"""
run_visual.py -- render every test case as a PNG you can eyeball.

The PNG is the reference: what `ARC.asm` *should* draw if it matches
the spec. Pixels are scaled 4x for readability.

Output: tools/build/visual/*.png
"""

from __future__ import annotations

import sys
from pathlib import Path

# Run from anywhere -- make ./tools importable.
sys.path.insert(0, str(Path(__file__).parent))

from ref_arc import draw_arc                                 # noqa: E402
from render import render_png                                # noqa: E402
from test_cases import CASES                                 # noqa: E402


def main() -> None:
    out_dir = Path(__file__).parent / "build" / "visual"
    out_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    for name, inp in CASES.items():
        res = draw_arc(inp)
        path = out_dir / f"{name}.png"
        annotate = {
            "case":  name,
            "C":     f"({res.cx},{res.cy})",
            "R":     res.r,
            "theta": f"{inp.theta:+.3f}",
            "pix":   len(res.pixels),
            "major": res.major,
        }
        render_png(res.pixels, path, scale=3, annotate=annotate)
        rows.append((name, res.cx, res.cy, res.r, len(res.pixels), res.major))

    # Summary line
    print(f"{'case':<16}  {'Cx':>4} {'Cy':>4} {'R':>4} {'pix':>5} major")
    for r in rows:
        print(f"{r[0]:<16}  {r[1]:>4} {r[2]:>4} {r[3]:>4} {r[4]:>5} {r[5]}")
    print(f"\nWrote {len(rows)} PNGs to {out_dir}")


if __name__ == "__main__":
    main()
