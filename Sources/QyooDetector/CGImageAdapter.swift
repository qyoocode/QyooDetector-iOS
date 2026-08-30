import CoreGraphics
import Foundation
import ImageIO

extension QyooDetector {
    /// Renders a `CGImage` to BGRA32 without PNG/JPEG encoding, normalizes the
    /// supplied orientation, and returns geometry in the upright image space.
    /// `CGImage` itself carries no orientation metadata, so callers must pass
    /// metadata obtained from their image source when it is not `.up`.
    public func detect(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation = .up
    ) throws -> [QyooResult] {
        let rendered = try Self.renderBGRA(cgImage)
        if orientation == .up {
            return try detect(
                bytes: rendered,
                width: cgImage.width,
                height: cgImage.height,
                bytesPerRow: cgImage.width * 4,
                pixelFormat: .bgra32
            )
        }

        return try rendered.withUnsafeBytes { source in
            let oriented = try QyooImageOrientationAdapter.copy(
                source: source,
                width: cgImage.width,
                height: cgImage.height,
                bytesPerRow: cgImage.width * 4,
                bytesPerPixel: 4,
                orientation: orientation
            )
            return try detect(
                bytes: oriented.data,
                width: oriented.width,
                height: oriented.height,
                bytesPerRow: oriented.bytesPerRow,
                pixelFormat: .bgra32
            )
        }
    }

    static func renderBGRA(_ image: CGImage) throws -> Data {
        guard image.width > 0, image.height > 0 else {
            throw QyooDetectorError.invalidImage
        }
        let (bytesPerRow, rowOverflow) = image.width.multipliedReportingOverflow(by: 4)
        let (byteCount, sizeOverflow) = bytesPerRow.multipliedReportingOverflow(by: image.height)
        guard !rowOverflow, !sizeOverflow else {
            throw QyooDetectorError.invalidImage
        }

        var pixels = Data(count: byteCount)
        let created = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard
                let baseAddress = bytes.baseAddress,
                let context = CGContext(
                    data: baseAddress,
                    width: image.width,
                    height: image.height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
                        | CGImageAlphaInfo.premultipliedFirst.rawValue
                )
            else {
                return false
            }
            context.interpolationQuality = .none
            context.draw(
                image,
                in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
            )
            return true
        }
        guard created else {
            throw QyooDetectorError.invalidImage
        }
        return pixels
    }
}
