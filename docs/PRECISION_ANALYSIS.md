# Precision analysis of arc drawing on the ZX Spectrum

This document explains, with the maths and the code-level consequences, **why
the iterative-rotation arc algorithm shipped in `NEW CIRCLE AND ARC.asm` drifts
in radius and phase over long arcs**, surveys the textbook fixes, and motivates
the algorithm used in `ARC.asm` — which has **zero radius drift by
construction** (not "small drift": exactly zero, because the inner loop is
pure integer Bresenham, identical to the routine that draws full circles).

The audience is someone comfortable with linear algebra and Z80 / ZX
floating-point internals.

---

## 1. The current algorithm and why it drifts

Given a start point `P₁`, a chord vector `(dx, dy)` and a signed sweep
angle `θ`, the existing routine computes — once, in floating point — the
circle centre `C`, the radius `R`, the number of steps `N = ⌊R·|θ|⌋ + ½`,
the per-step rotation `Δθ = θ/N`, and the constants `c = cos Δθ`,
`s = sin Δθ`. It then walks the radius vector `r = (xᵣ, yᵣ) = P − C` by
left-multiplying it with the 2×2 rotation matrix

$$
\mathbf{R}_{\Delta\theta} \;=\; \begin{pmatrix} c & -s \\ s & \;\;c \end{pmatrix},
\qquad \mathbf{r}_{k+1} \;=\; \mathbf{R}_{\Delta\theta}\,\mathbf{r}_{k}.
$$

In exact arithmetic the matrix is orthogonal — `det = c² + s² = 1` — so the
radius `‖r‖` is preserved exactly. In **finite-precision** arithmetic that
identity holds only up to the unit round-off `ε`. The ZX Spectrum FP format
is 5 bytes, with a 32-bit mantissa, so `ε ≈ 2⁻³²`. After each multiplication
and addition, the *computed* matrix is

$$
\widetilde{\mathbf{R}} \;=\; \mathbf{R}_{\Delta\theta} + \mathbf{E}, \qquad
\|\mathbf{E}\| \;\lesssim\; \varepsilon,
$$

so `det(R̃) = 1 + δ` with `|δ| ≲ ε`, and after `N` iterations the radius is
multiplied by `(1 + δ)^(N/2) ≈ 1 + N·δ/2`. Two distinct error modes are
present:

1. **Radius drift** — `‖rₖ‖ / R ≈ 1 + O(N·ε)`. The arc visibly spirals
   outward or inward for long arcs and large `R`.
2. **Phase drift** — the cumulative effective angle is
   `Σ Δθ + O(N·ε)`, so the endpoint lands O(N·ε·R) pixels away from the
   intended `P₂`.

For a Spectrum with `ε ≈ 2⁻³²` the drift is in principle subpixel up to
`N ≈ 10⁸`, so why is it visible in practice?

