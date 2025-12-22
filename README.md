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

;===============================================================
; Arc: New Arc algorithm
;===============================================================
;We want to draw a circular arc that:
;Starts at P1
;Ends at P2
;Rotates counterclockwise by a total angle θ

;          C (center) 
;         /|\
;        / | \
;       /  |  \
;      /   |   \
;     /    h    \
;    /     |     \
;   P1-----M-----P2
;      d/2    d/2
;   <------d------>
;
; * d = distance (P1,P2)
; * R = circle radius
; * h = distance from center C to the line P1P2 (chord height)
;   θ is the central angle subtended by the chord P₁–P₂, that is, the angle ∠P₁CP₂.
;
; Step 1: Compute the radius R
; Use the law of sines in triangle P1CP2:
;      d / sin(θ) = R / sin(θ/2)
;      => R = d / (2 * sin(θ/2))
; This is exact for any θ in (0, 2*pi)
;
;
; Step 2: Compute the height h (distance from center to chord)
; Apply Pythagoras in the right triangle C - M - P1
; (M is the midpoint of segment P1P2):
;      R^2 = h^2 + (d/2)^2
;      => h = sqrt(R^2 - (d/2)^2)
;
; Step 3: Find the center C = (Cx, Cy)
;
; 1. Midpoint of the segment:
;    Mx = x1 + dx/2
;    My = y1 + dy/2
;    (dx = x2 - x1, dy = y2 - y1)
;
; 2.  Perpendicular vector to (dx,dy):
;    For counter-clockwise arc: n = (-dy, dx)
;    (for clockwise arc just flip the sign)
;
; 3. Unit perpendicular vector:
;    d = sqrt(dx*dx + dy*dy)      // length of P1P2
;    ux = -dy / d
;    uy =  dx / d
;
; 4. Center coordinates:
;    Cx = Mx + h * ux
;    Cy = My + h * uy
;    (use -h for the other possible arc - the one on the opposite side)
;
;
; Step 4: Draw the arc
; With center C and radius R, draw the arc from P1 to P2 using Plot


# Assembling

The source code is a .asm text file that can be compiled with a Z80 assembler like sjasmplus or other, and run in a Spectrum emulator like the Fuse or Spetaculator. 
Run the assembler with:

sjasmplus --lst=zxrom.lst zxplot.asm


Sjasmplus is a command-line cross-compiler of assembly language for [Z80 CPU](https://en.wikipedia.org/wiki/Zilog_Z80).

Supports many [ZX-Spectrum](https://en.wikipedia.org/wiki/ZX_Spectrum) specific directives, has built-in Lua scripting engine and 3-pass design.

