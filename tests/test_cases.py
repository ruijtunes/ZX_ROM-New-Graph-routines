"""
test_cases.py -- catalogue of arc tests. Each case is a name and an
ArcInput. The same catalogue drives:
  - run_visual.py     (render reference PNGs you eyeball)
  - make_tap.py       (build a BASIC driver that calls the routine)
  - compare_screen.py (diff Fuse SCREEN$ vs reference per case)
"""

from __future__ import annotations

import math

from ref_arc import ArcInput


CASES: dict[str, ArcInput] = {
    # Cardinal quarter-circles (sanity)
    "quarter_ne":      ArcInput(x1=128, y1=96,  dx= 40, dy= 40, theta=+math.pi / 2),
    "quarter_nw":      ArcInput(x1=128, y1=96,  dx=-40, dy= 40, theta=+math.pi / 2),
    "quarter_cw":      ArcInput(x1=128, y1=96,  dx= 40, dy= 40, theta=-math.pi / 2),

    # Semicircles (boundary between minor and major)
    "semi_top":        ArcInput(x1= 88, y1=96,  dx= 80, dy=  0, theta=+math.pi),
    "semi_bottom":     ArcInput(x1= 88, y1=96,  dx= 80, dy=  0, theta=-math.pi),

    # Major arcs (> pi)
    "major_270":       ArcInput(x1=128, y1= 40, dx=  0, dy= 80, theta=+3 * math.pi / 2),
    "major_300":       ArcInput(x1=120, y1= 50, dx= 20, dy= 70, theta=+5 * math.pi / 3),

    # Tiny arcs (precision sensitive on long radii)
    "tiny_at_r60":     ArcInput(x1=128, y1=96,  dx= 60, dy=  3, theta=+0.1),

    # Long arcs at large R (worst case for the old DDA)
    "long_R80":        ArcInput(x1= 48, y1=96,  dx=160, dy=  0, theta=+math.pi),
    "long_R80_cw":     ArcInput(x1= 48, y1=96,  dx=160, dy=  0, theta=-math.pi),

    # Pathological: chord longer than diameter (should error in BASIC;
    # the algorithm sees |sin(A/2)| < d/(2R) which forces R = d/2 and
    # h imaginary. We skip these in the harness and document the case.
    # (Not in the dictionary.)

    # Asymmetric placement near screen edges (clipping test)
    "near_edge":       ArcInput(x1= 10, y1=10,  dx= 30, dy= 30, theta=+math.pi / 2),

    # User request: start (100,100), chord (100,50), sweep 1.5 rad
    "user_100_100":    ArcInput(x1=100, y1=100, dx=100, dy= 50, theta=1.5),
}
