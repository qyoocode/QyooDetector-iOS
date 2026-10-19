# Native core provenance

The production detector sources in `core/`, the public header in `include/`,
and the CML headers in `cml/` are a vendored snapshot of
[`qyoocode/QyooDetector-CPP`](https://github.com/qyoocode/QyooDetector-CPP) at:

```text
3a7002fd7cc6075d9bfb19fe537585dc277a9267
```

This snapshot defines the packaged detector baseline. `main.cpp`, `ImageLoader`,
tests, and CLI-only build files are intentionally excluded. Swift calls only
the public C ABI declared by `include/qyoo_detector.h`; no C++ implementation
header is public. The sole source-level Apple patch is a Clang diagnostic scope
around a historical narrowing-conversion warning in `QyooModel.cpp`; it changes
no executable statement.

The native core's raster operations use a source-vendored libgd 2.3.3 snapshot
from tag `gd-2.3.3`, commit:

```text
b5319a41286107b53daa0e08e402aa1819764bdc
```

The source snapshot is curated to the image allocation, pixels, drawing,
resampling, rotation/affine dependencies, allocation helpers, and disabled-PNG
stubs referenced by the unchanged detector objects. Optional image codecs and
font libraries are not compiled because the detector accepts decoded pixels
and its production C API does not expose diagnostic image writing. This
preserves the `GD_LANCZOS3` resampler used by the qualified multiscale policy
without adding PNG/JPEG file loading to the Apple library.

The vendored libgd files contain Clang diagnostic scopes for libgd 2.3.3's
historical narrowing-conversion warnings. These pragmas affect diagnostics only.

Licenses for both vendored projects are in `LICENSES/` at the repository root.


CML's 301 vendored files also match upstream commit
`0bb27c8637dd9cdc92b2f376a9e8c08eb649920f` byte for byte. See
[`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md) for license scope,
upstream placeholder handling, and asset-rights limitations.
