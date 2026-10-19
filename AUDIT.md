# Public repository audit — 18 October 2026

Inspected default branch `origin/main`:
`021becc75bd35834007aeca7a2db0f6451e8692c`.
Classification: **reference Swift SDK snapshot; current-app parity unqualified**.
Verdict: **HOLD for a newly endorsed Qyoo 4.0 SDK release**. The integration
surface is coherent, but current-app safety alignment, fresh Apple builds and
privacy/asset follow-up remain release gates. Native and Swift executable source
was preserved byte for byte.

## Findings

| Severity | Finding and evidence | Status |
| --- | --- | --- |
| HIGH | [`Tests/QyooDetectorTests/Fixtures/screen_raw_zero.jpeg`](Tests/QyooDetectorTests/Fixtures/screen_raw_zero.jpeg) at inspected main contained EXIF GPS coordinate fields with nonempty latitude/longitude rationals, device metadata and capture time. Values were never printed. | Current-file EXIF removed losslessly; compressed JPEG scan bytes unchanged, manifest hash updated, integrity guard added. Original still exists in Git history. Owner must assess privacy notification/history remediation separately; no rewrite is authorized. |
| HIGH | The read-only current-app source comparison found its detector pin is later than this public snapshot and includes additional empty-payload safety rejection. This snapshot's [`QyooDetectorTests.swift:12`](Tests/QyooDetectorTests/QyooDetectorTests.swift#L12) still explicitly expects zero acceptance. | Open alignment/qualification decision. No native behavior copied from private development. Numeric 36-bit range and detector acceptance policy must be treated separately. |
| HIGH | The source-equivalent C++ public core accepted a known generated 64×64 maximum-ID PNG as 0 during this audit. | Current Swift CGImage/CVPixelBuffer path NOT RUN; do not infer an Apple-path result, but shared-source safety qualification is a release gate. Public C++ release-safety fixture/gate retains the exact reproduction. |
| HIGH | Camera photograph redistribution rights are not established by repository documentation. | Owner/legal confirmation required. Existing photos retained, except privacy metadata removal. |
| MEDIUM | CML license was missing from the license bundle despite redistribution of 301 headers; [`cml/version.h:2`](Sources/CQyooDetectorCore/cml/version.h#L2) retains upstream placeholder text. | Complete upstream Boost 1.0 license restored; exact source fingerprint and scope documented without invented copyright or source rewriting. |
| MEDIUM | Build, device/simulator and orientation claims had no fresh audit-run results. | Explicit NOT RUN gates; macOS test and unsigned Apple compilation CI prepared, not represented as passing. |
| LOW | Installation example tracked mutable main and provenance used internal task language. | Example pins inspected public commit; provenance now describes a source snapshot, not an internal task. |

## Native provenance and application comparison

`python3 scripts/verify_sources.py --cpp ../QyooDetector-CPP` verified all
322 source files against C++ commit
`3a7002fd7cc6075d9bfb19fe537585dc277a9267`: one public C header,
20 native source/header files, 301 CML headers. The only native textual
exception is the documented Clang diagnostic scope in `QyooModel.cpp`.
All CML headers also match upstream CML
[`0bb27c8637dd9cdc92b2f376a9e8c08eb649920f`](https://github.com/demianmnave/CML/tree/0bb27c8637dd9cdc92b2f376a9e8c08eb649920f/cml)
byte for byte. See [third-party notices](THIRD_PARTY_NOTICES.md).
Upstream libgd provenance checks matched 29 files exactly; `gd.c`,
`gd_interpolation.c` and `gd_color_match.c` differ only by documented Clang
diagnostic scopes. `config.h` is package-specific.
The vendored libgd notice and source subset remain intact; no image codec
implementation is added to the detector package.

The current app uses the same public `QyooDetector.detect(pixelBuffer:orientation:)`
interface and raw `UInt64` result model. Its minimum iOS deployment target is
higher than this package's iOS 15 minimum. That establishes source-level API
compatibility, not exact runtime-policy equivalence or release/deployment status.
No private app source paths or operational configuration are distributed here.

[`Package.swift:1`](Package.swift#L1) requires tools 5.10, iOS 15 and macOS 13.
Apple frameworks are required; this package is not a Linux Swift package.
The CVPixelBuffer adapter accepts non-planar BGRA32 or GRAY8 and rejects NV12
and other planar inputs. It locks read-only and unlocks with `defer`:
[`PixelBufferAdapter.swift:15`](Sources/QyooDetector/PixelBufferAdapter.swift#L15).
Upright pixels are borrowed; other orientations copy to an upright raster.
[`ImageOrientation.swift`](Sources/QyooDetector/ImageOrientation.swift) handles
all eight EXIF orientations, including mirrors, and swaps dimensions for
left/right. CGImage rendering copies pixels to BGRA rather than re-encoding.

Each Swift instance owns one C context, destroyed in `deinit`; the native mutex
serializes calls. Native result arrays are released with `defer` after value
copying: [`QyooDetector.swift:253`](Sources/QyooDetector/QyooDetector.swift#L253).
Geometry is in upright top-left-origin image pixels. Source review and fixture
coverage support those documented contracts; runtime tests were not run here.

Routing/Base36, web resolution, Manifest experiences, ID allocation and AR are
app/service responsibilities. No signature-cell/CRC-10 shipped format is
established by this package, and no ML shipping-detector claim is made.

## Exposure review

Inspected 10 commits reachable from `origin/main`, including 422 distinct blobs
(8 binary), using `git rev-list --objects origin/main` and `git cat-file --batch`.
Private-key PEM markers, AWS access-key IDs, GitHub token formats and absolute
developer-home path patterns yielded no text matches. This bounded search is
not a guarantee that all secrets or personal data are absent. Binary review
found the confirmed EXIF metadata issue above. Current `IMG_5172.jpg` has no
EXIF block. No checkpoint, tracked executable, Xcode user-state or .DS_Store
was found. Existing author attribution and historical research fixture
provenance were retained. No sensitive coordinate/time values were output.

## Changes prepared

Pinned-install documentation; current-app parity caveat; concise provenance;
CML license restoration and dependency/asset notices; 8-fixture hash/range/EXIF
checks; complete native snapshot verification script; macOS/Apple CI workflow;
lossless EXIF removal and updated manifest digest. No decoder/wrapper ABI or
geometry change. Git history preserves the original photograph bytes.

## Verification

Commands below run from the repository root unless noted.

| Command | Result |
| --- | --- |
| `python3 scripts/verify_sources.py --cpp ../QyooDetector-CPP` | PASS: 8 fixture hashes/ranges/EXIF checks; 322 source files match documented core (diagnostic-only scope excepted). |
| Standard-library JPEG container comparison against original tracked file | PASS: one 6,634-byte EXIF segment removed; original compressed image scan unchanged byte for byte. |
| `git diff --check` | PASS at final review. |
| `xcodebuild -version` | PASS environment probe: Xcode 26.6 / 17F113. |
| `swift build` / `swift test` | NOT RUN: available storage below required 20 GiB floor. No SwiftPM resolution/install started. |
| `swift run QyooDetectorExample IMAGE` / benchmark | NOT RUN: same storage gate; no Apple scan success or timing result claimed. |
| `xcodebuild -scheme QyooDetector -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` | NOT RUN: same storage gate; no simulator booted or created. |
| `xcodebuild -scheme QyooDetector -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO` | NOT RUN: same storage gate. Device linking/signing/hardware not validated. |
| Physical iPhone/camera qualification | NOT RUN: physical device interaction and camera corpus outside available validation. |
| New CI workflow | NOT RUN: prepared locally; no push/remote execution. |

An initial Pillow metadata inspection was NOT RUN because Pillow was unavailable;
no dependency was installed. The successful EXIF inspection and lossless
transformation used the Python standard library instead. This worktree began
near 4.6 MiB and ended near 4.6 MiB; text additions roughly offset removed
metadata. No build tree, SDK download, simulator or dependency copy was
created; only small text additions and one smaller JPEG remain. Volume storage
was approximately 19.87 GiB when the build gate was evaluated. No cleanup or
space reclamation is claimed.

## Owner/legal release gates

Assess the historical location-data exposure without publicly repeating values;
approve any separate history treatment; confirm camera-photo rights; reconcile
empty-payload safety with current-app qualification and allowed ID policy; complete
shared-core accepted-wrong safety qualification; run fresh package tests, unsigned
device/simulator builds and physical camera validation, then inspect CI results. No independent security audit is claimed.
Software licensing does not settle trademark/patent claims about the carrier.


## Dependency advisory scope checked

[Debian's CVE-2026-9672 tracker](https://security-tracker.debian.org/tracker/CVE-2026-9672)
and the [upstream PHP/libgd patch](https://github.com/php/php-src/commit/b590f0380fda26ed180874a0255f0be078434315)
identify a GIF decoder LZW defect. The Apple vendored source subset excludes
`gd_gif_in.c`; the C++ CLI selects only PNG/JPEG loaders. A reachable Qyoo
vulnerability from this advisory was not established. System libgd users should
apply their distributor's security updates; version `2.3.3` alone does not
identify the distributor patch level. This scoped check is not a blanket
security clearance for libgd or all transitive codecs.
