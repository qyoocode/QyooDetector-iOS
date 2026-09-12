import CryptoKit
import Foundation
import XCTest
@testable import QyooDetector

final class EmptyPayloadIncidentTests: XCTestCase {
    func testPrivateExactCameraFramesRejectThroughSwiftAndC() throws {
        guard let path = ProcessInfo.processInfo.environment["QYOO_EMPTY_PAYLOAD_FRAME_DIR"] else {
            throw XCTSkip("Set QYOO_EMPTY_PAYLOAD_FRAME_DIR to the private exact-frame export")
        }
        let cases = [
            ("7CC2FAEC-9371-498C-AFE1-0DC93353F6FF", "17c66f5f0fa35929f840824b2b5d22c3c80385ea147bd1a6ad8050f99241bd05"),
            ("3431BF75-F620-44E6-9CFC-BEB24088569F", "4469fc6c9465232f69ca15aa63d4af16407ed010e63d617d573f3b79bc8ef7fc"),
        ]
        let detector = try QyooDetector()
        for (frameID, expectedHash) in cases {
            let url = URL(fileURLWithPath: path).appendingPathComponent(frameID)
                .appendingPathComponent("input.bgra")
            let pixels = try Data(contentsOf: url)
            let hash = SHA256.hash(data: pixels).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(hash, expectedHash, frameID)
            XCTAssertEqual(pixels.count, 720 * 1280 * 4)
            let direct = try TestSupport.directDetect(bgra: pixels, width: 720,
                height: 1280, bytesPerRow: 720 * 4)
            let buffer = try TestSupport.makeBGRApixelBuffer(pixels: pixels,
                width: 720, height: 1280, sourceBytesPerRow: 720 * 4)
            let wrapped = try detector.detect(pixelBuffer: buffer)
            XCTAssertTrue(direct.isEmpty, frameID)
            XCTAssertTrue(wrapped.isEmpty, frameID)
        }
    }
}
