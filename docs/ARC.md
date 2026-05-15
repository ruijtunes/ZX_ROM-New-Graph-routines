# ARC — exact, drift-free circular arc

Two implementations of ZX BASIC's `DRAW x, y, θ` (the three-argument
form, which draws a circular arc from the current PLOT position to
`(x_pos + x, y_pos + y)` sweeping through `θ` radians) have lived in
this repository:

| File                          | Algorithm                              | Radius drift | Status   |
| ----------------------------- | -------------------------------------- | ------------ | -------- |
| (removed) `NEW CIRCLE AND ARC.asm` | Rotational DDA in 5-byte FP        | O(N·ε)       | obsolete |
| `ARC.asm` / `INTEGRATED.asm`  | Bresenham circle + integer angular gate | **0**       | current  |

The mathematical analysis of both algorithms, including why iterative
2D rotation is doomed at finite precision and a survey of the textbook
fixes, is in [PRECISION_ANALYSIS.md](PRECISION_ANALYSIS.md). This page
is the API reference.

## Geometry

The Spectrum's `DRAW` semantics for the arc form: given the current
PLOT position `P1 = (x_pos, y_pos)`, a chord vector `(dx, dy)` and a
signed sweep `θ`, the routine draws the circular arc from `P1` to
`P2 = P1 + (dx, dy)` that subtends central angle `θ` at the circle's
centre. Positive `θ` sweeps counter-clockwise (in screen coordinates,
that is mathematically clockwise — ZX `y` increases downward; we keep
the same convention as the existing routine).

```
              C (centre)
             /|\
            / | \
           /  |  \
          /   h   \
         /    |    \
        P1----M----P2
           d/2 d/2
        <----- d ----->
```

* `d = ‖P2 − P1‖` — chord length
* `R = d / (2·sin(θ/2))` — radius
* `h = √(R² − (d/2)²)` with sign chosen by `sgn(θ)` — perpendicular
  distance from `C` to chord midpoint `M`
* `C = M + h · n̂` where `n̂` is the unit normal to the chord

## Algorithm (the short version)

In one paragraph: compute `C`, `R`, the start radius vector `u = P1−C`
and the end radius vector `v = P2−C` ONCE in FP. Round all four
components of `u` and `v` to signed bytes. Compute two flags from
`θ`: `σ = sgn θ` and `m = (|θ| > π)`. Run the Bresenham circle loop
unchanged. For each of the 8 candidate pixels per Bresenham step,
test angular membership with two integer cross products:

```
A = ux·ry − uy·rx     ; signed 16-bit
B = rx·vy − ry·vx     ; signed 16-bit

minor (m = 0):  accept iff  σ·A ≥ 0  ∧  σ·B ≥ 0
major (m = 1):  reject iff  σ·A < 0  ∧  σ·B < 0
```

If the test passes, call `PLOT_SUB`. Otherwise, drop the pixel. After
the Bresenham scan completes, force-plot `(Cx + vx, Cy + vy)` so the
arc terminates exactly on `P2` and `COORDS` is set correctly for the
next `DRAW` / `PLOT`.

There is **no floating point inside the loop**.

## Cost

Per candidate pixel:

* two signed 8×8 multiplications (the `mul8s` routine in `ARC.asm`,
  shift-and-add, ~140 T-states each),
* one 16-bit subtraction for each cross product,
* a few sign tests,
* a conditional `PLOT_SUB`.

Roughly **300–500 T-states per pixel test**, versus the old routine's
six `FP-CALC` ops per emitted pixel (~9 000–12 000 T-states). At
`R ≈ 40, θ ≈ π` the new arc is **15–25× faster** in addition to being
correct.

## Memory layout and integration

`ARC.asm` is position-independent (no `ORG` inside). It is intended
to be `INCLUDE`d from a wrapper that supplies the ORG, optionally
defines `SHARED_BRES_STEP` to the address of an external Bresenham
step routine, and supplies the surrounding code.

The canonical combined wrapper is `INTEGRATED.asm`, which provides
`CIRCLE`, the `DRAW` dispatcher, an L2477 wrapper, and a shared
`bres_step` subroutine, then `INCLUDE`s `ARC.asm` so its Bresenham
step collapses to a `call bres_step`. The whole image (CIRCLE +
ARC + DRAW + L2477) is 532 bytes.

For a standalone ARC build (no integrated CIRCLE), assemble
`ARC.asm` directly with an `ORG` wrapper and leave `SHARED_BRES_STEP`
undefined; the inline Bresenham step is preserved (387 bytes total).

The routine uses 14 bytes of RAM scratch at `$5B00` (the printer
buffer). On a 48K machine not driving a printer this area is idle.
If your environment uses the printer buffer, relocate `ARC_WORK` to
another free area (e.g. unused MEMBOT slots at `$5C92 + 5·n`).

## Edge cases

| Input                       | Behaviour                          |
| --------------------------- | ---------------------------------- |
| `sin(θ/2) = 0` (full turn)  | Degenerates to `LINE_DRAW`         |
| `d = 0` (zero chord)        | Single pixel at `P1`, exit cleanly |
| `R < 1`                     | Single pixel at `P1` (via `CIRCLE` |
|                             | path; `ARC.asm` does not re-check) |
| `|θ| = π`                   | Treated as minor arc (semicircle)  |
| `|θ| > 2π`                  | Not specially handled; angular     |
|                             | gate degenerates to "accept all"   |
|                             | so a full circle is drawn          |

## Testing

The arc must satisfy:

1. **Pixel-identical match against `CIRCLE`** when `|θ| ≥ 2π` and the
   centre / radius match.
2. **Endpoint coincides with `P2`** for every input (we force this).
3. **No drift on long arcs**: drawing the same arc many times with
   `OVER 1` should leave the screen empty (each pixel toggled exactly
   twice). The old DDA routine fails this for `R ≥ 40, θ ≥ 2π/3`.
4. **Continuity with `DRAW`/`PLOT` chains**: `COORDS` after the arc
   must equal the rounded `P2`.
