;================================================================
; ARC.asm  --  exact, drift-free circular arc for ZX Spectrum 48K
;
; Drop-in replacement for the rotational-DDA `draw_arc` path in
; `NEW CIRCLE AND ARC.asm`. The full rationale and the proof of
; zero radius drift are in docs/PRECISION_ANALYSIS.md ; the short
; version is:
;
;   The previous algorithm walks the radius vector by left-
;   multiplying a 2x2 rotation matrix at every step in 5-byte
;   FP. The matrix is orthogonal only up to round-off, so for
;   long arcs the radius spirals and the endpoint lands several
;   pixels off.
;
;   This routine computes  C, R, u = P1-C, v = P2-C  ONCE in FP,
;   rounds them to signed bytes, then drives a pure-integer
;   Bresenham circle loop (same as the one behind `CIRCLE`) and
;   gates each candidate pixel by two integer cross-products.
;
;   - the inner loop contains NO floating point,
;   - the emitted pixel set is a subset of CIRCLE's pixel set,
;   - radius drift is exactly zero,
;   - the endpoint is forced to land on P2,
;   - per pixel cost is ~2 signed 8x8 multiplies and a few tests.
;
; Memory model
;   Code is ROM-resident (read-only) and uses a 14-byte RAM
;   scratch area at $5B00 (printer buffer; idle on 48K machines
;   that are not driving a ZX Printer).
;
;================================================================

; --- ROM symbols (unchanged from NEW CIRCLE AND ARC.asm) -------
  IFNDEF EXPT_1NUM
EXPT_1NUM   EQU $1C82
  ENDIF
  IFNDEF CHECK_END
CHECK_END   EQU $1BEE
  ENDIF
  IFNDEF PLOT_SUB
PLOT_SUB    EQU $22E5
  ENDIF
  IFNDEF STK_TO_A
STK_TO_A    EQU $2314
  ENDIF
  IFNDEF FP_TO_A
FP_TO_A     EQU $2DA2
  ENDIF
  IFNDEF LINE_DRAW
LINE_DRAW   EQU $24B7
  ENDIF
  IFNDEF TEMPS
TEMPS       EQU $0D4D
  ENDIF
  IFNDEF COORDS
COORDS      EQU $5C7D
  ENDIF
  IFNDEF STACK_A
STACK_A     EQU $2D28
  ENDIF

; --- RAM scratch (14 bytes; printer buffer) ---------------------
ARC_WORK    EQU $5B00
ARC_UX      EQU ARC_WORK +  0    ; signed byte
ARC_UY      EQU ARC_WORK +  1
ARC_VX      EQU ARC_WORK +  2
ARC_VY      EQU ARC_WORK +  3
ARC_FLAGS   EQU ARC_WORK +  4    ; b0: sigma<0    b1: major arc
ARC_CY      EQU ARC_WORK +  5    ; unsigned byte (offset chosen so Cy/Cx/R
ARC_CX      EQU ARC_WORK +  6    ;  line up in ascending address order with
ARC_R       EQU ARC_WORK +  7    ;  the pop order R, Cx, Cy)
ARC_RX      EQU ARC_WORK +  8    ; signed byte, candidate point
ARC_RY      EQU ARC_WORK +  9
ARC_TMP16   EQU ARC_WORK + 10    ; 2 bytes, scratch for cross products

;================================================================
; Public entry. Reachable from the DRAW dispatcher in
; `NEW CIRCLE AND ARC.asm`: change  `jr z, draw_arc` to
; `jr z, draw_arc_new`. Memory layout assumes this file is
; assembled into the same image at ORG $2360.
;
; Calculator stack at entry (top first):
;     A    -- sweep angle, radians
;     dy   -- chord y component
;     dx   -- chord x component
; Current PLOT position is P1 = (x1, y1) at (COORDS).
;
; NOTE: this file does NOT contain an ORG directive. It is intended
; to be INCLUDEd from a small wrapper that supplies ORG and (optional)
; trailing code. The two wrappers shipped in tests/ are:
;     tests/build.ps1's auto-generated _ROM.asm / _C000.asm
;     tests/test_shim.asm  (BASIC-callable harness)
;================================================================

draw_arc_new:
            rst     20h                        ; advance past comma
            call    EXPT_1NUM                  ; stack the angle
            call    CHECK_END

;; --- Public alternate entry: caller has pushed (dx, dy, A) onto
;;     the calculator stack themselves (top of stack = A). Used by
;;     the test shim in tests/test_shim.asm.
draw_arc_calc:

