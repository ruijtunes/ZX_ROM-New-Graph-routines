
;************************************************************************************->
; RND based on SAM Coupe ROM 3.0 Last official release, source code on github https://github.com/simonowen/samrom/tree/master 
; SAM ROM by (Andrew J.A. Wright 1989-90); Dr. Andy Wright
; In 2008, he granted permission for all of his SAM Coupe titles and ROMs to be freely redistributed
; Dr. Wright was known for developing and selling BetaBASIC
; This RND implementation is much faster than the original ZX Spectrum implementation (more than 5x) using only integer operations
;***************************************************************************************
; ALGORITHM LCG - Linear Congruential Generator
; X_(n+1)=(aX_n+c) mod m
; m - the "modulus" ; a - the "multiplier"; c - the "increment" are integer constants
; that specify the generator
; X0 is the "seed" or "start value"
; ZX81, ZX Spectrum uses m=2^16+1, a =75, c=0
; SAM uses X_(n+1) = (254 × (X_n + 1) mod 65537)-1 = (254×X_n + 253) mod 65537
; m=65537 is a Fermat(4) prime 2^16+1
; 254 like 75 is a primitive root modulo 65537 ; c= 253
; Output: (X_n -1)/2^16   in [0,1[
;************************************************************************************


EXPT_1NUM:	EQU $1C82
PIXEL_ADD:  EQU $22AA
CHECK_END:	EQU $1BEE
PLOT_SUB:	EQU $22E5
STK_TO_A:   EQU $2314
STK_TO_BC:  EQU $2307
DRAW_LINE:  EQU $24B7                     
TEMPS:      EQU $0D4D
FIND_INT1:  EQU $1E94
REPORT_BC:  EQU $24F9

REPORT_C:   EQU $1C8A
COORDS:     EQU $5C7D
STACK_A:    EQU $2D28


SYNTAX_Z:   EQU $2530
S_RND_END:  EQU $2625
S_PI_END:   EQU $2630 

     ORG $25F8
S-RND 

	CALL	SYNTAX_Z      ; routine SYNTAX-Z
	JR	z, S_RND_END      ; forward to S-RND-END if checking syntax.

label_25FD:
	LD B,0			      ; B=0, used as zero operand in SBC to propagate
                          ; carry without adding value


	LD HL,($5C76)   	; HL = X_n  (current SEED from system variable)
 	LD E,$FD		; E = 253 = c
 	LD D,L			; D = L  →  DE = L×256 + 253
                     		; this pre-builds 256×(X_n+1) - 3
                        	; which equals 254×X_n + 253  after the subtractions


 	LD A,H			; A = H  (high byte of X_n, saved for 32-bit arithmetic)
 	ADD HL,HL		; HL = 2×X_n  (mod 2¹⁶);
				; carry flag = bit 16 of 2×X_n  (overflow)

 	SBC A,B			; A = H - carry  (B=0)
                      		; captures the overflow bit into A
                       		; A:HL now holds 2×X_n as a 32-bit value

 	EX DE,HL		; HL ↔ DE
                    		; HL = (L_original, $FD) = L×256 + 253
                   		; DE = 2×X_n (low 16 bits)

	SBC HL,DE		;(A : HL) − (0 : DE)
 				; HL = (L×256+253) − 2×X_n − carry_in 
				; carry_out = borrow from low 16-bit subtraction

 	SBC A,B			; A = A - 0 - carry_out  (B=0)
                        	; propagates borrow into high byte
                        	; A now holds high byte of the 32-bit result
 	
	LD C,A			; C = A  →  BC = A (since B=0, C is low byte) 
	SBC HL,BC		; HL = HL - A - carry
				; folds overflow back: since 2¹⁶ ≡ -1 (mod 65537)
                       		; subtracting A completes the mod 65537 reduction
                        	

 	JR NC,IMRND1		; if no borrow, result is in [0, 65536], skip adjustment
 	INC HL			; result was negative (HL wrapped), add 1
                        	; because -1 ≡ 65536 (mod 65537)
                        	; keeps result in [0, 65536]


IMRND1: LD ($5C76),HL  		; store X_(n+1) in SEED for next starting point.
				; X_(n+1) = (254×X_n + 253) mod 65537
                        	; equivalently: (254 × (X_n+1) mod 65537) - 1

	LD C,L
	LD B,H
	call	label_2D2B	; routine STACK-BC places on calculator stack
	rst	28h   		; FP-CALC 
	DEFB    $3D         	;re-stack, its exponent is therefore available.
				;EXP WILL BE 00 IF ZERO, ELSE 81-90H
	DEFB    $38         	;end-calc

	LD A, (HL)		; fetch exponent
	SUB $10			; reduce exponent by 2^16
	JR c,label_2625
	LD (HL), A	        ; new expoent
		
	;  2 bytes shorter than original ZX Spectrum RND implementation
	nop
	nop

S_RND_END:

	jr	S_PI_END    ; forward to S-PI-END
