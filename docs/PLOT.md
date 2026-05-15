# PLOT — fast LUT-based pixel plot

`ZXPLOT.asm` provides a drop-in replacement for the Spectrum ROM's
`PLOT-SUB` at `$22E5`. It fits in the same ROM slot, excluding an
8-byte mask LUT (`Mask_tab`) which lives where the existing ROM had a
shift loop.

## What changed

A screen byte holds 8 horizontal pixels. The ROM original reaches the
correct mask by performing up to 7 iterations of `RRCA`. We index a
small lookup table instead:

```
ld   de, Mask_tab
add  a, e
ld   e, a
ld   a, (de)      ; mask now in A
```

The rest of the routine is identical: the OVER and INVERSE flags out of
`P_FLAG` drive the bit-blend with the existing screen byte, and we exit
through `PO_ATTR` to set cell colours.

## Semantics

| `OVER` | `INVERSE` | Action                              |
| :----: | :-------: | ----------------------------------- |
|   0    |     0     | Set pixel                           |
|   1    |     0     | Toggle pixel (XOR)                  |
|   0    |     1     | Reset pixel                         |
|   1    |     1     | Recompute attribute, leave pixel    |

## Integration

Assemble with sjasmplus:

```
sjasmplus --lst=zxplot.lst ZXPLOT.asm
```

The output is a binary image you patch into a custom ROM or load into
RAM at `$22E5`. The mask table needs to be reachable from the same
routine; the file places it immediately after the patched ROM bytes.