;; --- one big FP block: stash A, dx, dy and compute R, h_signed.
;;     mem-0: h_signed   mem-1: dx   mem-2: dy   mem-3: d   mem-4: R   mem-5: A
;;     (No degenerate-case short-circuits; caller must avoid A=0, A=2*pi
;;      or zero chord -- those are nonsensical arcs.)
            RST     28H
            DEFB    $C5                        ; st-mem-5 A
            DEFB    $A2 $04 $1F                ; sin(A/2)
            DEFB    $C0                        ; st-mem-0 sin(A/2)
            DEFB    $02                        ; delete
            DEFB    $C2 $31 $04                ; st-mem-2 dy; dy^2
            DEFB    $01                        ; exch
            DEFB    $C1 $31 $04                ; st-mem-1 dx; dx^2
            DEFB    $0F $28                    ; d = sqrt(dx^2+dy^2)
            DEFB    $C3                        ; st-mem-3 d
            DEFB    $31 $E0 $31 $0F $05        ; R = d / (2 sin(A/2))
            DEFB    $C4                        ; st-mem-4 R
            DEFB    $31 $04 $01 $A2 $04 $31 $04 $03 $28
                                               ; h = sqrt(R^2 - (d/2)^2)
            DEFB    $E5 $29 $04                ; h * sgn(A) = h_signed
            DEFB    $E3 $05                    ; / d  -> hd = h_signed / d
            DEFB    $C0                        ; st-mem-0 hd
            DEFB    $02
            DEFB    $38

;; --- Combined Cy, Cx, R extraction ----------------------------
;;     One RST 28H block leaves stack [Cy, Cx, R] (R on top), then
;;     three STK_TO_A calls walk down ARC_R, ARC_CX, ARC_CY.
            ld      a, (COORDS)
            call    STACK_A                    ; push x1
            ld      a, ($5C7E)
            call    STACK_A                    ; push y1 (now on top)
            RST     28H
            DEFB    $E2 $A2 $04 $0F            ; y1 + dy/2
            DEFB    $E0 $E1 $04 $0F            ; + hd*dx        -> Cy
            DEFB    $01                        ; exch  -> [Cy, x1]
            DEFB    $E1 $A2 $04 $0F            ; x1 + dx/2
            DEFB    $E0 $E2 $1B $04 $0F        ; + hd*(-dy)     -> Cx
            DEFB    $E4                        ; push R         -> [Cy, Cx, R]
            DEFB    $38
            ld      hl, ARC_R
            call    STK_TO_A
            ld      (hl), a                    ; ARC_R = R
            dec     hl
            call    STK_TO_A
            ld      (hl), a                    ; ARC_CX = Cx
            dec     hl
            call    STK_TO_A
            ld      (hl), a                    ; ARC_CY = Cy

;; --- u = P1 - C ------------------------------------------------
            ld      a, (COORDS)
            ld      hl, ARC_CX
            sub     (hl)
            ld      (ARC_UX), a
            ld      a, ($5C7E)
            ld      hl, ARC_CY
            sub     (hl)
            ld      (ARC_UY), a

;; --- v = u + (dx, dy) ; one combined FP block (top=dx, below=dy) ---
            RST     28H
            DEFB    $E2 $E1                    ; push dy, then dx (top=dx)
            DEFB    $38
            call    pop_signed                 ; A = dx
            ld      hl, ARC_UX
            add     a, (hl)
            ld      (ARC_VX), a
            call    pop_signed                 ; A = dy
            ld      hl, ARC_UY
            add     a, (hl)
            ld      (ARC_VY), a

;; --- flags ----------------------------------------------------
            ld      c, 0
            RST     28H
            DEFB    $E5                        ; A
            DEFB    $29                        ; sgn
            DEFB    $38
            call    pop_signed                 ; A = sgn(A) as signed byte
            add     a, a                       ; CY = bit 7 of A (set iff sigma<0)
            rl      c                          ; rotate into b0 of flags
            RST     28H
            DEFB    $E5
            DEFB    $2A                        ; abs
            DEFB    $A3                        ; pi/2
            DEFB    $31
            DEFB    $0F                        ; pi
            DEFB    $03                        ; |A| - pi
            DEFB    $38
            call    pop_signed                 ; sign of |A|-pi in A
            or      a
            jp      m, .not_major              ; |A| < pi
            jr      z, .not_major              ; |A| = pi : minor
            set     1, c
.not_major:
            ld      a, c
            ld      (ARC_FLAGS), a

;; --- enter Bresenham ------------------------------------------
            ld      a, (ARC_R)
            ld      c, a                       ; x = R
            ld      b, 0                       ; y = 0
            ld      hl, 0                      ; err = 0
            jp      ARC_BRES_LOOP

