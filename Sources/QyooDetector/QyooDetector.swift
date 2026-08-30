import CoreGraphics
import Foundation
import ImageIO
import CQyooDetectorCore

/// A decoded point in the orientation-normalized image coordinate system.
/// The origin is at the top-left and coordinates are measured in pixels.
public struct QyooPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

/// Axis-aligned carrier bounds in the orientation-normalized image.
public struct QyooBounds: Equatable, Sendable {
    public let minX: Double
    public let minY: Double
    public let maxX: Double
    public let maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var cgRect: CGRect { CGRect(x: minX, y: minY, width: width, height: height) }
}

/// Carrier model corners in top-left, top-right, bottom-right, bottom-left order.
public struct QyooQuadrilateral: Equatable, Sendable {
    public let topLeft: QyooPoint
    public let topRight: QyooPoint
    public let bottomRight: QyooPoint
    public let bottomLeft: QyooPoint

    public init(
        topLeft: QyooPoint,
        topRight: QyooPoint,
        bottomRight: QyooPoint,
        bottomLeft: QyooPoint
    ) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    public var points: [QyooPoint] { [topLeft, topRight, bottomRight, bottomLeft] }
}

public enum QyooNormalizationStrategy: Equatable, Sendable {
    case carrierTemplate
}

/// One successfully decoded physical Qyoo.
public struct QyooResult: Equatable, Sendable {
    /// The raw 36-bit carrier payload. Only the low 36 bits are meaningful.
    public let payload: UInt64
    public let bounds: QyooBounds
    public let carrierQuadrilateral: QyooQuadrilateral?
    public let normalizationStrategy: QyooNormalizationStrategy

    public init(
        payload: UInt64,
        bounds: QyooBounds,
        carrierQuadrilateral: QyooQuadrilateral?,
        normalizationStrategy: QyooNormalizationStrategy
    ) {
        self.payload = payload
        self.bounds = bounds
        self.carrierQuadrilateral = carrierQuadrilateral
        self.normalizationStrategy = normalizationStrategy
    }
}

/// Raw formats accepted by the portable C core.
public enum QyooPixelFormat: Sendable {
    case gray8
    case rgb24
    case bgr24
    case rgba32
    case bgra32

    var byteCount: Int {
        switch self {
        case .gray8: 1
        case .rgb24, .bgr24: 3
        case .rgba32, .bgra32: 4
        }
    }

    var nativeValue: qyoo_pixel_format_t {
        switch self {
        case .gray8: UInt32(QYOO_PIXEL_FORMAT_GRAY8.rawValue)
        case .rgb24: UInt32(QYOO_PIXEL_FORMAT_RGB24.rawValue)
        case .bgr24: UInt32(QYOO_PIXEL_FORMAT_BGR24.rawValue)
        case .rgba32: UInt32(QYOO_PIXEL_FORMAT_RGBA32.rawValue)
        case .bgra32: UInt32(QYOO_PIXEL_FORMAT_BGRA32.rawValue)
        }
    }
}

public enum QyooDetectorError: Error, Equatable, Sendable {
    case incompatibleNativeCore(expected: UInt32, actual: UInt32)
    case invalidImage
    case unsupportedPixelBufferFormat(UInt32)
    case pixelBufferLockFailed(Int32)
    case outOfMemory
    case processingFailure
    case nativeFailure(UInt32)
}

extension QyooDetectorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .incompatibleNativeCore(expected, actual):
            "Incompatible Qyoo native API version (expected \(expected), received \(actual))."
        case .invalidImage:
            "The image dimensions, stride, format, or buffer length are invalid."
        case let .unsupportedPixelBufferFormat(format):
            "Unsupported CVPixelBuffer format: \(Self.fourCC(format))."
        case let .pixelBufferLockFailed(status):
            "CVPixelBufferLockBaseAddress failed with status \(status)."
        case .outOfMemory:
            "The Qyoo detector could not allocate required memory."
        case .processingFailure:
            "The Qyoo detector could not process the image safely."
        case let .nativeFailure(status):
            "The Qyoo native core returned unknown status \(status)."
        }
    }

    private static func fourCC(_ value: UInt32) -> String {
        let bytes = [
            UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff), UInt8(value & 0xff),
        ]
        if bytes.allSatisfy({ 32...126 ~= $0 }) {
            return "'\(String(bytes: bytes, encoding: .ascii) ?? "????")'"
        }
        return String(value)
    }
}

