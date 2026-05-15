"""
make_tap.py -- pure-Python TAP encoder for the ZX Spectrum.

Produces tests/build/arc_test_<case>.tap. Each TAP contains:

  1. Auto-starting BASIC loader:
       CLEAR 49151
       LOAD ""CODE                  : REM the shim + ARC at $C000
       BORDER 7: PAPER 7: INK 0: CLS
       POKE 23312..23316  dx        : 5 FP bytes
       POKE 23317..23321  dy        : 5 FP bytes
       POKE 23322..23326  A         : 5 FP bytes
       PLOT x1, y1
       RANDOMIZE USR 57344          : = $E000 = arc_test entry
       PAUSE 0                      : wait for keypress

  2. CODE block at $C000 (shim + ARC).

Usage:
    python tests/make_tap.py                 # build all cases
    python tests/make_tap.py CASE_NAME       # build one case
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from test_cases import CASES                                  # noqa: E402


# --------------------------- ZX 5-byte FP --------------------------
#
# Two forms:
#   small int -65535..65535:  00 sign LSB MSB 00   (sign=$FF if neg)
#   real:                     exp m1 m2 m3 m4
#                             where m1's top bit holds the sign and
#                             the rest is the top 7 bits of the
#                             mantissa AFTER the implicit leading 1.

def fp5(x: float) -> bytes:
    if x == 0.0:
        return bytes(5)
    if isinstance(x, int) or (x == int(x) and -65535.5 < x < 65535.5):
        n = int(x)
        if n < 0:
            n &= 0xFFFF
            sign = 0xFF
        else:
            sign = 0x00
        return bytes([0x00, sign, n & 0xFF, (n >> 8) & 0xFF, 0x00])
    sign = 0x80 if x < 0 else 0x00
    ax = abs(x)
    m, e = math.frexp(ax)            # m in [0.5,1)
    biased_e = e + 128
    if biased_e <= 0 or biased_e > 255:
        raise ValueError(f"out of range for ZX FP: {x}")
    # ZX stores the leading mantissa bit at position 7 of byte 1 but
    # OVERWRITES it with the sign bit on store, restoring it (to 1)
    # on load. So we compute the full 32-bit mantissa including the
    # leading 1, then mask off the top bit and OR in the sign.
    bits = int(m * (1 << 32) + 0.5) & 0xFFFFFFFF
    b1 = ((bits >> 24) & 0x7F) | sign
    b2 = (bits >> 16) & 0xFF
    b3 = (bits >>  8) & 0xFF
    b4 = (bits >>  0) & 0xFF
    return bytes([biased_e, b1, b2, b3, b4])


# --------------------------- TAP blocks ----------------------------

def _xor(block: bytes) -> int:
    cs = 0
    for b in block:
        cs ^= b
    return cs & 0xFF


def _tap_block(flag: int, payload: bytes) -> bytes:
    body = bytes([flag]) + payload
    body += bytes([_xor(body)])
    return len(body).to_bytes(2, "little") + body


def header(file_type: int, name: str, length: int, p1: int, p2: int) -> bytes:
    name_b = name.encode("ascii", "replace").ljust(10)[:10]
    return _tap_block(0x00,
        bytes([file_type]) + name_b
        + length.to_bytes(2, "little")
        + p1.to_bytes(2, "little")
        + p2.to_bytes(2, "little"))


def data_block(payload: bytes) -> bytes:
    return _tap_block(0xFF, payload)


# --------------------------- BASIC tokens --------------------------

T = {
    "CLEAR":     0xFD, "LOAD":   0xEF, "CODE":   0xAF, "RANDOMIZE": 0xF9,
    "USR":       0xC0, "PRINT":  0xF5, "SAVE":   0xE2, "SCREEN$":   0xAA,
    "POKE":      0xF4, "PLOT":   0xF6, "BORDER": 0xE7, "PAPER":     0xDA,
    "INK":       0xD9, "CLS":    0xFB, "REM":    0xEA, "LET":       0xF1,
    "PAUSE":     0xF2, "STOP":   0xE3, "GO TO":  0xEC,
}


def num_lit(n) -> bytes:
    """ASCII representation + hidden FP form (0x0E + 5 bytes)."""
    if isinstance(n, int) or n == int(n):
        n_i = int(n)
        return str(n_i).encode("ascii") + bytes([0x0E]) + fp5(n_i)
    return f"{n}".encode("ascii") + bytes([0x0E]) + fp5(float(n))


def basic_line(line_no: int, body: bytes) -> bytes:
    full = body + bytes([0x0D])
    return line_no.to_bytes(2, "big") + len(full).to_bytes(2, "little") + full


def stmt(*parts) -> bytes:
    out = bytearray()
    for p in parts:
        if isinstance(p, int):
            out.append(p)
        elif isinstance(p, str):
            out += p.encode("ascii")
        else:
            out += p
    return bytes(out)


# --------------------------- driver -------------------------------

ARG_DX = 0x5B10   # = 23312
ARG_DY = 0x5B15   # = 23317
ARG_A  = 0x5B1A   # = 23322


def poke_fp5(addr: int, val: float) -> list[bytes]:
    bs = fp5(val)
    return [stmt(T["POKE"], num_lit(addr + i), ",", num_lit(b))
            for i, b in enumerate(bs)]


def build_basic(inp, entry: int) -> bytes:
    lines: list[tuple[int, bytes]] = []
    lines.append((10, stmt(T["CLEAR"], num_lit(49151))))
    lines.append((20, stmt(T["LOAD"], '""', T["CODE"])))
    lines.append((30, stmt(T["BORDER"], num_lit(7), ":",
                           T["PAPER"],  num_lit(7), ":",
                           T["INK"],    num_lit(0), ":",
                           T["CLS"])))
    ln = 40
    for s in poke_fp5(ARG_DX, inp.dx):
        lines.append((ln, s)); ln += 1
    for s in poke_fp5(ARG_DY, inp.dy):
        lines.append((ln, s)); ln += 1
    for s in poke_fp5(ARG_A, inp.theta):
        lines.append((ln, s)); ln += 1
    lines.append((ln, stmt(T["PLOT"], num_lit(inp.x1), ",", num_lit(inp.y1)))); ln += 1
    lines.append((ln, stmt(T["RANDOMIZE"], T["USR"], num_lit(entry)))); ln += 1
    lines.append((ln, stmt(T["PAUSE"], num_lit(0))))
    return b"".join(basic_line(no, body) for no, body in lines)


def build_tap(case_name: str, inp, code_bin: bytes, entry: int) -> bytes:
    basic = build_basic(inp, entry)
    return (
        header(0, ("arc" + case_name)[:10], len(basic), 10, len(basic)) +
        data_block(basic) +
        header(3, "arc.code", len(code_bin), 0xC000, 0x8000) +
        data_block(code_bin)
    )


# --------------------------- main ---------------------------------

def main(argv: list[str]) -> int:
    root  = Path(__file__).parent
    bin_p = root / "build" / "shim_C000.bin"
    ent_p = root / "build" / "shim_entry.txt"
    if not bin_p.exists() or not ent_p.exists():
        print(f"missing {bin_p} or {ent_p}.")
        print("Build the shim first:")
        print("  powershell -ExecutionPolicy Bypass -File tests/build.ps1")
        return 1
    code  = bin_p.read_bytes()
    entry = int(ent_p.read_text().strip())
    print(f"shim:  {len(code)} bytes  arc_test = ${entry:04X}")

    want = argv[1:] or list(CASES.keys())
    out_dir = root / "build"
    for name in want:
        if name not in CASES:
            print(f"  skip: no case '{name}'")
            continue
        tap = build_tap(name, CASES[name], code, entry)
        out = out_dir / f"arc_test_{name}.tap"
        out.write_bytes(tap)
        print(f"  {out.name:<36}  {len(tap):>5} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