;================================================================
; pop_signed -- pop calculator-stack top as signed byte in A.
;                Uses FP-TO-A: A = |x|, CY set if x was negative.
;                Spectrum will report "B Integer out of range"
;                if |x| > 255 (this is the correct behaviour:
;                arc parameters are bounded by screen extents).
;================================================================
pop_signed:
            call    FP_TO_A
            ret     nc
            neg
            ret

;================================================================
; ARC_BRES_LOOP
;
; Identical Bresenham circle state machine to the one in
; `NEW CIRCLE AND ARC.asm`, with `Plot_circ` replaced by the
; gated `Plot_arc_pt`. The 8 symmetric octant points are emitted
; from a tiny dispatch loop that walks a sign table.
;================================================================

ARC_BRES_LOOP:
            push    hl                         ; save err
            push    bc                         ; save (y, x)
            ld      d, b                       ; D = y
            ld      e, c                       ; E = x

;; --- emit all 8 symmetric points.  Counter B counts DOWN 7..0,
;;     and its 3 low bits ARE the flag byte:
;;        b0=sx_neg  b1=sy_neg  b2=swap x<->y
;;     (verified: original octant table was the identity 0..7)
            ld      b, 8
.oct_loop:
            push    bc                         ; save B as octant counter
            dec     b                          ; B = 7..0 = flag byte
            bit     2, b                       ; swap?
            ld      a, e                       ; default rx = x
            ld      c, d                       ; default ry = y
            jr      z, .nswap
            ld      a, d                       ; swap : rx = y
            ld      c, e                       ;        ry = x
.nswap:
            bit     0, b                       ; sx_neg?
            jr      z, .sx_pos
            neg
.sx_pos:
            ld      (ARC_RX), a
            ld      a, c                       ; ry
            bit     1, b                       ; sy_neg?
            jr      z, .sy_pos
            neg
.sy_pos:
            ld      (ARC_RY), a
            call    Plot_arc_pt
            pop     bc                         ; restore counter
            djnz    .oct_loop

