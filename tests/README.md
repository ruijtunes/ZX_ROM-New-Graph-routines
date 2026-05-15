# Tools and tests

Everything in this directory is for **building and testing** `ARC.asm`.
Nothing here is part of the shipped ZX routines.

## Contents

| File                  | Purpose                                                                  |
| --------------------- | ------------------------------------------------------------------------ |
| `build.ps1`           | Assemble `ARC.asm` for ROM (`$2360`) AND for RAM (`$C000`). Reports sizes and the ROM-slot budget. |
| `ref_arc.py`          | **The spec.** Pure-Python reference implementation of the arc algorithm (identical maths to `ARC.asm`). |
| `render.py`           | Render a pixel set as a PNG and / or as a 6912-byte Spectrum `SCREEN$` blob. |
| `test_cases.py`       | The catalogue of arcs we test, plus parameter sweeps.                    |
| `run_visual.py`       | Render every test case as a `.png` you can eyeball.                      |
| `make_tap.py`         | Pack `arc_C000.bin` into a `.tap` you can `LOAD ""CODE` in Fuse.         |
| `compare_screen.py`   | Diff a `SCREEN$` blob saved from Fuse against the reference set.         |
| `test_ref.py`         | Self-tests for `ref_arc.py` (subset-of-circle, endpoint, complementary). |
| `sjasmplus/`          | Auto-downloaded sjasmplus binary (Z80 cross-assembler). 1.23.0 Win.      |

## Quick start

From the repo root (PowerShell):

```powershell
# 1. Build and check the memory budget.
powershell -ExecutionPolicy Bypass -File tools/build.ps1

# 2. Sanity-check the spec.
python tools/test_ref.py

# 3. Generate the reference PNGs (drift-free truth).
python tools/run_visual.py

# 4. Generate a TAP for Fuse.
python tools/make_tap.py
```

Then in Fuse: **File → Open** the `tools/build/arc_test.tap`. The
loader auto-starts at line 10 and `LOAD "" CODE`s the routine to
`$C000`. The per-test BASIC driver that sets up the FP-CALC stack
and calls `draw_arc_new` is **not yet packaged**—adding it is the
final piece for fully automatic round-trip diffing (see below).

## What "testing" means here

There are three independent test layers:

1. **Algorithm correctness** — `ref_arc.py` is the truth. It executes
   the same maths as `ARC.asm`: compute `C`, `R`, `u`, `v` exactly in
   floating point, then run integer Bresenham + cross-product gate.
   By construction the **set of pixels emitted is a subset of the
   Bresenham digital circle of radius R about C** — that is the
   property the precision analysis proves. `ref_arc.py` makes this
   property observable: it returns exactly that subset.

2. **Visual correctness** — `run_visual.py` renders every test case
   as a 256×192 PNG matching the Spectrum SCREEN$ layout (1 bpp,
   ink black on white). Eyeball them.

3. **Bit-exact Z80 correctness** — `compare_screen.py` takes a
   `SCREEN$` blob (6912 bytes) saved from a real Spectrum (or Fuse)
   running the assembled `ARC.asm`, and diffs it against the reference.
   Equal → the Z80 code is bit-exact with the spec. Different → the
   diff visualisation shows you exactly which pixels disagree.

## Memory budget — read this

`ARC.asm` is **581 bytes** of code. The original ZX ROM arc slot
(`$2360..$2477`) is only **279 bytes**. That means `ARC.asm`,
in its current form, **does not fit as a strict ROM in-place
replacement** — it would overrun into `LINE-DRAW`. There are three
honest options:

* **Run from RAM at `$C000`** — the test harness builds this way by
  default. Patch the ROM `DRAW` dispatcher with a `JP $C000`. Costs
  3 bytes in ROM.
* **Relocate `LINE-DRAW`** in a customised ROM image — `LINE-DRAW`
  is ~250 bytes and can be moved anywhere ROM has room.
* **Shrink the routine** — the obvious wins are: share the
  Bresenham step with `CIRCLE` (saves ~80 bytes), reuse the existing
  `NEW CIRCLE AND ARC.asm` FP setup instead of duplicating it
  (saves ~150 bytes). Estimated reachable size: **~300 bytes**,
  which would fit. Not done in this iteration.

`build.ps1` prints the current size every time so the budget is
always visible.

## Fuse (the emulator) — install

Fuse is the canonical Spectrum emulator on every platform. On
Windows, download the installer from the project page on
SourceForge and run it. It does not need elevation if you choose
a user-writable install directory.

The harness does not auto-install Fuse because the SourceForge
download is an interactive installer. Anything Fuse-compatible
(Spectaculator, Spin) will also work for the visual round-trip.

## Current state

* **Algorithm + visual layers: working.** `python tools/test_ref.py`
  and `python tools/run_visual.py` both pass; the PNGs in
  `tools/build/visual/` are correct (sanity-checked: quarter circles,
  semicircles, 270° major, near-edge clipping).
* **Build layer: working.** `tools/build.ps1` assembles both
  variants (`arc_ROM.bin`, `arc_C000.bin`, 581 bytes each).
* **TAP layer: minimal.** `make_tap.py` packs the binary plus an
  auto-starting loader, but a per-test BASIC driver that pushes the
  FP-CALC arguments and calls `$C000` still needs to be written.
  Once that exists, `compare_screen.py` is the final piece: diff
  the resulting `SCREEN$` against `ref_arc.py`.
