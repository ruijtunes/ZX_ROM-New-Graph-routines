"""
render.py -- visualise a pixel set.

Renders either as a PNG (any scale) or as a Spectrum SCREEN$ blob
(6912 bytes: 6144 bitmap + 768 attributes).

ZX SCREEN$ pixel layout:
  third (0..2)  -- which third of the screen (top / middle / bottom)
  row    (0..7) -- pixel row within the 8-pixel character cell
  cell_y (0..7) -- which character row within the third
  cell_x (0..31)
  bit    (0..7) -- horizontal pixel within the byte (MSB = leftmost)

Address of pixel (x, y) where (0,0) is top-left:
  byte = 0x4000 + ((y & 0xC0) << 5) | ((y & 0x07) << 8) | ((y & 0x38) << 2) | (x >> 3)
  bit  = 7 - (x & 7)
"""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw


SCREEN_W = 256
SCREEN_H = 192


def basic_to_screen_xy(x: int, y: int) -> tuple[int, int]:
    """Convert ZX BASIC coordinates (origin bottom-left) to screen
    pixel coordinates (origin top-left)."""
    return x, (SCREEN_H - 1) - y


def render_png(
    pixels: Iterable[tuple[int, int]],
    path: str | Path,
    *,
    scale: int = 2,
    annotate: dict | None = None,
) -> None:
    """Render a pixel set as a 1bpp-like PNG. Pixels in `pixels` are
    in ZX BASIC coordinates (origin bottom-left, Y up).
    """
    img = Image.new("RGB", (SCREEN_W, SCREEN_H), (255, 255, 255))
    px = img.load()
    for x, y in pixels:
        sx, sy = basic_to_screen_xy(x, y)
        if 0 <= sx < SCREEN_W and 0 <= sy < SCREEN_H:
            px[sx, sy] = (0, 0, 0)

    if scale != 1:
        img = img.resize((SCREEN_W * scale, SCREEN_H * scale), Image.NEAREST)

    if annotate:
        draw = ImageDraw.Draw(img)
        text = "\n".join(f"{k}: {v}" for k, v in annotate.items())
        draw.text((4, 4), text, fill=(200, 0, 0))

    Path(path).parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def screen_addr(x: int, y: int) -> tuple[int, int]:
    """Return (byte_offset_within_screen, bit_mask) for pixel (x, y)
    where (0, 0) is top-left (screen coordinates, not BASIC)."""
    if not (0 <= x < SCREEN_W and 0 <= y < SCREEN_H):
        raise ValueError((x, y))
    offset = ((y & 0xC0) << 5) | ((y & 0x07) << 8) | ((y & 0x38) << 2) | (x >> 3)
    mask = 1 << (7 - (x & 7))
    return offset, mask


def pixels_to_scr(pixels: Iterable[tuple[int, int]]) -> bytes:
    """Encode a pixel set (in ZX BASIC coords) as a 6912-byte
    SCREEN$ blob -- 6144 bitmap + 768 attributes (all 0x38 = white
    paper / black ink, no flash / bright)."""
    bitmap = bytearray(6144)
    for x, y in pixels:
        sx, sy = basic_to_screen_xy(x, y)
        if 0 <= sx < SCREEN_W and 0 <= sy < SCREEN_H:
            off, mask = screen_addr(sx, sy)
            bitmap[off] |= mask
    attrs = bytes([0x38]) * 768   # paper 7 (white), ink 0 (black)
    return bytes(bitmap) + attrs


def scr_to_pixels(scr: bytes) -> set[tuple[int, int]]:
    """Reverse of pixels_to_scr: extract the set of lit pixels from a
    SCREEN$ blob. Returns BASIC coordinates."""
    if len(scr) < 6144:
        raise ValueError(f"need >= 6144 bytes, got {len(scr)}")
    out: set[tuple[int, int]] = set()
    for sy in range(SCREEN_H):
        for sx in range(SCREEN_W):
            off, mask = screen_addr(sx, sy)
            if scr[off] & mask:
                # back to BASIC coords
                out.add((sx, (SCREEN_H - 1) - sy))
    return out
