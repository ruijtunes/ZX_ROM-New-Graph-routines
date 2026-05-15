"""
compare_screen.py -- diff a Spectrum SCREEN$ blob against the
reference for a given test case.

Usage:
    python compare_screen.py CASE_NAME path/to/screen.scr

Exit code is 0 iff the two pixel sets are identical.
Writes a per-case diff PNG to tools/build/diff/{case}.png with:
  - black     : pixel in both
  - red       : pixel in emulator, NOT in spec  (false positive)
  - blue      : pixel in spec, NOT in emulator  (missing)
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from PIL import Image                                        # noqa: E402

from ref_arc import draw_arc                                 # noqa: E402
from render import basic_to_screen_xy, scr_to_pixels         # noqa: E402
from test_cases import CASES                                 # noqa: E402


def diff(case: str, scr_path: Path) -> int:
    if case not in CASES:
        print(f"unknown case '{case}'. Available:")
        for k in CASES:
            print(f"  {k}")
        return 2

    spec = draw_arc(CASES[case]).pixels
    emu  = scr_to_pixels(scr_path.read_bytes())

    same    = spec & emu
    only_e  = emu  - spec   # false positives
    only_s  = spec - emu    # missing

    print(f"case '{case}':")
    print(f"  spec pixels      : {len(spec)}")
    print(f"  emulator pixels  : {len(emu)}")
    print(f"  matching         : {len(same)}")
    print(f"  false positives  : {len(only_e)}  (red)")
    print(f"  missing          : {len(only_s)}  (blue)")

    # Render a coloured diff
    img = Image.new("RGB", (256, 192), (255, 255, 255))
    px = img.load()
    for x, y in same:
        sx, sy = basic_to_screen_xy(x, y)
        px[sx, sy] = (0, 0, 0)
    for x, y in only_e:
        sx, sy = basic_to_screen_xy(x, y)
        px[sx, sy] = (220, 0, 0)
    for x, y in only_s:
        sx, sy = basic_to_screen_xy(x, y)
        px[sx, sy] = (30, 60, 220)
    img = img.resize((256 * 3, 192 * 3), Image.NEAREST)

    out_dir = Path(__file__).parent / "build" / "diff"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{case}.png"
    img.save(out_path)
    print(f"  diff image       : {out_path}")

    return 0 if (not only_e and not only_s) else 1


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    return diff(argv[1], Path(argv[2]))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
