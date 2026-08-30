import XCTest
@testable import QyooDetector

final class BehaviorEquivalenceTests: XCTestCase {
    func testKnownAnswerFixturesMatchDirectCAPI() throws {
        let detector = try QyooDetector()
        let cases: [(name: String, payload: UInt64?)] = [
            ("perfect.png", 51_178_614_380),
            ("rotation_30.png", 51_178_614_380),
            ("perspective_1.png", 51_178_614_380),
            ("single_bit_17.png", 262_144),
            ("all_zero.png", 0),
            ("screen_raw_zero.jpeg", 0),
            ("IMG_5172.jpg", 511_305_600),
            ("negative_gray.png", nil),
        ]

        for testCase in cases {
            let image = try TestSupport.fixture(testCase.name)
            let pixels = try QyooDetector.renderBGRA(image)
            let directResults = try TestSupport.directDetect(
                bgra: pixels,
                width: image.width,
                height: image.height,
                bytesPerRow: image.width * 4
            )
            let swiftResults = try detector.detect(cgImage: image)

            XCTAssertEqual(swiftResults, directResults, testCase.name)
            if let payload = testCase.payload {
                XCTAssertEqual(swiftResults.map(\.payload), [payload], testCase.name)
                XCTAssertEqual(swiftResults[0].payload >> 36, 0, testCase.name)
                XCTAssertNotNil(swiftResults[0].carrierQuadrilateral, testCase.name)
                XCTAssertEqual(
                    swiftResults[0].normalizationStrategy,
                    .carrierTemplate,
                    testCase.name
                )
            } else {
                XCTAssertTrue(swiftResults.isEmpty, testCase.name)
            }
        }
    }
}
