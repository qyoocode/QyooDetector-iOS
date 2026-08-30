import CoreVideo
import ImageIO
import XCTest
@testable import QyooDetector

final class InputOrientationTests: XCTestCase {
    func testPaddedPixelBufferMatchesRawBytes() throws {
        let image = try TestSupport.fixture("perfect.png")
        let pixels = try QyooDetector.renderBGRA(image)
        let detector = try QyooDetector()
        let raw = try detector.detect(
            bytes: pixels,
            width: image.width,
            height: image.height,
            bytesPerRow: image.width * 4,
            pixelFormat: .bgra32
        )
        let pixelBuffer = try TestSupport.makeBGRApixelBuffer(
            pixels: pixels,
            width: image.width,
            height: image.height,
            sourceBytesPerRow: image.width * 4,
            rowAlignment: 256
        )
        XCTAssertGreaterThanOrEqual(CVPixelBufferGetBytesPerRow(pixelBuffer), image.width * 4)
        XCTAssertEqual(try detector.detect(pixelBuffer: pixelBuffer), raw)
    }

    func testAllAppleOrientationsNormalizePixelsAndGeometry() throws {
        let image = try TestSupport.fixture("perfect.png")
        let source = try QyooDetector.renderBGRA(image)
        let uprightWidth = 640
        let uprightHeight = 544
        let upright = try TestSupport.uprightCanvas(
            containing: source,
            sourceWidth: image.width,
            sourceHeight: image.height,
            width: uprightWidth,
            height: uprightHeight
        )
        let detector = try QyooDetector()
        let expected = try detector.detect(
            bytes: upright,
            width: uprightWidth,
            height: uprightHeight,
            bytesPerRow: uprightWidth * 4,
            pixelFormat: .bgra32
        )
        XCTAssertEqual(expected.map(\.payload), [51_178_614_380])

        let orientations: [CGImagePropertyOrientation] = [
            .up, .upMirrored, .down, .downMirrored,
            .left, .leftMirrored, .right, .rightMirrored,
        ]
        for orientation in orientations {
            let stored = try TestSupport.storedPixels(
                forUpright: upright,
                uprightWidth: uprightWidth,
                uprightHeight: uprightHeight,
                orientation: orientation
            )
            let pixelBuffer = try TestSupport.makeBGRApixelBuffer(
                pixels: stored.data,
                width: stored.width,
                height: stored.height,
                sourceBytesPerRow: stored.width * 4
            )
            XCTAssertEqual(
                try detector.detect(pixelBuffer: pixelBuffer, orientation: orientation),
                expected,
                "orientation \(orientation.rawValue)"
            )
        }
    }

    func testCGImageRightAndMirroredOrientation() throws {
        let image = try TestSupport.fixture("perfect.png")
        let source = try QyooDetector.renderBGRA(image)
        let uprightWidth = 640
        let uprightHeight = 544
        let upright = try TestSupport.uprightCanvas(
            containing: source,
            sourceWidth: image.width,
            sourceHeight: image.height,
            width: uprightWidth,
            height: uprightHeight
        )
        let detector = try QyooDetector()
        let expected = try detector.detect(
            bytes: upright,
            width: uprightWidth,
            height: uprightHeight,
            bytesPerRow: uprightWidth * 4,
            pixelFormat: .bgra32
        )

        for orientation in [CGImagePropertyOrientation.right, .upMirrored] {
            let stored = try TestSupport.storedPixels(
                forUpright: upright,
                uprightWidth: uprightWidth,
                uprightHeight: uprightHeight,
                orientation: orientation
            )
            let storedImage = try TestSupport.makeCGImage(
                bgra: stored.data,
                width: stored.width,
                height: stored.height,
                bytesPerRow: stored.width * 4
            )
            XCTAssertEqual(
                try detector.detect(cgImage: storedImage, orientation: orientation),
                expected
            )
        }
    }

    func testGrayAndUnsupportedPixelBufferFormats() throws {
        let detector = try QyooDetector()
        let gray = try TestSupport.makeBlankPixelBuffer(
            width: 113,
            height: 79,
            format: kCVPixelFormatType_OneComponent8
        )
        XCTAssertTrue(try detector.detect(pixelBuffer: gray).isEmpty)

        let unsupported = try TestSupport.makeBlankPixelBuffer(
            width: 32,
            height: 32,
            format: kCVPixelFormatType_32ARGB
        )
        XCTAssertThrowsError(try detector.detect(pixelBuffer: unsupported)) { error in
            XCTAssertEqual(
                error as? QyooDetectorError,
                .unsupportedPixelBufferFormat(kCVPixelFormatType_32ARGB)
            )
        }
    }
}
