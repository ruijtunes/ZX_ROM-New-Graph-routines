#!/usr/bin/env python3
"""Generate a Fuse-loadable .sna snapshot for a single arc test case.

A .sna snapshot is a 48K memory dump preceded by a 27-byte header that
encodes the CPU state.  When loaded, Fuse RETN's into the address at the
top of the stack -- so we put our test_main address there and let it run.

Usage:
    python tests/make_sna.py [case_name]   # defaults to "quarter_ne"
"""

from __future__ import annotations
import sys, struct
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))

from test_cases import CASES        # noqa: E402
from make_tap import fp5            # noqa: E402  -- reuses bit-exact fp5

BUILD = HERE / "build"
SHIM_BIN = BUILD / "test_main.bin"   # produced by build.ps1
SHIM_SYM = BUILD / "test_main.sym"

# Symbol parser
def load_syms(path: Path) -> dict[str, int]:
    out = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or ':' not in line and '=' not in line:
            continue
        # sjasmplus default sym format: "<name>: equ <hex>" or "<name>  <hex>"
        parts = line.replace(':', ' ').replace('=', ' ').split()
        if len(parts) >= 2:
            name = parts[0]
            try:
                val = int(parts[-1], 16)
            except ValueError:
                continue
            out[name] = val
    return out


def build_sna(name: str, inp) -> bytes:
    syms = load_syms(SHIM_SYM)
    test_main = syms["test_main"]

    shim = SHIM_BIN.read_bytes()
    shim_org = 0xC000

    # 48K RAM image $4000..$FFFF
    ram = bytearray(0xC000)        # 49152 bytes

    def poke(addr: int, data: bytes):
        off = addr - 0x4000
        ram[off:off+len(data)] = data

    # screen attributes: paper 7 (white) / ink 0 (black) everywhere
    poke(0x5800, bytes([0x38]) * 768)

    # shim code at $C000+
    poke(shim_org, shim)

    # COORDS (BASIC's current PLOT pos)
    poke(0x5C7D, bytes([inp.x1 & 0xFF, inp.y1 & 0xFF]))

    # arc args at $5B10/$5B15/$5B1A as 5-byte FP
    poke(0x5B10, fp5(inp.dx))
    poke(0x5B15, fp5(inp.dy))
    poke(0x5B1A, fp5(inp.theta))

    # initial stack: place test_main address on top so RETN jumps there.
    sp = 0x7FFE
    poke(sp, bytes([test_main & 0xFF, (test_main >> 8) & 0xFF]))

    # 27-byte SNA header
    hdr = bytearray(27)
    hdr[0]    = 0x3F
    hdr[15:17] = struct.pack("<H", 0x5C3A)
    hdr[19]   = 0x00                          # IFF disabled
    hdr[23:25] = struct.pack("<H", sp)
    hdr[25]   = 1                             # IM 1
    hdr[26]   = 7                             # border white

    return bytes(hdr) + bytes(ram)


def main():
    case_name = sys.argv[1] if len(sys.argv) > 1 else "quarter_ne"
    inp = CASES[case_name]
    sna = build_sna(case_name, inp)
    out = BUILD / f"arc_test_{case_name}.sna"
    out.write_bytes(sna)
    print(f"Wrote {out}  ({len(sna)} bytes)  PC={hex(load_syms(SHIM_SYM)['test_main'])}")


if __name__ == "__main__":
    main()
