;================================================================
; test_main.asm  --  self-contained snapshot harness.
;
; Layout:
;   $C000..  : ARC.asm (INCLUDEd) followed by arc_test shim
;   $D000..  : test_main entry  (PC starts here in the snapshot)
;
; Snapshot generator (tests/make_sna.py) sets:
;   $5C7D = x1   (BASIC COORDS X)
;   $5C7E = y1   (BASIC COORDS Y)
;   $5B10..$5B14 = dx as ZX 5-byte FP
;   $5B15..$5B19 = dy
;   $5B1A..$5B1E = A
; and PC = test_main, with a sane initial stack at $7FFF.
;
; test_main calls the shim then halts.  The drawn pixels remain
; on screen for visual inspection in Fuse.
;================================================================

STK_STORE   EQU $2AB6
ARG_DX      EQU $5B10
ARG_DY      EQU $5B15
ARG_A       EQU $5B1A

            ORG   $C000
            INCLUDE "../ARC.asm"

;; arc_test : push dx, dy, A onto calc stack then JP into ARC core.
arc_test:
            ld    hl, ARG_DX
            call  push_fp5
            ld    hl, ARG_DY
            call  push_fp5
            ld    hl, ARG_A
            call  push_fp5
            jp    draw_arc_calc

push_fp5:   ld a,(hl)
            inc hl
            ld e,(hl)
            inc hl
            ld d,(hl)
            inc hl
            ld c,(hl)
            inc hl
            ld b,(hl)
            jp STK_STORE

;; Snapshot entry point.
            ORG   $D000
test_main:
            di
            ld    sp, $7FFF
            call  arc_test
.halt:
            halt                                ; infinite halt-loop
            jr    .halt
