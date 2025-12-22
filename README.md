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
Fast circle routine to replace the original ROM

Graphic routine in assembler (Z80) for drawing circles  with ZX Spectrum.

The Circle subroutine - Replace the one in the ROM @ $2320; Fits in the space of the original

The algorithm used is the mid-point algorithm.

# ZX-Arc

Arc: New Arc algorithm
Classic geometric algorithm for drawing a circular arc from two points and an angle (DRAW x,y,a),
using the center of the circle calculated via the formula:

R=d/(2⋅sin(θ/2)),h=√(R^2-(d/2)^2 )

And then determining the center (C_x,C_y) based on the perpendicular to the segment.

ALGORITHM OBJECTIVE
Given:
Starting point: P_1=(x_1,y_1)
Ending point: P_2=(x_2,y_2) → that is, displacement dx=x_2-x_1, dy=y_2-y_1

Rotation angle: θ (in radians, counterclockwise)
We want to draw a circular arc that:
Starts at P_1
Ends at P_2
Rotates counterclockwise with a total angle θ
________________________________________

# Assembling

The source code is a .asm text file that can be compiled with a Z80 assembler like sjasmplus or other, and run in a Spectrum emulator like the Fuse or Spetaculator. 
Run the assembler with:

sjasmplus --lst=zxrom.lst zxplot.asm


Sjasmplus is a command-line cross-compiler of assembly language for [Z80 CPU](https://en.wikipedia.org/wiki/Zilog_Z80).

Supports many [ZX-Spectrum](https://en.wikipedia.org/wiki/ZX_Spectrum) specific directives, has built-in Lua scripting engine and 3-pass design.

