"""
ref_arc.py -- pure-Python reference implementation of the
              drift-free arc algorithm shipped in ../ARC.asm.

This is THE SPEC. The Z80 code is correct iff its output (set of
plotted pixels, plus final COORDS) matches the output of this
module for the same inputs.

The algorithm is described in docs/PRECISION_ANALYSIS.md, sec 3.
The maths is in IEEE 754 double here; on the Spectrum it is in
5-byte FP. The integer inner loop is identical at the bit level.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class ArcInput:
    """One DRAW x_chord, y_chord, theta from current position P1.

    Coordinates use ZX BASIC's convention: origin at bottom-left,
    Y increasing upward. The screen is 256 x 192 pixels.
    """

    x1: int           # start point X (BASIC coords)
    y1: int           # start point Y
    dx: float         # chord X
    dy: float         # chord Y
    theta: float      # signed sweep angle, radians


@dataclass(frozen=True)
class ArcResult:
    cx: int                    # rounded centre, screen coords
    cy: int
    r: int                     # rounded radius
    ux: int                    # signed start radius vector
    uy: int
    vx: int                    # signed end radius vector
    vy: int
    sigma: int                 # +1 (CCW) or -1 (CW)
    major: bool                # |theta| > pi
    pixels: frozenset[tuple[int, int]]   # set of (x, y) in BASIC coords


# ---------------------------------------------------------------------------
# Helper: Bresenham midpoint circle, exactly as `NEW CIRCLE AND ARC.asm`
# walks it -- one octant from (R, 0) to where x == y, emitting the 8
# symmetric points each step.
# ---------------------------------------------------------------------------

def bresenham_circle(r: int) -> Iterable[tuple[int, int]]:
    """Yield (rx, ry) -- pixel offsets from the centre -- for one
    pass of the midpoint circle.

    The order matches what the Z80 emits: octant by octant within each
    Bresenham step. This makes Z80-vs-spec lockstep diffs trivial.
    """
    x, y = r, 0
    err = 0
    while x >= y:
        # 8-fold symmetry in the same order as the Z80 octant table.
        yield (+x, +y)
        yield (+x, -y)
        yield (-x, +y)
        yield (-x, -y)
        yield (+y, +x)
        yield (+y, -x)
        yield (-y, +x)
        yield (-y, -x)

        # Bresenham step (same arithmetic as the assembly).
        err += 1 + 2 * y
        y += 1
        if err - x - 1 >= 0:
            err += 1 - 2 * x
            x -= 1


# ---------------------------------------------------------------------------
# Membership predicate -- see docs/PRECISION_ANALYSIS.md, sec 3.1.
# ---------------------------------------------------------------------------

def in_arc(
    rx: int, ry: int,
    ux: int, uy: int,
    vx: int, vy: int,
    sigma: int, major: bool,
) -> bool:
    a = ux * ry - uy * rx
    b = rx * vy - ry * vx
    if sigma < 0:
        a, b = -a, -b
    if not major:
        return a >= 0 and b >= 0
    return not (a < 0 and b < 0)


# ---------------------------------------------------------------------------
# Top-level: compute everything `ARC.asm` would compute and return the
# pixel set.
# ---------------------------------------------------------------------------

def draw_arc(inp: ArcInput) -> ArcResult:
    # Setup -- floating point.
    d = math.hypot(inp.dx, inp.dy)
    if d == 0.0:
        return ArcResult(inp.x1, inp.y1, 0, 0, 0, 0, 0,
                         +1, False, frozenset({(inp.x1, inp.y1)}))
    half_a = inp.theta * 0.5
    sin_h = math.sin(half_a)
    if sin_h == 0.0:
        # 360-degree (or no-op) -- degenerates to a straight line.
        # The Z80 routine hands off to LINE_DRAW; we emulate by emitting
        # nothing and letting the caller cope. (Out of scope here.)
        return ArcResult(inp.x1, inp.y1, 0, 0, 0, 0, 0,
                         +1, False, frozenset())

    r = d / (2.0 * sin_h)
    sgn = 1 if inp.theta >= 0 else -1
    h = math.sqrt(max(0.0, r * r - (d / 2.0) ** 2)) * sgn
    # ZX FP rounds via banker's-style truncation in many ops; here we
    # use round-half-to-even which matches the typical FP behaviour
    # closely enough for visual identity. The Z80 may differ by +-1 in
    # the centre coordinate for borderline inputs.
    mid_x = inp.x1 + inp.dx / 2.0
    mid_y = inp.y1 + inp.dy / 2.0
    cx = mid_x + h * (-inp.dy / d)
    cy = mid_y + h * (+inp.dx / d)

    cx_i = int(round(cx))
    cy_i = int(round(cy))
    r_i  = int(round(abs(r)))

    ux = inp.x1 - cx_i
    uy = inp.y1 - cy_i
    vx = int(round(inp.x1 + inp.dx)) - cx_i
    vy = int(round(inp.y1 + inp.dy)) - cy_i

    major = abs(inp.theta) > math.pi + 1e-9

    pixels = set()
    for rx, ry in bresenham_circle(r_i):
        if in_arc(rx, ry, ux, uy, vx, vy, sgn, major):
            px = cx_i + rx
            py = cy_i + ry
            if 0 <= px < 256 and 0 <= py < 192:
                pixels.add((px, py))

    # Force endpoint -- matches the Z80's final-step PLOT.
    end_x = cx_i + vx
    end_y = cy_i + vy
    if 0 <= end_x < 256 and 0 <= end_y < 192:
        pixels.add((end_x, end_y))

    return ArcResult(
        cx=cx_i, cy=cy_i, r=r_i,
        ux=ux, uy=uy, vx=vx, vy=vy,
        sigma=sgn, major=major,
        pixels=frozenset(pixels),
    )
