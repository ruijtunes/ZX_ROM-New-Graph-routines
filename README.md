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

The exact definition of a circle centered at the origin is:

x^2+y^2=r^2

Solving for y gives y=± SQR (r^2−x^2)
Because of symmetry, we can mirror the solution (x,y) pairs we get in Quadrant I into the other quadrants. 

The algorithm used is the “Midpoint Circle Algorithm”

Start out from the top of the circle (pixel (0,r)). 
Move right (east (E)) or down-right (southeast (SE)), whichever is closer to the circle.
Stop when x=y
This implementation gives a more aesthetically pleasing circle than the one in the original ROM. 
 
# ZX-Arc

Arc: New Arc algorithm
Classic geometric algorithm for drawing a circular arc from two points and an angle (DRAW x,y,a),
using the center of the circle.

               
              C (center) 
             /|\
            / | \
           /  |  \
          /   |   \
         /    h    \
        /     |     \
       P1-----M-----P2
          d/2    d/2
       <------d------>
              
d = distance (P1,P2)
R = circle radius
h = distance from center C to the line P1P2 (chord height)
θ is the central angle subtended by the chord P₁–P₂, that is, the angle ∠P₁CP₂.

Algorithm Objective

Given:
- Starting point: \( P_1 = (x_1, y_1) \)
- Ending point: \( P_2 = (x_2, y_2) \)


- ```markdown
d = √(dx² + dy²)
R = d / (2 sin(θ / 2))
h = √(R² − (d / 2)²)
M = (x₁ + dx / 2 , y₁ + dy / 2)
n = (−dy / d , dx / d)
C = M + h · n



# Assembling

The source code is a .asm text file that can be compiled with a Z80 assembler like sjasmplus or other, and run in a Spectrum emulator like the Fuse or Spetaculator. 
Run the assembler with:

sjasmplus --lst=zxrom.lst zxplot.asm


Sjasmplus is a command-line cross-compiler of assembly language for [Z80 CPU](https://en.wikipedia.org/wiki/Zilog_Z80).

Supports many [ZX-Spectrum](https://en.wikipedia.org/wiki/ZX_Spectrum) specific directives, has built-in Lua scripting engine and 3-pass design.

