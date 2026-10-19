# Public repository audit — 18 October 2026

Inspected default branch `origin/main`:
`021becc75bd35834007aeca7a2db0f6451e8692c`.
Classification: **Swift SDK safety update; app adoption and shipping-binary parity pending**.
Verdict: **HOLD for a newly endorsed Qyoo 4.0 SDK release**. The integration
surface is coherent; macOS tests and unsigned Apple SDK target compilation are
now recorded below. App adoption, exact released-binary linkage, physical camera
qualification and privacy/asset follow-up remain gates. Only the two native
FeatureDetector files changed; Swift executable source and C ABI are unchanged.

## Findings

| Severity | Finding and evidence | Status |
| --- | --- | --- |
| HIGH | [`Tests/QyooDetectorTests/Fixtures/screen_raw_zero.jpeg`](Tests/QyooDetectorTests/Fixtures/screen_raw_zero.jpeg) at inspected main contained EXIF GPS coordinate fields with nonempty latitude/longitude rationals, device metadata and capture time. Values were never printed. | Current-file EXIF removed losslessly; compressed JPEG scan bytes unchanged, manifest hash updated, integrity guard added. Original still exists in Git history. Owner must assess privacy notification/history remediation separately; no rewrite is authorized. |
| HIGH | The read-only current-app source comparison found its detector pin is later than this public snapshot and includes additional empty-payload safety rejection. The later app pin still accepts sparse generated ID1 symbols as0 in the source-equivalent native probe. | Public SDK now vendors qualified public core60aa253; app pin migration remains a separate review. Genuine zero remains in the numeric domain. Numeric 36-bit range and detector acceptance policy must be treated separately. |
| HIGH | The source-equivalent C++ public core accepted a known generated 64×64 maximum-ID PNG as 0 during this audit. | Reproduced RED in Apple API/raw-buffer tests and repaired by qualified public core60aa253. All33 new Apple safety calls pass; actual camera and exact released binary remain unqualified. Public C++ release-safety fixture/gate retains the exact reproduction. |
| HIGH | Camera photograph redistribution rights are not established by repository documentation. | Owner/legal confirmation required. Existing photos retained, except privacy metadata removal. |
| MEDIUM | CML license was missing from the license bundle despite redistribution of 301 headers; [`cml/version.h:2`](Sources/CQyooDetectorCore/cml/version.h#L2) retains upstream placeholder text. | Complete upstream Boost 1.0 license restored; exact source fingerprint and scope documented without invented copyright or source rewriting. |
| MEDIUM | Initial audit lacked fresh Apple results. | Follow-up: macOS build/11tests PASS; unsigned iOS device/simulator target compilation results below. No device or simulator runtime qualification. |
| LOW | Installation example tracked mutable main and provenance used internal task language. | Example pins inspected public commit; provenance now describes a source snapshot, not an internal task. |

## Native provenance and application comparison

`python3 scripts/verify_sources.py --cpp ../QyooDetector-CPP` verified all
322 source files against C++ commit
`60aa253c074e69922084a66fea67a73aa2c93531`: one public C header,
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
lossless EXIF removal and updated manifest digest. Follow-up adds the qualified contradictory-empty native rejection and three
C-generator known-answer fixtures/tests. No wrapper/C ABI or geometry change. Git history preserves the original photograph bytes.

## Initial audit verification (before safety continuation)

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


## Shipping-impact follow-up: source identity versus binary proof

FACT: source `b8e13f4b3ca40320ea3c6f4c9e8bc1da2345b87a` is the retained
uploaded/selected 4.0/build 2 baseline. Both its committed `Package.swift` and
Xcode `Package.resolved` pin detector
`a1c3c6d203b503765243428f4fad163babcb79d9`. Retained
`Qyoo-iOS/.codex-work/phase3a/Qyoo-iOS/.codex-work/final-build-2/archive.log`
line 8 resolves that detector revision and line 405 records compiling its
`FeatureDetector.cpp`; `release-build.log` line 11 confirms the same resolution.
The report records archive/export/validation/upload success and selected build 2,
but explicitly predates submission. Its former archive path
`/tmp/Qyoo-AppStore-4.0.2/` and recorded DerivedData package checkout are no
longer present at inspection. No extant archive hash/binary-to-App-Store linkage
was established. Owner-reported approval does not identify the exact released
binary. Do not label the source baseline as the exact approved binary.

FACT: public `021becc75bd35834007aeca7a2db0f6451e8692c` versus a1c3c6d has
exactly two executable native file differences: `core/FeatureDetector.cpp` and
`.h`; the only other `Sources` difference is provenance text. The later code
counts sampled foreground pixels and rejects an all-zero grid **only for
NormalizationCarrierTemplate** when aggregate support reaches one dot's minimum
threshold. It clears candidate bits and reports
`carrier_template_empty_payload_rejected`; it does not blanket-reject payload
zero or alter a decoded bit. This specifically addresses contradictory
foreground evidence in that normalization path. It does not by inspection prove
that the separate C-generated 64px maximum-ID incident is rejected.

FACT: Phase3a and active experience-bridge iOS worktree HEADs both read b8e13f4;
respectively 2 and 61 status entries existed at inspection. Neither worktree was
modified. Both retain the a1c3c6d app pin. The app-facing
`Sources/QyooScannerCore/QyooDetectionEngine.swift` calls pixel-buffer detection
and maps returned results; it does not add an ID-zero filter. `ScannerResult`
copies the payload without reinterpretation. Native safety therefore matters to
current app source. No actual Apple pixel-buffer or shipping-binary result for
the C64 fixture is established by these source comparisons. Public SDK tests
remain unchanged during this follow-up; no build/test/simulator/device was run.

**Superseding measured source-impact result:** the continuation's first repaired
public native probe exactly reproduced `FeatureDetector.cpp` and `.h` from
app-pinned a1c3c6d (SHA-256 respectively
`eebe73ce4e51e165f089f4f126771bc1c55e1931beb15f175c6f98b21affdac9` and
`a3d7f8761ac99b9914f225375a5388c31fd4158077f2d97f0239a5771be94090`).
The repair came from native source commit
`5b23d087b702300d5d36e82ebda91dcca74728b1`. The 42-case C-generated scale
probe yielded **18 correct, 4 accepted-wrong, 20 rejected, 0 processing errors**.
Maximum-ID64px was safely rejected, but payload1 at64/68/96/128px was accepted
as0: aggregate foreground remained below the one-dot threshold. Exact case
outcomes and source-equality evidence are retained in workspace
`.codex-work/public-repo-audit/continuation-evidence.json`, fields
`first_repair_scale_probe` and `app_core_repair_equality`.

FACT: this demonstrates a remaining false-empty defect in the native source
used by the release-associated app pin, in a native harness; it supersedes any
inference that the later safety guard fully addresses the newly probed class.
It is not a reproduction through CGImage/CVPixelBuffer or the exact approved
binary. Exact approved-binary linkage remains unknown. Native-source safety and
Apple-path qualification are separate, open release gates.

FACT: the strengthened public core is now vendored from
`60aa253c074e69922084a66fea67a73aa2c93531`. Foreground under the existing
radiance/contrast predicate contradicts a claimed empty grid in either the
higher-resolution template-grid envelope or final sampler. The rejection changes
no decoded bits and reserves no ID. Parent's179-case native qualification reports
136correct,42rejected,1true-negative,0accepted-wrong,0errors. Five genuine C-zero
cases at64/68/96/128/256px now reject; all7 frozen Apple positives retain results.
These bounded corpus measurements do not establish general camera accuracy.
No private app source or pin was changed by this follow-up.

Read-only dependency recheck: GitHub upstream CML tree
`0bb27c8637dd9cdc92b2f376a9e8c08eb649920f` was non-truncated; all 301 local
headers have identical Git blob hashes, and upstream LICENSE is byte-identical
to `LICENSES/CML-Boost-1.0.txt`. Upstream README names Boost. This supports
attribution/license restoration while leaving historical import-chain uncertainty
explicit. The original C generator SVG helper has no file-level attribution;
its reachable path history begins at `7d269bd` (initial import). That is not
proof of authorship or a third-party grant. Owner confirmation remains open.

Exact historical metadata object/ref scope and non-executed owner options are
in [PRIVACY_REMEDIATION.md](PRIVACY_REMEDIATION.md). No metadata values were
printed, no private/source project was edited and no refs were rewritten.


## Safety continuation: fresh Apple verification

Run from this isolated SDK worktree; logs are retained in ignored `.codex-work/`.

| Command | Actual result |
| --- | --- |
| `python3 scripts/verify_sources.py --cpp ../QyooDetector-CPP` | PASS:11fixture hashes/ranges and322native/header files match60aa253; only historical QyooModel Clang diagnostic scope excepted. |
| `swift test --jobs 2 --filter ReleaseSafetyTests` before vendoring | RED:2tests,33accepted-wrong assertions,0unexpected errors; raw BGRA/GRAY, CGImage and all8CVPixelBuffer orientations reproduced false0 for3known-answer fixtures. |
| `swift build --jobs 2` after vendoring | PASS. |
| `swift test --jobs 2` after vendoring | PASS:11tests,0failures in75.9s; includes7frozen positives/1negative CAPI-vsSwift regression, orientation/lifecycle and33safety calls requiring exact payload or rejection. |
| Initial `xcodebuild -list -json` package-root probe | FAIL exit66: directory does not contain an Xcode project/workspace/package recognized by this CLI. Sandbox CoreSimulator connection warnings also occurred. No simulator booted. |
| `swift build --jobs 2 --target QyooDetector --triple arm64-apple-ios15.0 --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk` | PASS:unsigned device library target compilation,4.57s. |
| `swift build --jobs 2 --target QyooDetector --triple arm64-apple-ios15.0-simulator --sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator26.5.sdk` | PASS:unsigned Simulator library target compilation,4.53s; no runtime boot. |

README and CI now use the working SwiftPM cross-compilation commands with the
installed SDK path from xcrun. This proves library target compilation, not a
signed/linked consumer app or physical-camera qualification. New CI remains
unpublished/unrun remotely. Swift production source/orientation logic is unchanged.
The new tests retain independent C-generator ID oracles; processing errors throw
and cannot be counted as safe rejection. Zero accepted-wrong across33safety calls
is distinct from detection-rate claims. The original app and released binary
were not changed/tested by this SDK work.

Storage: start22,874,615,808B available; after macOS suite22,604,566,528B;
after device compilation22,551,367,680B; after Simulator compilation22,499,131,392B
(the actual final reading is in `.codex-work/apple-results.json`). One reusable
`.build/` is roughly367MB, scratch logs/results under40KB. Volume decline about
375MB is not attributed solely to this work. Both SDK architectures reuse the
same SwiftPM scratch root; no DerivedData/project/dependency copy was created.
All build/log evidence retained for review; no cleanup or space reclamation.
The volume remains above20GiB. No simulator/device/signing/production action.
