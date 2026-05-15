# CIRCLE — midpoint Bresenham replacement for ROM `$2320`

This routine replaces the ROM's `CIRCLE` command. The exact circle
relation

$$ x^2 + y^2 = r^2 $$

is rasterised by the **midpoint circle algorithm** (a 2D specialisation
of Bresenham's). The state machine walks one octant from the top
`(0, r)`, choosing at each step between "east" and "south-east"
according to the sign of the implicit-equation residual `error`, and
emits the eight symmetric pixels by reflection.

The implementation lives in `INTEGRATED.asm` (combined CIRCLE +
ARC + DRAW image, sharing one Bresenham step subroutine with the
new arc routine):

* entry at `$2320` (`L2320`): parses BASIC arguments, then jumps to
  the integer loop;
* `C8LOOP` (the inner loop): one Bresenham step per iteration, with
  eight `Plot_circ` calls per visited octant point;
* fits in the same ROM bytes as the original.

Compared to the ROM original the curve is rounder (the original used a
parametric `cos/sin` walk with truncation that left visible flats at
the cardinal points; see [assets/circle-comparison.png](assets/circle-comparison.png)).

## Why this is the foundation of the new arc

A digital circle drawn by midpoint Bresenham is **exact**: every state
variable is an integer, every transition is integer-only, and the
emitted pixel set is independent of rounding. The new arc routine
(`ARC.asm`) reuses this loop verbatim — gating the emit step on an
integer angular-membership predicate — and inherits the exactness. See
[PRECISION_ANALYSIS.md](PRECISION_ANALYSIS.md) for the proof and the
algorithm.
