# QyooDetector

Qyoo is maintained by **Pushplay LLC**.

QyooDetector is a Swift Package for detecting 36-bit Qyoo carriers from
decoded Apple image buffers. It wraps the portable C detector core and does not
reimplement recognition in Swift.

This package vendors the detector safety snapshot identified below. The
release-associated app pin predates its stronger empty-payload guard; adopting
this SDK requires an explicit app pin update and qualification. Exact approved
binary identity has not been independently established. It implements visual
detection, not URL routing, Manifest resolution, ID allocation, or AR rendering.
See [AUDIT.md](AUDIT.md) for publication gates and validation limits.

Requires Swift tools 5.10 or later and Apple SDKs. Supported platforms:

- iOS 15 or later, including iOS Simulator
- macOS 13 or later

## Installation

Add `https://github.com/qyoocode/QyooDetector-iOS.git` as a Swift Package and
link the `QyooDetector` library product. For reproducible integration, pin a reviewed commit or release tag. This
example requires replacing the placeholder with the full reviewed SDK commit:

```swift
dependencies: [
    .package(
        url: "https://github.com/qyoocode/QyooDetector-iOS.git",
        revision: "<reviewed SDK commit>"
    ),
]
```

## Usage

```swift
import QyooDetector

let detector = try QyooDetector()
let results = try detector.detect(pixelBuffer: pixelBuffer)

for result in results {
    print(result.payload)                 // raw UInt64; low 36 bits are used
    print(result.bounds)
    print(result.carrierQuadrilateral as Any)
}
```

`CVPixelBuffer` inputs support non-planar `kCVPixelFormatType_32BGRA` and
`kCVPixelFormatType_OneComponent8`. Upright buffers use their existing base
address and row stride directly; the wrapper does not copy their pixels.

`CGImage` is also supported without PNG/JPEG re-encoding:

```swift
let results = try detector.detect(cgImage: image, orientation: .right)
```

`CGImage` and `CVPixelBuffer` do not reliably carry display orientation inside
the pixel object. Pass the corresponding `CGImagePropertyOrientation` when the
stored pixels are not upright. The wrapper normalizes all eight orientations,
including mirrored variants, before detection. Result bounds and quadrilateral
points are measured in the normalized caller-visible image, with a top-left
origin and pixel units. Left/right orientations swap the result image width and
height.

For already decoded data, `detect(bytes:width:height:bytesPerRow:pixelFormat:)`
accepts GRAY8, RGB24, BGR24, RGBA32, or BGRA32 data with padded rows.

A successful no-Qyoo decision returns an empty array. Native allocation,
invalid-image, and processing failures throw `QyooDetectorError`. Each
`QyooResult` contains the exact raw 36-bit payload in a `UInt64`, carrier bounds,
an optional carrier quadrilateral, and the production normalization strategy.
Historical decimal/row-column/boundary/frame codecs are intentionally absent.

## Threading and lifetime

`QyooDetector` is not main-actor isolated and may be called from background
tasks or camera-frame processing. One instance owns one native detector context;
the C core serializes concurrent calls on that instance. Independent detector
instances may execute concurrently. There is no global detector context.

Image storage is borrowed only for the synchronous call. Swift callers never
handle native result allocations: the wrapper copies results into Swift value
types and releases every C result array before returning or throwing.

## Native core provenance

The package source-vendors the public ABI and implementation from
`qyoocode/QyooDetector-CPP` commit
`60aa253c074e69922084a66fea67a73aa2c93531`. The C ABI in
`qyoo_detector.h` is the integration boundary; C++ implementation types are not
public. The exact libgd 2.3.3 resampler source required by the frozen multiscale
policy is vendored without image-codec dependencies. See
`Sources/CQyooDetectorCore/PROVENANCE.md` and `LICENSES/`.

The repository's Qyoo code is BSD-3-Clause; CML and libgd have separate
licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Include applicable
notices in app distributions. Historical fixture photographs are regression
evidence; their presence does not grant rights to unrelated photographs.

**Status: reference Swift package.** Package tests establish the documented
API/regression behavior; they do not establish production camera reliability.

## Build, test, and example

```sh
python3 scripts/verify_sources.py
swift build
swift test
swift run QyooDetectorExample /path/to/image.jpg
```

The example prints every payload and its geometry. It is a command-line sample,
not a scanner or camera application.

Unsigned Apple SDK target compilation can be checked without booting a simulator:

```sh
swift build --target QyooDetector --triple arm64-apple-ios15.0 \
  --sdk "$(xcrun --sdk iphoneos --show-sdk-path)"
swift build --target QyooDetector --triple arm64-apple-ios15.0-simulator \
  --sdk "$(xcrun --sdk iphonesimulator --show-sdk-path)"
```

For camera-path timing, the benchmark separates pixel-buffer lock/metadata
cost, direct C runtime, and total Swift-call runtime:

```sh
swift run -c release QyooDetectorBenchmark /path/to/upright-image.jpg 10
```


Tests cover fixture regression output, pixel formats, orientation transforms,
result lifetimes, and concurrent contexts. Historical-photo expected values
are detector regression oracles; they do not independently establish the
photographed ID. The suite is not a camera reliability benchmark. Record
accepted-wrong IDs separately from rejection in any additional camera corpus.

The checked-in workflow runs macOS package tests and unsigned Apple
SDK target compilation. Device signing and physical iPhone camera validation require a
separate supported environment. See [AUDIT.md](AUDIT.md) for what was actually
run during this audit.

With a local C++ checkout containing the documented commit, verify every
vendored header and implementation file without compiling:

```sh
python3 scripts/verify_sources.py --cpp ../QyooDetector-CPP
```

Camera fixtures are distributed without EXIF metadata. The audit removed an
EXIF block from `screen_raw_zero.jpeg` without changing its compressed image
scan; the fixture manifest records the updated digest. This working-tree
correction does not remove the original metadata from Git history. See
[PRIVACY_REMEDIATION.md](PRIVACY_REMEDIATION.md) for historical exposure; no history
rewrite is part of this cleanup.

The safety update rejects an empty-grid claim when existing high-contrast
foreground contradicts it in either the template grid or final sample disks.
The numeric domain still includes zero; this is a conservative acceptance rule,
not a new payload codec. In native qualification five C-generated genuine zero
symbols at64/68/96/128/256px change from acceptance to rejection; the frozen
Apple zero fixtures remain accepted. See [AUDIT.md](AUDIT.md) for measured corpus
limits. This is a reference package; app adoption and production camera support
are separately qualified and are outside this cleanup.
