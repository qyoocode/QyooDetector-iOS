import Foundation
import XCTest
@testable import QyooDetector

final class LifecycleTests: XCTestCase {
    func testMalformedRawImageParameters() throws {
        let detector = try QyooDetector()
        let bytes = Data(repeating: 255, count: 128)
        let cases: [(Int, Int, Int)] = [
            (0, 8, 8),
            (8, 0, 8),
            (8, 8, 7),
            (65_536, 65_536, 65_536),
        ]
        for (width, height, stride) in cases {
            XCTAssertThrowsError(
                try detector.detect(
                    bytes: bytes,
                    width: width,
                    height: height,
                    bytesPerRow: stride,
                    pixelFormat: .gray8
                )
            ) { error in
                XCTAssertEqual(error as? QyooDetectorError, .invalidImage)
            }
        }
    }

    func testDifferentSizesStridesAndRepeatedCalls() throws {
        let detector = try QyooDetector()
        for (width, height, stride) in [(17, 19, 32), (96, 64, 113), (321, 47, 384)] {
            let bytes = Data(repeating: 255, count: stride * height)
            for _ in 0..<4 {
                XCTAssertTrue(
                    try detector.detect(
                        bytes: bytes,
                        width: width,
                        height: height,
                        bytesPerRow: stride,
                        pixelFormat: .gray8
                    ).isEmpty
                )
            }
        }
    }

    func testMultipleContextsAndCleanup() throws {
        let image = try TestSupport.fixture("perfect.png")
        let pixels = try QyooDetector.renderBGRA(image)
        let first = try QyooDetector()
        let second = try QyooDetector()
        XCTAssertEqual(
            try first.detect(
                bytes: pixels,
                width: image.width,
                height: image.height,
                bytesPerRow: image.width * 4,
                pixelFormat: .bgra32
            ),
            try second.detect(
                bytes: pixels,
                width: image.width,
                height: image.height,
                bytesPerRow: image.width * 4,
                pixelFormat: .bgra32
            )
        )

        weak var released: QyooDetector?
        autoreleasepool {
            let detector = try? QyooDetector()
            released = detector
            let blank = Data(repeating: 255, count: 32 * 32)
            _ = try? detector?.detect(
                bytes: blank,
                width: 32,
                height: 32,
                bytesPerRow: 32,
                pixelFormat: .gray8
            )
        }
        XCTAssertNil(released)
    }

    func testSameContextCanBeCalledConcurrently() throws {
        let detector = try QyooDetector()
        let bytes = Data(repeating: 255, count: 128 * 96)
        let queue = DispatchQueue(label: "qyoo.concurrent-test", attributes: .concurrent)
        let group = DispatchGroup()
        let lock = NSLock()
        var failures: [Error] = []
        for _ in 0..<8 {
            group.enter()
            queue.async {
                defer { group.leave() }
                do {
                    let results = try detector.detect(
                        bytes: bytes,
                        width: 128,
                        height: 96,
                        bytesPerRow: 128,
                        pixelFormat: .gray8
                    )
                    if !results.isEmpty {
                        throw TestSupportError.invalidNativeResults
                    }
                } catch {
                    lock.lock()
                    failures.append(error)
                    lock.unlock()
                }
            }
        }
        group.wait()
        XCTAssertTrue(failures.isEmpty, "\(failures)")
    }
}