* The Spectrum FP routines (`FP-CALC`'s multiply, `sin`, `cos`) are not
  correctly rounded. Their effective ε on a single operation is closer to
  `2⁻²⁷`–`2⁻²⁸`. A multiplication+addition pair already gives `5–10·ε`.
* The transformation is applied to `(xᵣ, yᵣ)` **including** the slowly-
  varying long-range bias, not to a centred perturbation. This means the
  round-off rides on top of values of magnitude `R`, so absolute error is
  `R·ε` per step. For `R = 60` and `N = 200` this can reach **0.4–1 pixel**.
* Each FP-CALC instruction does its own re-stacking, which can renormalise
  in ways that bias one direction systematically.

Empirically: `DRAW 0,0,6.28` (a near-full sweep) draws a curve that
visibly fails to close on long, thin arcs.

---

## 2. The textbook fixes, and why none of them is quite right here

The literature on iterative rotation precision is mature. Here is the
survey, with the honest verdict for the ZX context.

### 2.1 Minsky's circle algorithm (HAKMEM #149, 1972)

Replace the rotation by

$$
x_{k+1} = x_k - \varepsilon\, y_k, \qquad
y_{k+1} = y_k + \varepsilon\, x_{k+1},
$$

with `ε = 2 sin(Δθ/2)`. **Note the asymmetry**: `y` uses the *new* `x`. The
iteration matrix has determinant `1` exactly, so the orbit closes exactly
and there is no radius drift — but the orbit is a **slightly tilted
ellipse**, not a true circle. The eccentricity goes as `ε²/8`. For
`Δθ ≈ 1/R` this is `~1/(8R²)`. At `R = 60` the ellipse has axes differing
by about 1 part in 30 000, i.e. invisibly elliptical for ZX screen
resolution.

**Verdict for us**: excellent and absurdly cheap (two multiplies, two adds
per step — could be done in fixed point), but the orbit is not bit-
identical to the circle that the `CIRCLE` command draws, so a long
`CIRCLE` followed by `DRAW … ,θ` would not align pixel-perfectly. For a
matched look-and-feel with the existing `CIRCLE`, we want the *same*
underlying digital circle.

### 2.2 Singleton / Buneman / "Numerical Recipes" stable trig recurrence

Numerically the dominant error in iterating the rotation matrix is the
catastrophic cancellation hidden in `1 − cos Δθ` for small `Δθ`. The fix
(Singleton 1967, popularised by *Numerical Recipes*) is to store the small
quantity `α = 2 sin²(Δθ/2) = 1 − cos Δθ` and `β = sin Δθ` explicitly, and
iterate

$$
\begin{aligned}
x_{k+1} &= x_k - (\alpha\, x_k + \beta\, y_k), \\
y_{k+1} &= y_k - (\alpha\, y_k - \beta\, x_k).
\end{aligned}
$$

This reduces the per-step error from `O(ε)` to `O(ε·Δθ)` and the cumulative
phase error from `O(N·ε)` to `O(√N·ε)` (random-walk behaviour). It is the
recommended general-purpose fix.

**Verdict for us**: 2× more FP-CALC ops per step than the current code. It
*reduces* drift; it does not eliminate it. We can do better.

### 2.3 Chebyshev three-term recurrence

`cos((k+1)Δθ) = 2 cos(Δθ)·cos(kΔθ) − cos((k−1)Δθ)`, similarly for `sin`.
Stores one constant `2 cos Δθ` and two previous states. Same precision class
as Singleton — `O(√N·ε)`.

**Verdict for us**: no advantage on the Z80; harder to gate-and-plot.

### 2.4 Renormalisation every K steps

After every K rotations, rescale by `1 / √(x² + y²)`. Or use the cheap
first-order Newton step `r ← r · (3 − r·r/R²) / 2`. This caps radius drift
but does not eliminate phase drift and adds a divide / square root every
K steps.

**Verdict for us**: a band-aid. Adds code complexity and is dominated by
the trig setup that we keep anyway.

### 2.5 Exact circle algorithms (Bresenham / midpoint / Pitteway)

A digital circle drawn by Bresenham's midpoint algorithm is *exactly*
defined: integer state, exact transitions, no drift, no cumulative error,
ever. It is what `CIRCLE` already uses in this repo. The challenge is that
Bresenham generates pixels in 8-octant order, not in angular order from
`P₁`, and not naturally restricted to a sub-arc. Pitteway (1967) extended
Bresenham to ellipses and arcs by maintaining additional sign tests on the
implicit equation.

**Verdict for us**: this is the right family. But Pitteway-style sub-arc
state machines are intricate and easy to get wrong for the eight-octant
sweep crossings. We use a simpler, equally exact variant — described in
the next section — that *reuses the existing circle loop verbatim*.

---

## 3. The algorithm shipped in `ARC.asm`

> **Digital-circle traversal with a two-half-plane angular gate.**

In one sentence: run the same Bresenham circle as `CIRCLE`, and for every
one of the 8 symmetric candidate pixels, decide in O(1) integer arithmetic
whether it lies inside the requested angular sweep — if yes, plot it.

### 3.1 The geometry

Let `C = (Cx, Cy)` be the centre and `R` the radius (all computed once in
FP, as today). Let

* `u = P₁ − C` be the radius vector at the *start* of the arc,
* `v = P₂ − C` be the radius vector at the *end* of the arc,
  where `P₂ = P₁ + (dx, dy)`,
* `σ = sgn θ ∈ {−1, +1}` be the sweep direction,
* `m = 1` iff `|θ| > π` ("major arc"), else `m = 0`.

All four of `ux, uy, vx, vy` are bounded by `R`, which on the ZX screen is
at most `≈ 96`. We round them to **signed 8-bit integers**. The total
state needed by the inner loop is **six bytes**: `ux, uy, vx, vy, σ, m`.

For any candidate pixel `p = (rx, ry)` *relative to C*, define the 2D cross
products

$$
A \;=\; \mathbf{u} \times \mathbf{p} \;=\; u_x r_y - u_y r_x, \qquad
B \;=\; \mathbf{p} \times \mathbf{v} \;=\; r_x v_y - r_y v_x .
$$

Each cross product is a signed 16-bit integer (`|u_x|·|r_y| ≤ 96·96 = 9216`,
well inside `±32767`). `sgn(σ·A)` answers "is `p` on the sweep side of
`u`?"; `sgn(σ·B)` answers "is `p` on the sweep side of `v`, looking back?".

The membership test is then:

| arc type             | condition                                |
| -------------------- | ---------------------------------------- |
| minor arc, `m = 0`   | `σ·A ≥ 0`  **and**  `σ·B ≥ 0`            |
| major arc, `m = 1`   | **not** ( `σ·A < 0`  **and**  `σ·B < 0` ) |

The minor-arc case admits only pixels in the lens between the two
half-planes through `C` perpendicular to `u` and `v`. The major-arc case
*rejects* only pixels in the lens of the *complementary* sweep. Both cases
collapse to the same two cross products and two sign tests.

### 3.2 Why this has zero radius drift

The set of pixels emitted by the inner loop is, by construction, a
**subset** of the pixel set that `CIRCLE` itself draws for the same centre
and radius. The radius is encoded as an integer once; the loop state
contains only integers and only updates them by integer Bresenham
transitions. There is no floating-point operation inside the loop, hence
no rounding error, hence no drift.

### 3.3 Phase precision and the endpoint

The only place where finite precision enters is the setup, where `ux, uy,
vx, vy` are rounded from FP to signed bytes. A rounding error of ±½ in
either component perturbs the cross-product zero crossings by at most one
pixel along the circumference. To guarantee the arc *terminates exactly*
at `P₂` (so that subsequent `DRAW`/`PLOT` commands chain correctly), we
explicitly plot `(Cx + vx, Cy + vy)` and write it to `COORDS` as the final
step — independent of whether the Bresenham scan emitted that pixel.

So the residual phase error is **at most one pixel** at start and at
most **zero pixels** at the end (we force it). The classical iterative
rotation gives, at the Spectrum's effective precision, several pixels for
long arcs.

### 3.4 Cost per pixel

Inside the inner loop, per candidate pixel we do:

* two signed 8×8 → 16-bit multiplies (≈ 100 T-states each with a tight
  shift-and-add),
* one subtract for each cross product,
* a couple of sign tests and conditional jumps,
* a conditional call to `PLOT_SUB`.

That is **≈ 300–400 T-states of integer work**, replacing **≈ 6 FP-CALC
operations** (~ 9000–12000 T-states) in the previous algorithm. The
expected speed-up at `R ≈ 40` and `θ ≈ π` is **20–30×**.

### 3.5 Degenerate cases

* `R < 1`: plot the single pixel at `P₁` (handled by existing CIRCLE entry).
* `|θ| < some threshold` (one pixel of arc length): emit `DRAW`-line and
  fall through to `LINE_DRAW`. The existing FP setup already detects
  `sin(θ/2) = 0`; we extend it to detect `R·|θ| < 1`.
* `|θ| ≥ 2π`: clamp the angular gate to "accept all" — the routine
  degenerates to drawing the full digital circle, exactly as `CIRCLE`
  would.

### 3.6 What this routine is **not**

It is not "the optimal sub-pixel arc". Anti-aliased or Wu-style
arc-drawing would require a multi-tone display; the ZX has only one bit
per pixel, so a digital circle's pixel set is *the* correct answer.
Within that constraint, the algorithm is exact and cannot be improved.

---

## 4. Has anyone published this?

The pieces — Bresenham circles, cross-product half-plane tests, angular
sweep gating — are individually classical. The **combination as a
practical arc primitive on an 8-bit microcomputer, using signed-byte cross
products and a single bit for the major-arc case, sharing the host's
existing Bresenham circle scaffolding**, does not appear in the standard
references (Foley/van Dam, Rogers, Hearn/Baker, the ZX Spectrum literature,
nor the `comp.sys.sinclair` / WoS archives I am aware of). The closest
relatives in print are:

* **Pitteway (1967, *Computer J.*)** — extends Bresenham to ellipses and
  conic arcs via a state machine on the implicit form. Different mechanism
  and harder to implement.
* **Van Aken & Novak (1985, *ACM TOG*)** — "Curve-drawing algorithms for
  raster displays", with an arc variant using the explicit equation. More
  general but more expensive.
* **Wu (1991)** — anti-aliased lines and circles. Doesn't apply at 1 bpp.

So while we make no novelty claim — the constituent ideas are decades old
— the engineering combination as described above appears to be original
to this codebase. If you find prior art, we'd be grateful for the
citation; until then, treat it as folklore-by-construction.

---

## 5. Reference: the membership predicate in pseudocode

```text
function in_arc(rx, ry, ux, uy, vx, vy, sigma, major) -> bool:
    A := ux*ry - uy*rx          # cross(u, p), signed 16-bit
    B := rx*vy - ry*vx          # cross(p, v), signed 16-bit

    if sigma < 0:
        A := -A
        B := -B

    if not major:
        return (A >= 0) and (B >= 0)
    else:
        return not ((A < 0) and (B < 0))
```

The Z80 implementation in `ARC.asm` inlines this without temporaries:
`σ` is folded into the cross-product sign tests, so no negation is
performed at run-time.