/// A reusable detector backed by one independent native context.
///
/// Synchronous detection does not run on the main actor. Calls on the same
/// instance are serialized by the native core; separate instances may run in
/// parallel. Sharing an instance across background tasks is safe.
public final class QyooDetector: @unchecked Sendable {
    public static let nativeAPIVersion = UInt32(QYOO_DETECTOR_API_VERSION)

    private let nativeContext: OpaquePointer

    public init() throws {
        let actualVersion = qyoo_detector_api_version()
        guard actualVersion == Self.nativeAPIVersion else {
            throw QyooDetectorError.incompatibleNativeCore(
                expected: Self.nativeAPIVersion,
                actual: actualVersion
            )
        }

        var context: OpaquePointer?
        let status = qyoo_detector_create(&context)
        guard status == UInt32(QYOO_STATUS_OK.rawValue), let context else {
            throw Self.error(for: status)
        }
        nativeContext = context
    }

    deinit {
        qyoo_detector_destroy(nativeContext)
    }

    /// Detects all qualified physical Qyoos in decoded raw bytes.
    ///
    /// Rows may contain padding. The data is borrowed only for this call.
    /// An empty array is a successful, safe no-Qyoo result; processing failures
    /// throw. This overload treats the bytes as already oriented upright.
    public func detect(
        bytes: Data,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        pixelFormat: QyooPixelFormat
    ) throws -> [QyooResult] {
        try bytes.withUnsafeBytes { buffer in
            try detect(
                buffer: buffer,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                pixelFormat: pixelFormat
            )
        }
    }

    func detect(
        buffer: UnsafeRawBufferPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        pixelFormat: QyooPixelFormat
    ) throws -> [QyooResult] {
        guard
            width > 0,
            height > 0,
            width <= Int(UInt32.max),
            height <= Int(UInt32.max),
            bytesPerRow >= 0,
            let baseAddress = buffer.baseAddress
        else {
            throw QyooDetectorError.invalidImage
        }

        let (minimumRowBytes, rowOverflow) = width.multipliedReportingOverflow(
            by: pixelFormat.byteCount
        )
        guard !rowOverflow, bytesPerRow >= minimumRowBytes else {
            throw QyooDetectorError.invalidImage
        }
        let (precedingBytes, heightOverflow) = (height - 1).multipliedReportingOverflow(
            by: bytesPerRow
        )
        let (requiredBytes, sizeOverflow) = precedingBytes.addingReportingOverflow(
            minimumRowBytes
        )
        guard !heightOverflow, !sizeOverflow, buffer.count >= requiredBytes else {
            throw QyooDetectorError.invalidImage
        }

        var image = qyoo_image_t(
            struct_size: MemoryLayout<qyoo_image_t>.size,
            width: UInt32(width),
            height: UInt32(height),
            stride_bytes: bytesPerRow,
            pixel_format: pixelFormat.nativeValue,
            pixels: baseAddress.assumingMemoryBound(to: UInt8.self),
            buffer_size: buffer.count
        )
        var nativeResults = qyoo_result_array_t()
        let status = qyoo_detector_detect(nativeContext, &image, &nativeResults)
        defer { qyoo_result_array_release(&nativeResults) }

        guard status == UInt32(QYOO_STATUS_OK.rawValue) else {
            throw Self.error(for: status)
        }
        guard nativeResults.outcome == UInt32(QYOO_DETECTION_DECODED.rawValue) else {
            return []
        }
        guard nativeResults.count > 0, let results = nativeResults.results else {
            throw QyooDetectorError.processingFailure
        }

        return (0..<nativeResults.count).map { index in
            Self.result(from: results[index])
        }
    }

    private static func result(from native: qyoo_result_t) -> QyooResult {
        let corners = native.carrier_quadrilateral
        let quadrilateral: QyooQuadrilateral? = native.carrier_quadrilateral_valid == 0
            ? nil
            : QyooQuadrilateral(
                topLeft: point(from: corners.0),
                topRight: point(from: corners.1),
                bottomRight: point(from: corners.2),
                bottomLeft: point(from: corners.3)
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

    private static func point(from native: qyoo_point_t) -> QyooPoint {
        QyooPoint(x: native.x, y: native.y)
    }

    private static func error(for status: qyoo_status_t) -> QyooDetectorError {
        if status == UInt32(QYOO_STATUS_INVALID_ARGUMENT.rawValue) {
            return .invalidImage
        }
        if status == UInt32(QYOO_STATUS_OUT_OF_MEMORY.rawValue) {
            return .outOfMemory
        }
        if status == UInt32(QYOO_STATUS_PROCESSING_FAILURE.rawValue) {
            return .processingFailure
        }
        return .nativeFailure(status)
    }
}
