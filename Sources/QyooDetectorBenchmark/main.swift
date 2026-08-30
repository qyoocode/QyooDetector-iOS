import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import CQyooDetectorCore
import QyooDetector

enum BenchmarkError: Error {
    case usage
    case imageDecode
    case pixelBuffer(Int32)
    case native(UInt32)
    case unexpectedResults
}

func makePixelBuffer(from image: CGImage) throws -> CVPixelBuffer {
    var optionalBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        image.width,
        image.height,
        kCVPixelFormatType_32BGRA,
        [kCVPixelBufferCGImageCompatibilityKey as String: true] as CFDictionary,
        &optionalBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer = optionalBuffer else {
        throw BenchmarkError.pixelBuffer(status)
    }
    let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, [])
    guard lockStatus == kCVReturnSuccess else {
        throw BenchmarkError.pixelBuffer(lockStatus)
    }
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
    guard
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
        let context = CGContext(
            data: baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
                | CGImageAlphaInfo.premultipliedFirst.rawValue
        )
    else {
        throw BenchmarkError.imageDecode
    }
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return pixelBuffer
}

func elapsedMilliseconds(_ operation: () throws -> Void) rethrows -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    try operation()
    let end = DispatchTime.now().uptimeNanoseconds
    return Double(end - start) / 1_000_000
}

func mean(_ values: [Double]) -> Double {
    values.reduce(0, +) / Double(values.count)
}

func detectDirect(
    context: OpaquePointer,
    image: inout qyoo_image_t
) throws -> [UInt64] {
    var nativeResults = qyoo_result_array_t()
    let status = qyoo_detector_detect(context, &image, &nativeResults)
    defer { qyoo_result_array_release(&nativeResults) }
    guard status == UInt32(QYOO_STATUS_OK.rawValue) else {
        throw BenchmarkError.native(status)
    }
    guard nativeResults.outcome == UInt32(QYOO_DETECTION_DECODED.rawValue) else {
        return []
    }
    guard let results = nativeResults.results else {
        throw BenchmarkError.unexpectedResults
    }
    return (0..<nativeResults.count).map { results[$0].payload }
}

func withLockedNativeImage<T>(
    pixelBuffer: CVPixelBuffer,
    _ operation: (inout qyoo_image_t) throws -> T
) throws -> T {
    let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    guard lockStatus == kCVReturnSuccess else { throw BenchmarkError.pixelBuffer(lockStatus) }
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        throw BenchmarkError.imageDecode
    }
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
    var image = qyoo_image_t(
        struct_size: MemoryLayout<qyoo_image_t>.size,
        width: UInt32(width),
        height: UInt32(height),
        stride_bytes: stride,
        pixel_format: UInt32(QYOO_PIXEL_FORMAT_BGRA32.rawValue),
        pixels: baseAddress.assumingMemoryBound(to: UInt8.self),
        buffer_size: (height - 1) * stride + width * 4
    )
    return try operation(&image)
}

do {
    guard CommandLine.arguments.count == 2 || CommandLine.arguments.count == 3 else {
        throw BenchmarkError.usage
    }
    let iterations = CommandLine.arguments.count == 3
        ? Int(CommandLine.arguments[2]) ?? 5
        : 5
    guard iterations > 0 else { throw BenchmarkError.usage }
    let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
    guard
        let source = CGImageSourceCreateWithURL(url, nil),
        let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw BenchmarkError.imageDecode
    }
    let pixelBuffer = try makePixelBuffer(from: cgImage)

    let adapterIterations = 2_000
    let adapterTotal = try elapsedMilliseconds {
        for _ in 0..<adapterIterations {
            let status = CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            guard status == kCVReturnSuccess else { throw BenchmarkError.pixelBuffer(status) }
            _ = CVPixelBufferGetBaseAddress(pixelBuffer)
            _ = CVPixelBufferGetWidth(pixelBuffer)
            _ = CVPixelBufferGetHeight(pixelBuffer)
            _ = CVPixelBufferGetBytesPerRow(pixelBuffer)
            _ = CVPixelBufferGetPixelFormatType(pixelBuffer)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
    }

    var nativeContext: OpaquePointer?
    let createStatus = qyoo_detector_create(&nativeContext)
    guard createStatus == UInt32(QYOO_STATUS_OK.rawValue), let nativeContext else {
        throw BenchmarkError.native(createStatus)
    }
    defer { qyoo_detector_destroy(nativeContext) }

    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let stride = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let expectedPayloads = try withLockedNativeImage(pixelBuffer: pixelBuffer) { image in
        try detectDirect(context: nativeContext, image: &image)
    }

    let detector = try QyooDetector()
    guard try detector.detect(pixelBuffer: pixelBuffer).map(\.payload) == expectedPayloads else {
        throw BenchmarkError.unexpectedResults
    }
    var nativeSamples: [Double] = []
    var swiftSamples: [Double] = []
    let measureNative = {
        try withLockedNativeImage(pixelBuffer: pixelBuffer) { image in
            try elapsedMilliseconds {
                guard try detectDirect(context: nativeContext, image: &image) == expectedPayloads else {
                    throw BenchmarkError.unexpectedResults
                }
            }
        }
    }
    let measureSwift = {
        try elapsedMilliseconds {
            guard try detector.detect(pixelBuffer: pixelBuffer).map(\.payload) == expectedPayloads else {
                throw BenchmarkError.unexpectedResults
            }
        }
    }
    for index in 0..<iterations {
        if index.isMultiple(of: 2) {
            nativeSamples.append(try measureNative())
            swiftSamples.append(try measureSwift())
        } else {
            swiftSamples.append(try measureSwift())
            nativeSamples.append(try measureNative())
        }
    }

    let adapterMean = adapterTotal / Double(adapterIterations)
    let nativeMean = mean(nativeSamples)
    let swiftMean = mean(swiftSamples)
    print("fixture=\(CommandLine.arguments[1])")
    print("dimensions=\(width)x\(height) stride=\(stride)")
    print("iterations=\(iterations) payloads=\(expectedPayloads)")
    print(String(format: "cvpixelbuffer_adapter_mean_ms=%.6f", adapterMean))
    print(String(format: "native_c_api_mean_ms=%.3f", nativeMean))
    print(String(format: "swift_total_mean_ms=%.3f", swiftMean))
    print(String(format: "estimated_wrapper_delta_ms=%.3f", swiftMean - nativeMean))
} catch BenchmarkError.usage {
    FileHandle.standardError.write(
        Data("usage: QyooDetectorBenchmark IMAGE [ITERATIONS]\n".utf8)
    )
    exit(2)
} catch {
    FileHandle.standardError.write(Data("benchmark failed: \(error)\n".utf8))
    exit(1)
}
