# formal-proof: what the verify image must hold

The `formal-proof` evaluator (`evaluator.json` beside this file) starts its tools by absolute path inside the
verify VM. This note says what the verify image must provide for that entry, what it must not contain, and the
check the owner runs on the real image to prove the pins. The image is defined in `adapters/verify-image/Dockerfile`
and built by the owner with the steps in `adapters/verify-image/BUILD.md`. The owner built it on 2026-11-18, and the
sandbox registry's verify entry names it by digest since AC-04 and AC-11 were recorded on 2026-11-19 (Q23). When no
verify VM can be created, the evaluator fails closed with `sandbox-unavailable`, and a tool a probe cannot start is
`tool-missing`. No formal-proof deed has yet run in a verify VM.

## Tools and pins

The table is the registry entry's, row for row; a test (`adapters/evaluator-image.test.mjs`) fails when the two
differ.

| Tool | Pinned version | Absolute path | Probe |
|---|---|---|---|
| lean | 4.35.0 | /opt/hlo/lean/bin/lean | `/opt/hlo/lean/bin/lean --version` |
| lake | 4.35.0 | /opt/hlo/lean/bin/lake | `/opt/hlo/lean/bin/lake --version` |
| rocq | 9.3.0 | /opt/hlo/rocq/bin/rocq | `/opt/hlo/rocq/bin/rocq --version` |

| Pinned file | Value |
|---|---|
| lean-toolchain | leanprover/lean4:v4.35.0 |

`lake` and `lean` are one Lean toolchain directory (`/opt/hlo/lean`, with both in `bin/`): Lake uses the Lean
it is installed beside ("joint home") unless `LAKE_OVERRIDE_LEAN` is set, and the verify exec sets no such
variable. The pin for `lake` is the Lean version its probe line names, not Lake's own version number.

## Where each tool comes from

The Dockerfile names every source and checksum. In short:

- Lean is the official release tarball for Linux, checked against the sha256 that GitHub lists for it, unpacked
  into `/opt/hlo/lean`.
- Rocq is installed with opam, the route Rocq's own install notes recommend, from opam-repository at a fixed
  commit. It goes into an opam switch whose prefix is `/opt/hlo/rocq`, so the final stage copies it to the path it
  was built for. The switch also holds the OCaml compiler it was built with. Rocq is configured without its native
  compiler, so no step calls it.
- The image's base is an official Debian image, pinned by digest in the Dockerfile.

## What the image must not contain

- No coding agent, no agent login, and no credential of any kind.
- No `elan` and no other toolchain installer: the entry's tools are started by path, and a `lean-toolchain` that
  differs from the pin is refused by the host, and nothing in the image could act on it.
- No network tool the steps do not need (`curl`, `wget`, `git`): the steps need none, and the verify VM is opened
  to no host for this evaluator. The build fetches with them in a build stage that never reaches the final image.
- No library the image does not pin. For Lean there is none: a deed whose build needs a Lean dependency (mathlib
  included) fails closed. For Rocq, the image holds Corelib, which comes with Rocq, and the Rocq Stdlib, at the
  release the Dockerfile pins (below). A deed that needs any other Rocq library fails closed.

## Open, for the owner (not pinned)

The registry entry has no field for a library, so neither item here is pinned in it, and neither is checked by a
probe. The test that guards this note checks that each item here says so.

- mathlib: **unpinned**, and left out of the image (owner decision, 2026-11-13): a proof that imports it fails
  closed. Looked up earlier, not applied: tag v4.35.0, commit 56a005855ea17e0b0958f73ec801ae140b0a1679, whose
  `lean-toolchain` is the entry's pinned value.
- Rocq Stdlib: **unpinned** in the registry entry, which has no field for it. The image installs Stdlib 9.2.0
  (opam `rocq-stdlib.9.2.0`), the release whose notes say "Compatible with Rocq 9.1, 9.2 and 9.3"
  (https://github.com/rocq-prover/stdlib/releases/tag/V9.2.0), and the build fails if `From Stdlib Require Import
  Arith.` does not compile. It is listed for the owner to confirm.

## The owner-run check

Run inside a VM created from the image, as the tool user, before the image's digest is named in the sandbox
registry. The owner ran these checks on 2026-11-18 and again on 2026-11-19: each probe's first line matched, and none of
`elan`, `curl` and `wget` was found. The `sbx` version, the digest and the output are recorded in `adapters/verify-image/BUILD.md`, "The recorded run". `adapters/verify-image/BUILD.md` step 6 lists these with the rest of AC-04 and AC-11. Record the date, the
`sbx` version and the digest with the output.

```
/opt/hlo/lean/bin/lean --version
/opt/hlo/lean/bin/lake --version
/opt/hlo/rocq/bin/rocq --version
command -v elan curl wget; echo "absent: $?"
```

Expected: the first line of each probe matches the entry's `versionPattern` and captures the pinned version:

- `Lean (version 4.35.0, <target>, commit <40 hex>, Release)`
- `Lake version <x.y.z>-src+<7 hex> (Lean version 4.35.0)`
- `The Rocq Prover, version 9.3.0`
- the last line ends in `absent: 1` and nothing before it names a path.

These line formats were read from the pinned releases' sources, and the owner's run printed them. The image build
checks each first line against the entry's pattern and fails if one differs. If the line in the verify VM differs, the entry's
`versionPattern` is wrong, and the image is not used until the entry is corrected.