;; --- Bresenham step ------------------------------------------
;;     In standalone builds we use the inline step (identical to
;;     CIRCLE-DRAW's). In the integrated build the step lives in
;;     CIRCLE and is shared via -DSHARED_BRES_STEP=<addr>.
            pop     bc                         ; (y, x)
            pop     hl                         ; err
  IFDEF SHARED_BRES_STEP
            call    SHARED_BRES_STEP           ; CY=1 -> continue loop
            jp      c, ARC_BRES_LOOP
  ELSE
            ld      a, c                       ; save x
            inc     hl
            ld      c, b
            ld      b, 0
            add     hl, bc
            add     hl, bc
            ld      b, c
            ld      c, a
            inc     b                          ; y++
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
            dec     c                          ; x--
.no_xdec:
            ld      a, c
            cp      b
            jp      nc, ARC_BRES_LOOP
  ENDIF

;; --- force the endpoint to be plotted, set COORDS -------------
;;     copy v into r (overwriting last candidate) and re-use arc_emit
            ld      hl, ARC_VX
            ld      de, ARC_RX
            ldi
            ldi
            call    arc_emit                   ; tail-calls PLOT_SUB which writes COORDS
            jp      TEMPS

;================================================================
; Plot_arc_pt
;
; Inputs : ARC_RX, ARC_RY      -- signed candidate offset from C
;          ARC_UX..ARC_VY      -- u, v vectors
;          ARC_FLAGS           -- sigma sign + major flag
;          ARC_CX, ARC_CY      -- centre
; Action : plots (Cx + rx, Cy + ry) iff p lies in the requested
;          angular sweep.
; Clobbers: A, BC, DE, HL.  IX preserved across call.
;
; Membership predicate (docs/PRECISION_ANALYSIS.md, sec 3.1):
;
;   A_cross = ux*ry - uy*rx
;   B_cross = rx*vy - ry*vx
;   if sigma < 0: A := -A ; B := -B
;
;   minor arc:  (A >= 0) AND (B >= 0)
;   major arc:  NOT ( (A < 0) AND (B < 0) )
;================================================================

Plot_arc_pt:
            ;; --- A_cross = UX*RY - UY*RX ---
            ld      hl, ARC_UX                 ; first operand pair
            ld      de, ARC_RX                 ; second (P0=RX, P1=RY)
            call    do_cross                   ; HL = A_cross (sigma-corrected)
            ld      b, h                       ; B = sign byte of A_cross
            ;; --- B_cross = RX*VY - RY*VX = (VY*RX) - (VX*RY) ---
            ;; Same shape as cross(V, R) but with operand order swapped,
            ;; which is the NEGATIVE of cross(V, R).  do_cross flips sign
            ;; if sigma<0; we want B_cross = -cross(V,R).  Easiest: pass
            ;; (R, V) instead -- giving cross(R, V) = RX*VY - RY*VX. 
            ld      hl, ARC_RX
            ld      de, ARC_VX
            call    do_cross                   ; HL = B_cross (sigma-corrected)
            ld      a, (ARC_FLAGS)
            bit     1, a
            ld      a, h                       ; A = sign byte of B_cross
            jr      nz, .major
            ;; minor: reject if EITHER negative (b7 of A or B set)
            or      b
            ret     m
            jr      arc_emit
.major:                                       ; reject iff BOTH negative
            and     b
            ret     m

;;----------------------------------------------------------------
;; arc_emit -- plot (Cx + ARC_RX, Cy + ARC_RY). Tail-calls PLOT_SUB.
;; Shared by per-octant emit and endpoint-forcing block.
;;----------------------------------------------------------------
arc_emit:
            ld      a, (ARC_CX)
            ld      hl, ARC_RX
            add     a, (hl)
            ld      c, a
            ld      a, (ARC_CY)
            ld      hl, ARC_RY
            add     a, (hl)
            ld      b, a
            jp      PLOT_SUB                   ; tail-call (writes COORDS)

;================================================================
; do_cross --  HL = (*P)*(*(Q+1)) - (*(P+1))*(*Q)
;              then negated if ARC_FLAGS bit 0 (sigma<0).
;
; In : HL -> P (2 signed bytes:  P0, P1)
;      DE -> Q (2 signed bytes:  Q0, Q1)
; Out: HL = signed result
; Clobbers: A, BC, DE, HL.
;================================================================
do_cross:
            ld      a, (hl)                    ; A = P0
            inc     hl                         ; -> P1
            inc     de                         ; -> Q1
            ex      de, hl                     ; HL -> Q1, DE -> P1
            ld      c, (hl)                    ; C = Q1
            dec     hl                         ; HL -> Q0
            push    hl                         ; save Q-ptr
            push    de                         ; save P-ptr (-> P1)
            call    mul8s                      ; HL = P0*Q1
            pop     de                         ; DE -> P1
            ex      (sp), hl                   ; stack top = P0*Q1; HL -> Q0
            ld      a, (de)                    ; A = P1
            ld      c, (hl)                    ; C = Q0
            call    mul8s                      ; HL = P1*Q0
            ex      de, hl                     ; DE = P1*Q0
            pop     hl                         ; HL = P0*Q1
            and     a
            sbc     hl, de                     ; HL = P0*Q1 - P1*Q0
            ;; --- sigma fix: negate HL if flag bit 0 set ---
            ld      a, (ARC_FLAGS)
            rrca                               ; CY = bit 0
            ret     nc
            ;; HL := -HL   (CY may be 1 here; compute without sbc)
            xor     a
            sub     l
            ld      l, a
            sbc     a, a
            sub     h
            ld      h, a
            ret

;================================================================
; mul8s -- signed 8x8 -> 16 multiply.
;   In : A = a (signed), C = b (signed)
;   Out: HL = a * b
;   Clobbers A, B, D, E ; IX, IY preserved ; C preserved.
;================================================================
mul8s:                              ; A signed * C signed -> HL signed
            ld      b, a                   ; B = original A
            xor     c                      ; sign-of-product in bit 7 of A
            push    af                     ; save sign
            ld      a, b                   ; A = original A
            or      a
            jp      p, .pa
            neg
.pa:
            ld      h, a                   ; H = |A|
            ld      a, c                   ; A = original C
            or      a
            jp      p, .pc
            neg
.pc:
            ld      e, a                   ; E = |C|
            ld      d, 0
            ld      l, d                   ; L = 0
            ld      a, h                   ; multiplier in A
            ld      h, d                   ; H = 0 (HL = accumulator)
            ld      b, 8
.lp:
            add     hl, hl
            add     a, a                   ; b7 -> CY
            jr      nc, .sk
            add     hl, de
.sk:
            djnz    .lp
            pop     af                     ; restore sign-of-product (in bit 7)
            ret     p                      ; if positive, done
            xor     a                      ; HL := -HL
            sub     l
            ld      l, a
            sbc     a, a
            sub     h
            ld      h, a
            ret

;================================================================
; END of ARC.asm
;================================================================
