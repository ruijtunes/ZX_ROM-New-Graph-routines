# ZX-Plot
Fast plot routine using LUT to replace the original ROM

Graphic routine in assembler (Z80) for plotting pixels with ZX Spectrum.

The Plot subroutine - Replace the one in the ROM @ $22E5; Fits in the space of the original (excluding the LUT)

A screen byte holds 8 pixels so it is necessary use a mask to leave the other 7 pixels unaffected.
In this version I use a LUT to grab the mask.
All 64 pixels in the character cell take any embedded colour items.
A pixel can be reset (inverse 1), toggled (over 1), or set ( with inverse and over switches off).
With both switches on, the byte is simply put back on the screen though the colours may change.


# ZX-Circle
Fast plot routine using LUT to replace the original ROM

Graphic routine in assembler (Z80) for plotting pixels with ZX Spectrum.

The Plot subroutine - Replace the one in the ROM @ $22E5; Fits in the space of the original (excluding the LUT)

A screen byte holds 8 pixels so it is necessary use a mask to leave the other 7 pixels unaffected.
In this version I use a LUT to grab the mask.
All 64 pixels in the character cell take any embedded colour items.
A pixel can be reset (inverse 1), toggled (over 1), or set ( with inverse and over switches off).
With both switches on, the byte is simply put back on the screen though the colours may change.


# The source code is a .asm text file that can be compiled with a Z80 assembler like sjasmplus or other, and run in a Spectrum emulator like the Fuse or Spetaculator. 

Run the assembler with:

sjasmplus --lst=zxrom.lst zxplot.asm


Sjasmplus is a command-line cross-compiler of assembly language for [Z80 CPU](https://en.wikipedia.org/wiki/Zilog_Z80).

Supports many [ZX-Spectrum](https://en.wikipedia.org/wiki/ZX_Spectrum) specific directives, has built-in Lua scripting engine and 3-pass design.

