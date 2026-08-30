import Foundation
import ImageIO

struct QyooOrientedPixels {
    let data: Data
    let width: Int
    let height: Int
    let bytesPerRow: Int
}

extension CGImagePropertyOrientation {
    var qyooSwapsDimensions: Bool {
        switch self {
        case .left, .leftMirrored, .right, .rightMirrored: true
        default: false
        }
    }
}
enum QyooImageOrientationAdapter {
    static func copy(
        source: UnsafeRawBufferPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        bytesPerPixel: Int,
        orientation: CGImagePropertyOrientation
    ) throws -> QyooOrientedPixels {
        guard
            width > 0,
            height > 0,
            bytesPerPixel > 0,
            bytesPerRow >= width * bytesPerPixel,
            let sourceBase = source.baseAddress
        else {
            throw QyooDetectorError.invalidImage
        }

        let destinationWidth = orientation.qyooSwapsDimensions ? height : width
        let destinationHeight = orientation.qyooSwapsDimensions ? width : height
        let (destinationStride, strideOverflow) = destinationWidth.multipliedReportingOverflow(
            by: bytesPerPixel
        )
        let (destinationCount, countOverflow) = destinationStride.multipliedReportingOverflow(
            by: destinationHeight
        )
        guard !strideOverflow, !countOverflow else {
            throw QyooDetectorError.invalidImage
        }

        var destination = Data(count: destinationCount)
        destination.withUnsafeMutableBytes { output in
            guard let destinationBase = output.baseAddress else { return }
            for destinationY in 0..<destinationHeight {
                for destinationX in 0..<destinationWidth {
                    let sourcePoint = sourceCoordinates(
                        destinationX: destinationX,
                        destinationY: destinationY,
                        sourceWidth: width,
                        sourceHeight: height,
                        orientation: orientation
                    )
                    let sourceOffset = sourcePoint.y * bytesPerRow
                        + sourcePoint.x * bytesPerPixel
                    let destinationOffset = destinationY * destinationStride
                        + destinationX * bytesPerPixel
                    destinationBase.advanced(by: destinationOffset).copyMemory(
                        from: sourceBase.advanced(by: sourceOffset),
                        byteCount: bytesPerPixel
                    )
                }
            }
        }
        return QyooOrientedPixels(
            data: destination,
            width: destinationWidth,
            height: destinationHeight,
            bytesPerRow: destinationStride
        )
    }

    private static func sourceCoordinates(
        destinationX x: Int,
        destinationY y: Int,
        sourceWidth width: Int,
        sourceHeight height: Int,
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
