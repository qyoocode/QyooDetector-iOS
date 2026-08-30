import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import CQyooDetectorCore
@testable import QyooDetector

enum TestSupportError: Error {
    case missingFixture(String)
    case imageDecode(String)
    case pixelBuffer(Int32)
    case native(UInt32)
    case invalidNativeResults
    case imageCreation
}

enum TestSupport {
    static func fixture(_ name: String) throws -> CGImage {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: nil,
            subdirectory: "Fixtures"
        ) else {
            throw TestSupportError.missingFixture(name)
        }
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw TestSupportError.imageDecode(name)
        }
        return image
    }

    static func directDetect(
        bgra: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int
    ) throws -> [QyooResult] {
        var context: OpaquePointer?
        let createStatus = qyoo_detector_create(&context)
        guard
            createStatus == UInt32(QYOO_STATUS_OK.rawValue),
            let context
        else {
            throw TestSupportError.native(createStatus)
        }
        defer { qyoo_detector_destroy(context) }

        return try bgra.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                throw TestSupportError.invalidNativeResults
            }
            var image = qyoo_image_t(
                struct_size: MemoryLayout<qyoo_image_t>.size,
                width: UInt32(width),
                height: UInt32(height),
                stride_bytes: bytesPerRow,
                pixel_format: UInt32(QYOO_PIXEL_FORMAT_BGRA32.rawValue),
                pixels: baseAddress.assumingMemoryBound(to: UInt8.self),
                buffer_size: buffer.count
            )
            var nativeResults = qyoo_result_array_t()
            let status = qyoo_detector_detect(context, &image, &nativeResults)
            defer { qyoo_result_array_release(&nativeResults) }
            guard status == UInt32(QYOO_STATUS_OK.rawValue) else {
                throw TestSupportError.native(status)
            }
            guard nativeResults.outcome == UInt32(QYOO_DETECTION_DECODED.rawValue) else {
                return []
            }
            guard let results = nativeResults.results else {
                throw TestSupportError.invalidNativeResults
            }
            return (0..<nativeResults.count).map { result(from: results[$0]) }
        }
    }

    static func makeBGRApixelBuffer(
        pixels: Data,
        width: Int,
        height: Int,
        sourceBytesPerRow: Int,
        rowAlignment: Int = 64
    ) throws -> CVPixelBuffer {
        let attributes = [
            kCVPixelBufferBytesPerRowAlignmentKey as String: rowAlignment,
        ] as CFDictionary
        var optionalBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes,
            &optionalBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer = optionalBuffer else {
            throw TestSupportError.pixelBuffer(status)
        }

        let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, [])
        guard lockStatus == kCVReturnSuccess else {
            throw TestSupportError.pixelBuffer(lockStatus)
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let destination = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw TestSupportError.imageCreation
        }
        let destinationBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        destination.assumingMemoryBound(to: UInt8.self).initialize(
            repeating: 255,
            count: destinationBytesPerRow * height
        )
        try pixels.withUnsafeBytes { source in
            guard let sourceBase = source.baseAddress else {
                throw TestSupportError.imageCreation
            }
            for row in 0..<height {
                destination.advanced(by: row * destinationBytesPerRow).copyMemory(
                    from: sourceBase.advanced(by: row * sourceBytesPerRow),
                    byteCount: width * 4
                )
            }
        }
        return pixelBuffer
    }

    static func makeBlankPixelBuffer(
        width: Int,
        height: Int,
        format: OSType
    ) throws -> CVPixelBuffer {
        var optionalBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            nil,
            &optionalBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer = optionalBuffer else {
            throw TestSupportError.pixelBuffer(status)
        }
        let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, [])
        guard lockStatus == kCVReturnSuccess else {
            throw TestSupportError.pixelBuffer(lockStatus)
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
            baseAddress.assumingMemoryBound(to: UInt8.self).initialize(
                repeating: 255,
                count: CVPixelBufferGetDataSize(pixelBuffer)
            )
        }
        return pixelBuffer
    }

    static func makeCGImage(
        bgra: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int
    ) throws -> CGImage {
        guard
            let provider = CGDataProvider(data: bgra as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Little.union(
                    CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            throw TestSupportError.imageCreation
        }
        return image
    }

    static func uprightCanvas(
        containing pixels: Data,
        sourceWidth: Int,
        sourceHeight: Int,
        width: Int = 640,
        height: Int = 544
    ) throws -> Data {
        let stride = width * 4
        var canvas = Data(repeating: 255, count: stride * height)
        let offsetX = (width - sourceWidth) / 2
        let offsetY = (height - sourceHeight) / 2
        try canvas.withUnsafeMutableBytes { destination in
            try pixels.withUnsafeBytes { source in
                guard let destinationBase = destination.baseAddress,
                      let sourceBase = source.baseAddress else {
                    throw TestSupportError.imageCreation
                }
                for row in 0..<sourceHeight {
                    destinationBase.advanced(
                        by: (row + offsetY) * stride + offsetX * 4
                    ).copyMemory(
                        from: sourceBase.advanced(by: row * sourceWidth * 4),
                        byteCount: sourceWidth * 4
                    )
                }
            }
        }
        return canvas
    }

    static func storedPixels(
        forUpright upright: Data,
        uprightWidth: Int,
        uprightHeight: Int,
        orientation: CGImagePropertyOrientation
    ) throws -> (data: Data, width: Int, height: Int) {
        let swapsDimensions: Bool
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            swapsDimensions = true
        default:
            swapsDimensions = false
        }
        let storedWidth = swapsDimensions ? uprightHeight : uprightWidth
        let storedHeight = swapsDimensions ? uprightWidth : uprightHeight
        var stored = Data(count: storedWidth * storedHeight * 4)
        try stored.withUnsafeMutableBytes { destination in
            try upright.withUnsafeBytes { source in
                guard let destinationBase = destination.baseAddress,
                      let sourceBase = source.baseAddress else {
                    throw TestSupportError.imageCreation
                }
                for y in 0..<uprightHeight {
                    for x in 0..<uprightWidth {
                        let sourcePoint = storedCoordinate(
                            uprightX: x,
                            uprightY: y,
                            storedWidth: storedWidth,
                            storedHeight: storedHeight,
                            orientation: orientation
                        )
                        destinationBase.advanced(
                            by: (sourcePoint.y * storedWidth + sourcePoint.x) * 4
                        ).copyMemory(
                            from: sourceBase.advanced(by: (y * uprightWidth + x) * 4),
                            byteCount: 4
                        )
                    }
                }
            }
        }
        return (stored, storedWidth, storedHeight)
    }

    private static func result(from native: qyoo_result_t) -> QyooResult {
        let corners = native.carrier_quadrilateral
        let quadrilateral = native.carrier_quadrilateral_valid == 0
            ? nil
            : QyooQuadrilateral(
                topLeft: QyooPoint(x: corners.0.x, y: corners.0.y),
                topRight: QyooPoint(x: corners.1.x, y: corners.1.y),
                bottomRight: QyooPoint(x: corners.2.x, y: corners.2.y),
                bottomLeft: QyooPoint(x: corners.3.x, y: corners.3.y)
            )
        return QyooResult(
            payload: native.payload,
            bounds: QyooBounds(
                minX: native.bounds.min_x,
                minY: native.bounds.min_y,
                maxX: native.bounds.max_x,
                maxY: native.bounds.max_y
            ),
            carrierQuadrilateral: quadrilateral,
            normalizationStrategy: .carrierTemplate
        )
    }

    private static func storedCoordinate(
        uprightX x: Int,
        uprightY y: Int,
        storedWidth width: Int,
        storedHeight height: Int,
        orientation: CGImagePropertyOrientation
    ) -> (x: Int, y: Int) {
        switch orientation {
        case .up: (x, y)
        case .upMirrored: (width - 1 - x, y)
        case .down: (width - 1 - x, height - 1 - y)
        case .downMirrored: (x, height - 1 - y)
        case .leftMirrored: (y, x)
        case .right: (y, height - 1 - x)
        case .rightMirrored: (width - 1 - y, height - 1 - x)
        case .left: (width - 1 - y, x)
        @unknown default: (x, y)
        }
    }
}
