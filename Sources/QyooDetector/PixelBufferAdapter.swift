import CoreVideo
import ImageIO

extension QyooDetector {
    /// Detects Qyoos in a non-planar BGRA32 or 8-bit grayscale pixel buffer.
    ///
    /// `.up` buffers are passed to the native core without a wrapper-level
    /// pixel copy. Other orientations are normalized into an upright buffer.
    /// Returned geometry is always in that upright, caller-visible coordinate
    /// system with a top-left origin.
    public func detect(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) throws -> [QyooResult] {
        let format: QyooPixelFormat
        switch CVPixelBufferGetPixelFormatType(pixelBuffer) {
        case kCVPixelFormatType_32BGRA:
            format = .bgra32
        case kCVPixelFormatType_OneComponent8:
            format = .gray8
        case let unsupported:
            throw QyooDetectorError.unsupportedPixelBufferFormat(unsupported)
        }
        guard CVPixelBufferGetPlaneCount(pixelBuffer) == 0 else {
            throw QyooDetectorError.unsupportedPixelBufferFormat(
                CVPixelBufferGetPixelFormatType(pixelBuffer)
            )
        }

        let lockStatus = CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        guard lockStatus == kCVReturnSuccess else {
            throw QyooDetectorError.pixelBufferLockFailed(lockStatus)
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw QyooDetectorError.invalidImage
        }
        let (precedingBytes, overflow) = (height - 1).multipliedReportingOverflow(
            by: bytesPerRow
        )
        let (lastRowBytes, rowOverflow) = width.multipliedReportingOverflow(
            by: format.byteCount
        )
        let (requiredBytes, sizeOverflow) = precedingBytes.addingReportingOverflow(lastRowBytes)
        guard !overflow, !rowOverflow, !sizeOverflow else {
            throw QyooDetectorError.invalidImage
        }
        let source = UnsafeRawBufferPointer(start: baseAddress, count: requiredBytes)

        if orientation == .up {
            return try detect(
                buffer: source,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                pixelFormat: format
            )
        }

        let oriented = try QyooImageOrientationAdapter.copy(
            source: source,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            bytesPerPixel: format.byteCount,
            orientation: orientation
        )
        return try oriented.data.withUnsafeBytes { bytes in
            try detect(
                buffer: bytes,
                width: oriented.width,
                height: oriented.height,
                bytesPerRow: oriented.bytesPerRow,
                pixelFormat: format
            )
        }
    }
}
