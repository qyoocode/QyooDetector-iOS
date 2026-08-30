import Foundation
import ImageIO
import QyooDetector

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: QyooDetectorExample IMAGE\n".utf8))
    exit(2)
}

let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
guard
    let source = CGImageSourceCreateWithURL(url, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
else {
    FileHandle.standardError.write(Data("could not decode image\n".utf8))
    exit(1)
}

do {
    let detector = try QyooDetector()
    let results = try detector.detect(cgImage: image)
    if results.isEmpty {
        print("no Qyoo")
    }
    for result in results {
        let bits = String(result.payload, radix: 2).leftPadded(to: 36, with: "0")
        print("payload=\(bits) bounds=\(result.bounds)")
        if let quadrilateral = result.carrierQuadrilateral {
            print("quadrilateral=\(quadrilateral.points)")
        }
    }
} catch {
    FileHandle.standardError.write(Data("detection failed: \(error)\n".utf8))
    exit(1)
}

private extension String {
    func leftPadded(to length: Int, with character: Character) -> String {
        String(repeating: String(character), count: Swift.max(0, length - count)) + self
    }
}
