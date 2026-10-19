# Historical image metadata: exact scope and owner options

Inspection date: 2026-10-18. FACT unless identified otherwise. No coordinate,
capture-time or other EXIF values are included here. No history or remote ref
was changed. This is a remediation proposal, not authorization to rewrite.

## Confirmed object and revisions

Repository: `qyoocode/QyooDetector-iOS`.
Path: `Tests/QyooDetectorTests/Fixtures/screen_raw_zero.jpeg`.
Original Git blob: `65871d43ecc5d12fac73f9f234a997006c1d8168`.
Introduction commit: `d56406bad4c55d48c4f99ee95c1fea800ab695da`.
The original blob has nonempty GPS coordinate fields and capture/device metadata.
The audit removes its EXIF segment losslessly at
`6661ce1e036280fe62c2648f86c153bb3ad00984`; compressed image scan data is
unchanged. That commit does not remove the original ancestor blob.

All five locally known commit trees retaining this exact blob at this path:

- `d56406bad4c55d48c4f99ee95c1fea800ab695da`
- `021becc75bd35834007aeca7a2db0f6451e8692c`
- `a1c3c6d203b503765243428f4fad163babcb79d9`
- `08f234f092cd80c83ca3e103252036ffe2729278`
- `414f0ecea244c133f8da4b3ae925cbe8d95159d3`

`git rev-list --objects --all` associates the blob with the path above.
This bounds known local objects; it does not inventory forks or hidden refs.
Live read-only `git ls-remote --heads --tags origin` advertises exactly:

| Remote ref | Target |
| --- | --- |
| `refs/heads/main` | `021becc75bd35834007aeca7a2db0f6451e8692c` |
| `refs/heads/task-22-empty-payload-safety` | `a1c3c6d203b503765243428f4fad163babcb79d9` |

No advertised tags were returned. Both advertised branches directly retain the
original image. Locally, main, task-11-portable-core, task-22-empty-payload-safety,
codex/phase6-hybrid-wrapper and their relevant origin-tracking refs retain it;
the audit branch retains it through ancestry despite sanitizing its tip.

## Remediation options and consequences (PROPOSAL)

1. Publish reviewed sanitized current files on both public branches. This stops
   normal latest-file downloads exposing EXIF but leaves old commits, raw links,
   clones and archives readable. It is the lowest disruption option and is not
   historical erasure. Include the sanitized fixture digest/guard on both lines.
2. If the owner explicitly authorizes exact history treatment, prepare a separate
   replacement-history review for **every** affected public branch and descendant,
   replacing only this image blob with the sanitized image. Preserve a restricted
   recovery copy according to owner policy. Do not execute rewriting from this
   document. Rewriting changes affected commits and descendant IDs; all current
   SHA pins, source links, provenance records, checksums and release evidence need
   an explicit migration map. In particular app detector pin a1c3c6d is affected.
3. A repository host privacy-removal request may be needed for cached views,
   unreachable objects and pull-request refs. Coordinate with the host before
   claiming erasure; a branch force update alone does not purge those surfaces.
4. Inspect forks, downloads, release assets, mirrors and collaborators' clones
   under separate authorization. Fork owners must cooperate; old objects can be
   reintroduced by merges or pushes. Tell collaborators how to preserve unrelated
   work and migrate to replacement history; do not instruct blanket deletion.
   Existing tag links would require review if tags are later discovered; none
   were advertised in this bounded check. Existing issue/PR/commit links may
   break or keep old cached content. Assess notification with the owner without
   publishing the metadata values or unnecessarily amplifying a raw-image link.

No published-photo authorship or consent is inferred from a Git author name.
No complete fork/PR-ref/cache inventory or legal conclusion is claimed.
