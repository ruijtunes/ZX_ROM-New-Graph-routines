;================================================================
; INTEGRATED.asm  --  CIRCLE + ARC + DRAW dispatcher sharing one
; Bresenham step subroutine.
;
; Goal: measure the combined image size when CIRCLE's 8-octant
; emit loop and the new ARC use the SAME `bres_step` subroutine,
; instead of two near-identical inline copies.
;
; Layout: contiguous at ORG $C000 to measure raw bytes. Final
; ROM placement (CIRCLE at $2320, DRAW at $2382, L2477 at $2477)
; is a separate concern; user splices with jumps from the
; canonical addresses.
;================================================================

EXPT_1NUM   EQU $1C82
CHECK_END   EQU $1BEE
PLOT_SUB    EQU $22E5
STK_TO_A    EQU $2314
STK_TO_BC   EQU $2307
LINE_DRAW   EQU $24B7
TEMPS       EQU $0D4D
REPORT_C    EQU $1C8A

            ORG $C000

;================================================================
; CIRCLE entry  (canonical ROM address: $2320)
;================================================================
CIRCLE:
            rst     18h
            cp      $2C
            jp      nz, REPORT_C
            rst     20h
            call    EXPT_1NUM
            call    CHECK_END
            RST     28H
            DEFB    $2A, $3D, $38                  ; abs, re-stack
            ld      a, (hl)
            cp      $81
            jr      nc, CIRCLE_BIG
            RST     28H
            DEFB    $02, $38                       ; tiny: just plot centre
            jp      PLOT_SUB
CIRCLE_BIG:
            call    STK_TO_A
            push    af
            call    STK_TO_BC
            pop     af
            ld      e, c
            ld      d, b
            ld      c, a
            ld      b, 0
            ld      hl, 0
            jr      C8LOOP

Plot_circ:
            push    bc
            exx
            pop     bc
            call    PLOT_SUB
            exx
            ret

;================================================================
; bres_step  --  shared Bresenham circle step
;   In : B=y, C=x, HL=err
;   Out: B,C,HL updated; CY=1 if x>=y (continue), CY=0 if done
;================================================================
bres_step:
            ld      a, c
            inc     hl
            ld      c, b
            ld      b, 0
            add     hl, bc
            add     hl, bc
            ld      b, c
            ld      c, a
            inc     b
            push    hl
            ld      a, b
            ld      b, 0
            and     a
            sbc     hl, bc
            dec     hl
            bit     7, h
            ld      b, a
            pop     hl
            jr      nz, .no_xdec
            ld      a, b
            ld      b, 0
            and     a
            sbc     hl, bc
            sbc     hl, bc
            inc     hl
            ld      b, a
            dec     c
.no_xdec:
            ld      a, c
            cp      b
            ccf
            ret
bres_step_end:

;================================================================
; C8LOOP  --  8-octant emit + call bres_step
;================================================================
C8LOOP:
            push    hl
            push    bc
            ld      h, b
            ld      l, c
            ld      a, l
            add     a, e
            ld      c, a
            ld      a, h
            add     a, d
            ld      b, a
            call    Plot_circ
            ld      a, d
            sub     h
            ld      b, a
            call    Plot_circ
            ld      a, e
            sub     l
            ld      c, a
            call    Plot_circ
            ld      a, h
            add     a, d
            ld      b, a
            call    Plot_circ
            ld      a, h
            add     a, e
            ld      c, a
            ld      a, l
            add     a, d
            ld      b, a
            call    Plot_circ
            ld      a, d
            sub     l
            ld      b, a
            call    Plot_circ
            ld      a, e
            sub     h
            ld      c, a
            call    Plot_circ
            ld      a, d
            add     a, l
            ld      b, a
            call    Plot_circ
            pop     bc
            pop     hl
            call    bres_step
            jp      c, C8LOOP
            jp      TEMPS
C8LOOP_end:

;================================================================
; DRAW dispatcher  (canonical ROM address: $2382)
;================================================================
DRAW:
            rst     18h
            cp      $2C
            jr      z, ARC_ENTRY
            call    CHECK_END
            jp      LINE_DRAW
DRAW_end:

;================================================================
; ARC -- INCLUDE ARC.asm with SHARED_BRES_STEP defined so the arc
; routine `call`s our bres_step instead of inlining its own copy.
;================================================================
SHARED_BRES_STEP EQU bres_step
            DEFINE SHARED_BRES_STEP
ARC_ENTRY:
            INCLUDE "ARC.asm"
ARC_end:

;================================================================
; L2477 -- legacy DRAW exit  (canonical ROM address: $2477)
;================================================================
L2477:
            call    LINE_DRAW
            jp      TEMPS
INTEGRATED_END:

            DISPLAY "CIRCLE setup      : ", /D, Plot_circ-CIRCLE
            DISPLAY "Plot_circ         : ", /D, bres_step-Plot_circ
            DISPLAY "bres_step (shared): ", /D, bres_step_end-bres_step
            DISPLAY "C8LOOP            : ", /D, C8LOOP_end-C8LOOP
            DISPLAY "DRAW dispatcher   : ", /D, DRAW_end-DRAW
            DISPLAY "ARC (included)    : ", /D, ARC_end-ARC_ENTRY
            DISPLAY "L2477 wrapper     : ", /D, INTEGRATED_END-L2477
            DISPLAY "TOTAL image bytes : ", /D, INTEGRATED_END-CIRCLE
