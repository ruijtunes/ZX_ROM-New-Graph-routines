DEVICE ZXSPECTRUM48     ; Sets the device (48K)
; -------------------
; The Plot subroutine - Replace the one in the ROM @ $22E5; Fits in the space of the original (excluding the LUT)
; -------------------
; A screen byte holds 8 pixels so it is necessary use a mask
; to leave the other 7 pixels unaffected. In this version I use a LUT to grab the mask.
; All 64 pixels in the character cell take any embedded colour
; items.
; A pixel can be reset (inverse 1), toggled (over 1), or set ( with inverse
; and over switches off). With both switches on, the byte is simply put
; back on the screen though the colours may change.


PLOT_SUB	EQU	$22E5
COORDS	 	EQU $5C7D
PIXEL_ADD:  EQU $22AA
PO_ATTR:	EQU $0BDB

	ORG PLOT_SUB

;; PLOT-SUB
L22E5:
	ld	(COORDS), bc	 ; store new x/y values in COORDS
;***********************
; New optimization with LUT for the PLOT routine.
;*******************************
	call	PIXEL_ADD	 ; routine PIXEL-ADD gets address in HL,
                         ; count from left 0-7 in B.

  	ld  de, Mask_tab
   	add a,e
   	ld  e, a             ; pixel position in A.	
   	ld  a, (de)          ; get mask from LUT
   	ld  b, a   		     ; lined up with the pixelbit position in the byte.

   	ld	a, (hl)		     ; The pixel-byte is obtained in A.
	ld	c, (iy + $57)    ; P_FLAG to C
	bit	0, c		     ; is it to be OVER 1 ?
	jr	nz, L22FD	     ; forward to PL-TST-IN if so.

						 ; was over 0	
	and 	b		     ; combine with mask to blank pixel.

;; PL-TST-IN	
L22FD:
	bit	2, c		     ; is it inverse 1 ?
	jr	nz, L2303        ; to PLOT-END if so.

	xor 	b		     ; switch the pixel
	cpl  			     ; restore other 7 bits

;; PLOT-END	
L2303:
	ld	(hl), a          ; load byte to the screen.
	jp	PO_ATTR          ; exit to PO-ATTR to set colours for cell.
	nop 				 ; 1 free byte

Mask_tab: 
;; lookup table with mask for plot 
   	DEFB    $7F   		;01111111 ($7F)
	DEFB    $BF   		;10111111 ($BF)
	DEFB    $DF   		;11011111 ($DF)
	DEFB    $EF   		;11101111 ($EF)
	DEFB    $F7   		;11110111 ($F7)
	DEFB    $FB   		;11111011 ($FB)
	DEFB    $FD   		;11111101 ($FD)	
	DEFB 	$FE   		;11111110 ($FE)

