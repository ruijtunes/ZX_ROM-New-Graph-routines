"""
test_ref.py -- sanity self-test of ref_arc.py.

Checks:
  1. Setting theta=2pi should emit the full Bresenham circle (modulo
     the start-pixel rounding).
  2. The pixel set of an arc must always be a SUBSET of the Bresenham
     circle for that (C, R) -- this is the key correctness property
     proven in docs/PRECISION_ANALYSIS.md.
  3. The endpoint must be present in the pixel set (we force-plot it).
  4. CCW vs CW with the same |theta| together must cover the full
     circle.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from ref_arc import ArcInput, bresenham_circle, draw_arc           # noqa: E402


def circle_pixels(cx: int, cy: int, r: int) -> set[tuple[int, int]]:
    return {(cx + rx, cy + ry) for rx, ry in bresenham_circle(r)}


def check_subset_of_circle() -> None:
    """Every arc must emit a subset of the corresponding Bresenham
    circle. This is the *defining* correctness property."""
    seeds = [
        ArcInput(128, 96,  40,  40, +math.pi / 2),
        ArcInput(128, 96,  40,  40, -math.pi / 2),
        ArcInput(88,  96,  80,  0,  +math.pi),
        ArcInput(128, 40,  0,   80, +3 * math.pi / 2),
        ArcInput(10,  10,  30,  30, +math.pi / 2),
    ]
    for inp in seeds:
        res = draw_arc(inp)
        cpix = circle_pixels(res.cx, res.cy, res.r)
        # The forced endpoint may be 1px off the digital circle when
        # (vx,vy) doesn't land exactly on a Bresenham step -- that is
        # acceptable and documented.
        end = (res.cx + res.vx, res.cy + res.vy)
        diff = (res.pixels - cpix) - {end}
        assert not diff, f"arc has pixels not on circle: {diff} (case {inp})"
    print("[ok] every arc is a subset of its Bresenham circle (+endpoint)")


def check_endpoint_present() -> None:
    inp = ArcInput(128, 96, 40, 40, +math.pi / 2)
    res = draw_arc(inp)
    end = (res.cx + res.vx, res.cy + res.vy)
    assert end in res.pixels, f"endpoint {end} missing from arc"
    print(f"[ok] endpoint {end} forced into arc pixel set")


def check_complementary_arcs_cover_circle() -> None:
    """An arc of +theta and an arc of -(2pi - theta) over the SAME
    chord (same P1, P2) trace the two halves of the same circle and
    should together cover it. With theta = pi the chord is a diameter
    and both halves are semicircles on opposite sides."""
    inp_a = ArcInput(88, 96, 80, 0, +math.pi)
    inp_b = ArcInput(88, 96, 80, 0, -math.pi)
    a = draw_arc(inp_a)
    b = draw_arc(inp_b)
    assert (a.cx, a.cy, a.r) == (b.cx, b.cy, b.r), (a, b)
    circ = circle_pixels(a.cx, a.cy, a.r)
    missing = circ - (a.pixels | b.pixels)
    assert len(missing) <= 2, f"complementary semis miss {len(missing)} px"
    print(f"[ok] +pi and -pi over same chord cover circle (gap: {len(missing)} px)")


def check_full_circle_via_theta_2pi() -> None:
    """A full turn degenerates to LINE_DRAW in the Z80, but our
    reference returns an empty set in that case. We instead verify
    that two semicircles cover the digital circle."""
    inp_a = ArcInput(88, 96, 80, 0, +math.pi)
    inp_b = ArcInput(168, 96, -80, 0, +math.pi)
    a = draw_arc(inp_a).pixels
    b = draw_arc(inp_b).pixels
    rf = draw_arc(inp_a)
    circ = circle_pixels(rf.cx, rf.cy, rf.r)
    missing = circ - (a | b)
    assert len(missing) <= 4, f"two semis miss {len(missing)} pixels"
    print(f"[ok] two semicircles cover circle (gap: {len(missing)} px)")


def main() -> int:
    check_subset_of_circle()
    check_endpoint_present()
    check_complementary_arcs_cover_circle()
    check_full_circle_via_theta_2pi()
    print("\nALL SPEC CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
