import CoreVideo
import ImageIO
import XCTest
@testable import QyooDetector

/// C-generator known answers catch false empty-payload acceptance, including
/// sparse cells lost during normalization. A processing error must throw/fail.
final class ReleaseSafetyTests: XCTestCase {
    private let fixtures: [(String, UInt64)] = [
        ("c-max64.png", 68_719_476_735),
        ("c-one96.png", 1),
        ("c-one128.png", 1),
    ]

    private func assertSafe(_ results: [QyooResult], expected: UInt64, label: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(results.isEmpty || results.map(\.payload) == [expected],
                      "Accepted wrong payload: \(label): \(results.map(\.payload))",
                      file: file, line: line)
    }

    func testGeneratedSymbolsNeverAcceptAnotherIDInRawAndCGImagePaths() throws {
        let detector = try QyooDetector()
        for (name, expected) in fixtures {
            let image = try TestSupport.fixture(name)
            let bgra = try QyooDetector.renderBGRA(image)
            // These fixtures are grayscale; extract an exact channel, not a
            // new color-space/luminance approximation of the source pixels.
            let pixels = [UInt8](bgra)
            var gray = Data(capacity: image.width * image.height)
            for offset in stride(from: 0, to: pixels.count, by: 4) {
                XCTAssertEqual(pixels[offset], pixels[offset + 1], name)
                XCTAssertEqual(pixels[offset], pixels[offset + 2], name)
                gray.append(pixels[offset])
            }
            for (bytes, format, stride) in [
                (bgra, QyooPixelFormat.bgra32, image.width * 4),
                (gray, QyooPixelFormat.gray8, image.width),
            ] {
                assertSafe(try detector.detect(bytes: bytes, width: image.width,
                                              height: image.height, bytesPerRow: stride,
                                              pixelFormat: format),
                           expected: expected, label: "\(name) \(format)")
            }
            assertSafe(try detector.detect(cgImage: image), expected: expected, label: name)
        }
    }

    func testGeneratedSymbolsNeverAcceptAnotherIDThroughAllPixelBufferOrientations() throws {
        let detector = try QyooDetector()
        let orientations: [CGImagePropertyOrientation] = [
            .up, .upMirrored, .down, .downMirrored,
            .left, .leftMirrored, .right, .rightMirrored,
        ]
        for (name, expected) in fixtures {
            let image = try TestSupport.fixture(name)
            let upright = try QyooDetector.renderBGRA(image)
            for orientation in orientations {
                let stored = try TestSupport.storedPixels(forUpright: upright,
                                                         uprightWidth: image.width,
                                                         uprightHeight: image.height,
                                                         orientation: orientation)
                let buffer = try TestSupport.makeBGRApixelBuffer(pixels: stored.data,
                                                                width: stored.width,
                                                                height: stored.height,
                                                                sourceBytesPerRow: stored.width * 4)
                assertSafe(try detector.detect(pixelBuffer: buffer, orientation: orientation),
                           expected: expected, label: "\(name) orientation \(orientation.rawValue)")
            }
        }
    }
}
