# RND — SAM Coupé style LCG on the ZX Spectrum

`Rand.asm` ports the SAM Coupé ROM's RND routine (Andrew J. A. Wright,
1989–90; freely redistributable as of 2008) to the ZX Spectrum, fitting
in the existing `S-RND` ROM slot at `$25F8`.

The implementation is **>5× faster than the original Sinclair RND** and
uses only integer arithmetic.

## Algorithm

A Lehmer-style linear congruential generator with

$$
X_{n+1} = (254 \cdot X_n + 253) \bmod 65537,
$$

equivalently `X(n+1) = (254 · (X(n) + 1) mod 65537) − 1`. Both ZX (75)
and SAM (254) multipliers are primitive roots modulo the Fermat prime
`F₄ = 2¹⁶ + 1 = 65537`, so the generator cycles through all 65 536
non-zero states before repeating.

## Why this is fast

The optimisation hinges on the identity

$$
254 \cdot (X + 1) \;=\; 256 \cdot (X + 1) - 2 \cdot (X + 1).
$$

Multiplying a 16-bit value by 256 is a byte rotation (free). So the
expensive `* 254` collapses to a couple of `ADD HL,HL` instructions
plus carry propagation, with the `mod 65537` folded in by the fact
that `2¹⁶ ≡ −1 (mod 65537)`: any overflow past 16 bits is *subtracted*
from the running result.

The full annotated assembly is in `Rand.asm`. The routine ends with the
standard `SUB $10` exponent adjustment used by all Spectrum integer-RND
implementations to convert the 16-bit integer state into a normalised
floating-point value in `[0, 1)`.

## Properties

* **Period**: 65 536 (the full multiplicative group of `Z/65537`).
* **Statistical character**: same family as the Sinclair original;
  passes the same simple tests (uniform distribution to one part in
  ~10⁴), fails the same hard ones (LCGs always do).
* **Determinism**: identical sequence given the same seed.
* **Size**: 2 bytes shorter than the Sinclair original (two `NOP`s
  pad the slot).
