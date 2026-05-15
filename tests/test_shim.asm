;================================================================
; test_shim.asm -- BASIC-callable driver for ARC.asm.
;
; Layout in RAM (after LOAD "" CODE 49152):
;   $C000          arc_entry  -- the original draw_arc_new
;                                (for completeness; not called here)
;   $C000+...      draw_arc_calc -- stack-only entry, see ARC.asm
;   ...
;   $E000          arc_test (this shim)
;
; Calling convention from BASIC:
;
;     POKE 23312+0..4 , dx  (5-byte FP, sign-mantissa-exponent ZX form)
;     POKE 23312+5..9 , dy
;     POKE 23312+10..14, A
;     PLOT x1, y1
;     RANDOMIZE USR <arc_test address>   : address is in shim.sym
;
; The shim:
;   1. pushes dx, dy, A onto the calc stack (in that order; top = A)
;   2. JPs into ARC's draw_arc_calc label
;
; 15-byte arg block at $5B10 (printer-buffer area, idle on 48K).
;================================================================

; ROM helper: push 5-byte FP from registers onto the calculator
; stack.  Entry:  A = exponent, EDCB = mantissa bytes (m1..m4).
STK_STORE   EQU $2AB6

ARG_DX      EQU $5B10        ; 5 bytes
ARG_DY      EQU $5B15
ARG_A       EQU $5B1A

            ORG   $C000
            INCLUDE "../ARC.asm"     ; provides draw_arc_new + draw_arc_calc

arc_test:
            ld      hl, ARG_DX
            call    push_fp5
            ld      hl, ARG_DY
            call    push_fp5
            ld      hl, ARG_A
            call    push_fp5
            jp      draw_arc_calc

;; push_fp5 -- copy 5 bytes from (HL) onto the calculator stack.
push_fp5:
            ld      a, (hl)        ; exponent
            inc     hl
            ld      e, (hl)        ; m1 (sign bit + 7 bits)
            inc     hl
            ld      d, (hl)        ; m2
            inc     hl
            ld      c, (hl)        ; m3
            inc     hl
            ld      b, (hl)        ; m4
            jp      STK_STORE      ; tail-call; ret from there

;================================================================
; END test_shim.asm
;================================================================
