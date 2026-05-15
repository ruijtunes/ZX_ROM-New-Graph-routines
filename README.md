# ZX Spectrum — new graphics ROM routines

Drop-in assembler replacements for four ZX Spectrum ROM graphics
routines, plus a new exact arc-drawing routine.

| Routine          | Source             | ROM slot        | Doc                                  |
| ---------------- | ------------------ | --------------- | ------------------------------------ |
| PLOT             | `ZXPLOT.asm`       | `$22E5`         | [docs/PLOT.md](docs/PLOT.md)         |
| CIRCLE + ARC + DRAW (shared step) | `INTEGRATED.asm` | `$2320` / `$2360` / `$2382` | [docs/CIRCLE.md](docs/CIRCLE.md), [docs/ARC.md](docs/ARC.md) |
| ARC only (standalone)             | `ARC.asm`        | `$2360`         | [docs/ARC.md](docs/ARC.md)           |
| RND              | `Rand.asm`         | `$25F8`         | [docs/RND.md](docs/RND.md)           |

## What's new in this revision

`ARC.asm` is a new arc routine with **zero radius drift by
construction**. The previous arc implementation (rotational DDA in
5-byte FP) was provably drifty for long arcs at the Spectrum's FP
precision. The new implementation runs a pure-integer Bresenham
circle (the same one that backs `CIRCLE`) and gates each emitted
pixel by two integer cross products. No floating point inside the
loop. Same pixel set as `CIRCLE` for the corresponding full circle.

`INTEGRATED.asm` combines `CIRCLE`, the new `ARC` and the `DRAW`
dispatcher in one image that shares a single Bresenham step
subroutine (`bres_step`) between `CIRCLE` and `ARC`. Sizes:

| Block                          | Bytes |
| ------------------------------ | ----: |
| CIRCLE setup                   |    46 |
| Plot_circ                      |     8 |
| `bres_step` (shared)           |    39 |
| C8LOOP (8-octant emit)         |    69 |
| DRAW dispatcher                |    11 |
| ARC (calls `bres_step`)        |   353 |
| L2477 wrapper                  |     6 |
| **Total combined image**       | **532** |

The two-copy variant (CIRCLE + standalone `ARC.asm`, each with its
own inline Bresenham step) totals ~565 bytes, so sharing the step
saves ~33 bytes.

The full mathematical analysis — why the rotation-matrix DDA drifts,
why the standard textbook fixes (Minsky's circle, Singleton/Buneman
stable trig recurrence, Chebyshev recurrence, periodic renormalisation)
each fail to be the right answer here, and what the new algorithm
actually computes — is in
[docs/PRECISION_ANALYSIS.md](docs/PRECISION_ANALYSIS.md).

## Building

All sources are sjasmplus-compatible Z80 assembler. The repository
ships a pinned sjasmplus 1.23.0 under `tests/sjasmplus/`.

Standalone `ARC.asm`:

```
tests/build.ps1                       # builds ROM, C000, Shim, Main variants
```

Combined CIRCLE + ARC + DRAW image:

```
tests/sjasmplus/.../sjasmplus.exe --raw=tests/build/integrated.bin INTEGRATED.asm
```

Integration of `ARC.asm` into a custom wrapper is documented in
[docs/ARC.md](docs/ARC.md#memory-layout-and-integration).

## Testing

The Python reference (`tests/ref_arc.py`) is the executable spec
that the Z80 code is required to match pixel-for-pixel.

```
python tests/test_ref.py              # spec checks (subset, endpoint, coverage)
python tests/run_visual.py            # render every case to docs-style PNGs
```

Fuse-based on-machine validation: build the C000 variant, generate
a `.sna` via `tests/make_sna.py`, then run `tests/run_fuse.ps1`.

## Project layout

```
.
├── README.md                       # this file
├── ZXPLOT.asm                      # PLOT replacement (incl. mask LUT)
├── INTEGRATED.asm                  # CIRCLE + ARC + DRAW (shared bres_step)
├── ARC.asm                         # exact integer arc (standalone / INCLUDE)
├── Rand.asm                        # SAM-style RND
├── docs/
│   ├── PLOT.md
│   ├── CIRCLE.md
│   ├── ARC.md
│   ├── RND.md
│   ├── PRECISION_ANALYSIS.md       # the deep analysis
│   └── assets/
│       ├── circle-comparison.png   # ROM vs new CIRCLE
│       └── arc-equations.png       # arc geometry reference
└── tests/                          # build script, Python spec, sjasmplus, harness
```
