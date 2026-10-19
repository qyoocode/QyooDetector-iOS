# QyooDetector

QyooDetector is a Swift Package for detecting 36-bit Qyoo carriers from
decoded Apple image buffers. It wraps the portable C detector core and does not
reimplement recognition in Swift.

This package preserves the detector snapshot identified below. Current app
integration may pin a later qualified revision; this snapshot does not by
itself establish parity with the shipping Qyoo 4.0 scanner. It implements visual
detection, not URL routing, Manifest resolution, ID allocation, or AR rendering.
See [AUDIT.md](AUDIT.md) for publication gates and validation limits.

Requires Swift tools 5.10 or later and Apple SDKs. Supported platforms:

- iOS 15 or later, including iOS Simulator
- macOS 13 or later

## Installation

Add `https://github.com/qyoocode/QyooDetector-iOS.git` as a Swift Package and
link the `QyooDetector` library product. For reproducible integration, pin a reviewed commit or release tag. This
example pins the public snapshot inspected by the audit:

```swift
dependencies: [
    .package(
        url: "https://github.com/qyoocode/QyooDetector-iOS.git",
        revision: "021becc75bd35834007aeca7a2db0f6451e8692c"
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
`3a7002fd7cc6075d9bfb19fe537585dc277a9267`. The C ABI in
`qyoo_detector.h` is the integration boundary; C++ implementation types are not
public. The exact libgd 2.3.3 resampler source required by the frozen multiscale
policy is vendored without image-codec dependencies. See
`Sources/CQyooDetectorCore/PROVENANCE.md` and `LICENSES/`.

The repository's Qyoo code is BSD-3-Clause; CML and libgd have separate
licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Include applicable
notices in app distributions. Historical photograph redistribution rights
remain an owner-review gate.

## Build, test, and example

```sh
python3 scripts/verify_sources.py
swift build
swift test
swift run QyooDetectorExample /path/to/image.jpg
```

The example prints every payload and its geometry. It is a command-line sample,
not a scanner or camera application.

Apple SDK builds can be checked directly:

```sh
xcodebuild -scheme QyooDetector \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO

xcodebuild -scheme QyooDetector \
  -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
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

The checked-in workflow runs macOS package tests and generic unsigned Apple
SDK builds. Device signing and physical iPhone camera validation require a
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
[AUDIT.md](AUDIT.md) for the owner follow-up.
