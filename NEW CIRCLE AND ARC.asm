
; -----------------------------------------------------------------------------
; THE NEW 'CIRCLE' COMMAND
; -----------------------------------------------------------------------------
;
; Initially, the syntax has been partly checked using the class for the DRAW
; command which stacks the origin of the circle (X,Y).
; --------------------------------------------------------------------------------

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
COORDS:	EQU $5C7D


            ORG $2320
;;CIRCLE
L2320:
            rst     18h                             ; GET-CHAR x, y.
            cp      $2C                             ; Is character the required comma ?
            jp      nz, REPORT_C                    ; Error Report: Nonsense in BASIC
            rst     20h                             ; NEXT-CHAR advances the parsed character address.
            call    EXPT_1NUM                       ; routine EXPT-1NUM stacks radius in runtime.
            call    CHECK_END                       ; routine CHECK-END will return here in runtime
                                                    ; if nothing follows the command.
; Now make the radius positive and ensure that it is in floating point form
; so that the exponent byte can be accessed for quick testing.
new_circle_entry:
;; FP-CALC x, y, r.
            RST     28H                             ; FP-CALC x, y, r.
            DEFB    $2A                             ; abs x, y, r.
            DEFB    $3D                             ; re-stack x, y, r.
            DEFB    $38                             ; end-calc x, y, r.
            ld      a,(hl)                          ; Fetch first, floating-point, exponent byte.
            cp      $81                             ; Compare to one.
            jr      nc,L233B                        ; Forward to C-R-GRE-1
                                                    ; if circle radius is greater than one.

; The circle is no larger than a single pixel so delete the radius from the
; calculator stack and plot a point at the centre.
            RST     28H                             ; FP-CALC x, y, r.
            DEFB    $02                             ; delete x, y.
            DEFB    $38                             ; end-calc x, y.
            jr      PLOT_SUB                        ; back to PLOT routine to just plot x,y.
; ---
;; C-R-GRE-1
L233B:
            call    STK_TO_A                        ;  A = radius
            push    af
            call    STK_TO_BC                       ;  C=Xc, B=Yc
            pop     af
            ld      e,c
            ld      d,b                              ; (d,e) contains the center coordinates (yc, xc)
            ld      c,a                              ; x = r
            ld      b,0                              ; y = 0 ; (b,c) stores the current arc point coordinates (y,x)
            ld      hl,0                             ; error = 0 (I need 16 bits)
            jp      C8LOOP                           ; label_238D

Plot_circ:
            push    bc
            exx                                      ; keep the registers
            pop     bc
            call    PLOT_SUB                         ; + $4 ;PLOT
            exx                                      ; recovers registers.
            ret

label_2358:
Mask_tab:
;; lookup table with mask for plot
            DEFB    $7F                              ; 01111111 ($7F)
            DEFB    $BF                              ; 10111111 ($BF)
            DEFB    $DF                              ; 11011111 ($DF)
            DEFB    $EF                              ; 11101111 ($EF)
            DEFB    $F7                              ; 11110111 ($F7)
            DEFB    $FB                              ; 11111011 ($FB)
            DEFB    $FD                              ; 11111101 ($FD)
            DEFB    $FE                              ; 11111110 ($FE)
            ; *** 2 bytes free
            nop
            nop

;===============================================================
; DRAW_ARC - ZX Spectrum 48K - Fully compatible with ROM
; Input: FP calculator stack with [dx, dy, A] (angle in radians)
; Output: Draws arc using PLOT (ROM $22E5)
; Test: DRAW 100,50,1.5 → perfect arc
;===============================================================
;L2360:
draw_arc:
            rst     20h                              ; NEXT-CHAR advances the parsed character address.
            call    EXPT_1NUM                        ; routine EXPT-1NUM stacks radius in runtime.
            call    CHECK_END                        ; routine CHECK-END will return here in runtime
                                                     ; if nothing follows the command.
;; Now enter the calculator and store the complete rotation angle in mem-5
            RST     28H                              ;; FP-CALC x, y, A.
            DEFB    $C5                              ;; st-mem-5 x, y, A.
; Test the angle for the special case of 360 degrees.
            DEFB    $A2                              ;; stk-half x, y, A, 1/2.
            DEFB    $04                              ;; multiply x, y, A/2.
            DEFB    $1F                              ;; sin x, y, sin(A/2).
            DEFB    $31                              ;; duplicate x, y, sin(A/2),sin(A/2)
            DEFB    $30                              ;; not x, y, sin(A/2), (0/1).
            DEFB    $30                              ;; not x, y, sin(A/2), (1/0).
            DEFB    $00                              ;; jump-true x, y, sin(A/2).
            DEFB    DR_SIN_NZ - $                    ;; to DR_SIN_NZ ;$06 

; If sin(A/2) is not zero Then the third parameter is 2*PI (or a multiple of 2*PI)
; so a 360 degrees turn would just be a straight line.
; Eliminating this case here prevents division by zero at later stage.
            DEFB    $02                              ;; delete x, y.
            DEFB    $38                              ;; end-calc x, y.
            jp      L2477                            ; forward to LINE-DRAW
; ---
;===============================================================
; Valid arc: New Arc algorithm
;===============================================================
; We want to draw a circular arc that:
; Starts at P1
; Ends at P2
; Rotates counterclockwise by a total angle θ
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
; θ is the central angle subtended by the chord P₁–P₂, that is, the angle ∠P₁CP₂.
;===============================================================
; Start by computing R, h, Cx, Cy
;===============================================================
DR_SIN_NZ:
            DEFB    $C0                              ; st-mem-0 ← sin(A/2) dx, dy, sin(A/2).
            DEFB    $02                              ; delete dx, dy
            DEFB    $C2                              ; st-mem-2 ← dy
            DEFB    $31                              ; duplicate
            DEFB    $04                              ; multiply -> dy²
            DEFB    $01                              ; exchange
            DEFB    $C1                              ; st-mem-1 <- dx
            DEFB    $31                              ; duplicate
            DEFB    $38                              ; end-calc
            jp      ARC_CIRC8
          
            ORG     $2382

; --------------------
; THE 'DRAW' COMMAND
; --------------------
; The Spectrum's DRAW command is overloaded and can take two parameters sets.
;
; With two parameters, it simply draws an approximation to a straight line
; at offset x,y using the LINE-DRAW routine.
;
; With three parameters, an arc is drawn to the point at offset x,y turning
; through an angle, in radians, supplied by the third parameter.
; The ARC drawing implemented here uses a new algorithm.
;; DRAW
label_2382:
            rst     18h                              ; GET-CHAR
            cp      $2C                              ; is it the comma character ?
            jr      z, draw_arc                      ; forward, if so to new draw_arc 
; There are two parameters e.g. DRAW 255,175
            call    CHECK_END                        ; routine CHECK-END
            jp      L2477                            ; jump forward to LINE-DRAW
; ---
;;DR-3-PRMS
C8LOOP:
; ============================================================
; Circle routine (optimized)
; Inputs:
; A = radius
; ($5C7D) = Yc (center Y)
; ($5C7E) = Xc (center X)
; Uses BC=(y,x), DE=(Yc,Xc), HL=error
; ============================================================
; ============================================================
; Plot all 8 symmetric points
; ============================================================
            push    hl                               ; save HL (error) to use as temporary
            push    bc                               ; y,x
            ld      h,b
            ld      l,c
; ==================================================
; 1st OCTANT: (Yc + y, Xc + x)
; ==================================================
            ld      a,l                              ; x
            add     a,e                              ; x+Xc
            ld      c,a                              ; c <-- Xc+x
            ld      a,h
            add     a,d
            ld      b,a                              ; Yc + y
            call    Plot_circ                        ; (Yc + y, Xc + x)
; ==================================================
; 2nd OCTANT: (Yc - y, Xc + x)
; ==================================================
            ld      a,d
            sub     h
            ld      b,a                              ; Yc - y
            call    Plot_circ                        ; (Yc - y, Xc + x)
; ==================================================
; 3rd OCTANT: (Yc - y, Xc - x)
; ==================================================
            ld      a,e
            sub     l
            ld      c,a
            call    Plot_circ                        ; (Xc - x, Yc - y)
; ==================================================
; 4th OCTANT: (Yc + y, Xc - x)
; ==================================================
            ld      a,h
            add     a,d
            ld      b,a                              ; Yc + y
            call    Plot_circ                        ; (Xc - x, Yc + y)
; ==================================================
; 5th OCTANT: (Yc + x, Xc + y)
; ==================================================
            ld      a,h
            add     a,e
            ld      c,a                              ; Xc + y
            ld      a,l
            add     a,d
            ld      b,a                              ; Yc + x
            call    Plot_circ                        ; (Xc + y, Yc + x)
; ==================================================
; 6th OCTANT: (Yc - x, Xc + y)
; ==================================================
            ld      a,d
            sub     l
            ld      b,a                              ; Yc - x
            call    Plot_circ                        ; (Xc + y, Yc - x)
; ==================================================
; 7th OCTANT: (Yc - x, Xc - y)
; ==================================================
            ld      a,e
            sub     h
            ld      c,a                              ; Xc - y
            call    Plot_circ                        ; (Xc - y, Yc - x)
; ==================================================
; 8th OCTANT: (Yc + x, Xc - y)
; ==================================================
            ld      a,d
            add     a,l
            ld      b,a                              ; Yc + x
            call    Plot_circ                        ; (Xc - y, Yc + x)

; ------ Optimized Bresenham Algorithm ------
            pop     bc                               ; x,y
            pop     hl
            ld      a,c                              ; save x
; error += 1 + 2*y (B = y)
            inc     hl                               ; error += 1
            ld      c,b                              ; c <-- y
            ld      b,0                              ; BC = y
            add     hl,bc                            ; error += y
            add     hl,bc                            ; error += y (total: + 2*y)
            ld      b,c
            ld      c,a
            inc     b                                ; y++

; Verify if error - x <= 0 (C = x)
            push    hl                               ; [1] preserve error
            ld      a,b
            ld      b,0                              ; BC = x
            and     a                                ; clear carry
            sbc     hl,bc                            ; error - x
            dec     hl                               ; error - x - 1
            bit     7,h                              ; error - x <= 0 ?
            ld      b,a
            pop     hl                               ; [1] restore error
            jr      nz,skip_circ8                    ; if positive, skip

            ; Adjust error and decrement x
            ; error += 1 - 2*x ;(c = x)
            ld      a,b
            ld      b,0                              ; BC = x
            and     a                                ; clear carry
            sbc     hl,bc                            ; error -= x
            sbc     hl,bc                            ; error -= x (total: - 2*x)
            inc     hl                               ; error += 1
            ld      b,a
            dec     c                                ; x--

skip_circ8:
            ld      a,c
            cp      b                                ; y <= x?
            jp      nc,C8LOOP                        ; If yes, continue
            JP      TEMPS                            ; TEMPS

;===============================================================
; Arc continuation -
; d = sqrt(dx^2 + dy^2) ; - Distance between the two points
;===============================================================
ARC_CIRC8:
            ; stack: dx,dy^2
            RST     28H
            DEFB    $04                              ; multiply -> dx^2
            DEFB    $0F                              ; addition -> dx^2 + dy^2
            DEFB    $28                              ; sqr -> d       ; Destroy mem 3 and mem 4
            DEFB    $C3                              ; st-mem-3 <- d (safe: result pushed) ************
            ; ------------------------------------
            ; R = d / (2 * sin(A/2)) Radius
            ; ------------------------------------
            ; stack: d
            DEFB    $31                              ; duplicate
            DEFB    $E0                              ; get-mem-0 → sin(A/2)
            DEFB    $31                              ; duplicate
            DEFB    $0F                              ; add => 2 * sin(A/2)
            DEFB    $05                              ; divide => d / (2*sin(A/2)) = R Radius
            DEFB    $C4                              ; st-mem-4 ← R ********************
            ; --- h² = R² - (d/2)² ---
            DEFB    $31                              ; duplicate R
            DEFB    $04                              ; multiply → R^2
            ; ------------------------
            ; d2 = d / 2
            ; ------------------------
            ; stack: d,R^2
            DEFB    $01                              ; exchange → (d, R²)
            DEFB    $A2                              ; stk-half ;1/2
            DEFB    $04                              ; multiply -> d/2
            ; stack R^2, d/2
            DEFB    $31                              ; duplicate
            DEFB    $04                              ; multiply → (d/2)^2
            DEFB    $03                              ; subtract → h²
            ; store in mem-0
            DEFB    $C0                              ; st-mem-0 <- h^2
            DEFB    $38                              ; end-calc

            ; --- Check h² >= 0 ---
            ; The HL register now addresses the exponent byte
            ld      a,(hl)                           ; A = exponent
            and     a
            jr      z, Calcular_Cy                   ; exponent == 0 => value is 0
            inc     hl
            bit     7,(hl)
            jp      nz,REPORT_BC                     ; REPORT-BC: impossible arc

H_pos_expo:
            RST     28H
            DEFB    $e4                              ; R
            DEFB    $01                              ; exchange
            DEFB    $e3                              ; d
            DEFB    $01                              ; exchange
            DEFB    $28                              ; sqrt(h²) <<<<< ; Destroy mem 3 and mem 4 with the new SQR.
            DEFB    $c0                              ; h -> mem 0
            DEFB    $02                              ; delete
            DEFB    $c3                              ; d → mem-3
            DEFB    $02                              ; delete
            DEFB    $c4                              ; R → mem-4
            DEFB    $02                              ; delete
            DEFB    $38                              ; end-calc

;===============================================================
; Cx = x1 + dx/2 + h * (-dy / d)
; Cy = y1 + dy/2 + h * (dx / d)
;===============================================================
Calcular_Cy:
            ld      a, ($5C7E)                       ; A = y1 (COORDS high byte)
            call    label_2D28                       ; ROM: push y1 as FP value
            RST     28H                              ; Start FP calculator block
            ; --- Compute Cy ---
            ; stack: y1
            DEFB    $E0                              ; get-mem-0 → h
            DEFB    $01                              ; exchange
            ; stack: h,y1
            DEFB    $E2                              ; get-mem-2 → dy
            DEFB    $A2                              ; stk-half (0.5)
            DEFB    $04                              ; multiply → dy/2
            ; defb $0F ; add → y1 + dy/2
            DEFB    $E0                              ; get-mem-0 → h
            DEFB    $E1                              ; get-mem-1 → dx
            DEFB    $E3                              ; get-mem-3 → d
            DEFB    $05                              ; divide → dx / d
            DEFB    $04                              ; multiply → h * (dx/d)
            DEFB    $0F                              ; add → dy/2 + h * (dx/d)
            DEFB    $c0                              ; st-mem-0 → -yrel_i
            DEFB    $0F                              ; add → Cy= y1 + dy/2 + h * (dx/d)
            ; stack: h,Cy
            DEFB    $01                              ; exchange
            ; stack: Cy,h
            DEFB    $E0                              ; get-mem-0 → -yrel_i
            DEFB    $01                              ; exchange
            ; stack: Cy,-yrel_i,h
            DEFB    $38                              ; end-calc

            ld      a, (COORDS)                       ; A = x1 (COORDS low byte)
            call    label_2D28                       ; ROM: push x1 as FP value
            RST     28H                              ; Start FP calculator block
            ; --- Compute Cx ---
            ; stack: Cy,-yrel_i,h,x1
            DEFB    $01                              ; exchange
            ; stack: Cy,-yrel_i,x1,h
            ; defb $E0 ; get-mem-0 → h
            DEFB    $E2                              ; get-mem-2 → dy
            DEFB    $1B                              ; negate → -dy
            DEFB    $E3                              ; get-mem-3 → d
            DEFB    $05                              ; divide → -dy / d
            DEFB    $04                              ; multiply → h * (-dy/d)
            DEFB    $E1                              ; get-mem-1 → dx
            DEFB    $A2                              ; stk-half (0.5)
            DEFB    $04                              ; multiply → dx/2
            ; defb $0F ; add → x1 + dx/2
            DEFB    $0F                              ; add dx/2 + h * (-dy/d)
            DEFB    $c0                              ; st-mem-0 → -xrel_i
            DEFB    $0F                              ; add → Cx
            DEFB    $E0                              ; get-mem-0 → ; -xrel_i

; --------------------------------------------------------------
; Calc N = INT(R * A) and Δθ = A / N
; mem-3 = N
; --------------------------------------------------------------
            ; stack ; -Cy,-yrel_i,Cx,-xrel_i
            DEFB    $E5                              ; get-mem-5 -> A (input angle in radians)
            DEFB    $31                              ; duplicate
            DEFB    $E4                              ; get-mem-4 -> R (arc radius)
            DEFB    $04                              ; multiply ; N = R * A
            DEFB    $27                              ; INT → N = floor(R*A) — number of steps
            DEFB    $C3                              ; st-mem-3 ← N
            ; Δθ = A / N
            DEFB    $05                              ; Division: Δθ = A / N (angular step)

; --------------------------------------------------------------
; Precompute_SinCos: calculate sin(Δθ) and cos(Δθ)
; Store: mem-2 = cos(Δθ)
;        mem-4 = sin(Δθ)
; --------------------------------------------------------------
            ; Note: 'sin' and 'cos' trash locations mem-0 to mem-2
            ; stack: -Cy,-yrel_i,Cx,-xrel_i,Δθ
            DEFB    $31                              ; duplicate Δθ
            DEFB    $1f                              ; sin
            DEFB    $C4                              ; st-mem-4 ← sin(Δθ)
            DEFB    $01                              ; exchange
            DEFB    $20                              ; cos
            DEFB    $C2                              ; st-mem-2 ← cos(Δθ)
            DEFB    $02                              ; delete
            DEFB    $02                              ; delete
            ; stack: -Cy,-yrel_i,Cx,-xrel_i
            DEFB    $e3                              ; N
            DEFB    $38                              ; END-CALC
            call    FIND_INT1                        ; routine FIND-INT1 fetches N from stack to A.
            ld      b,a                              ; B = loop counter (N)
            push    bc
            ; or a                                   ; Test if N = 0
            ; ret z                                  ; Exit early if N=0 (degenerate case)

Draw_Arc_DDA:
ARC_DRAW:
;===============================================================
; INITIALIZATION OF x_rel AND y_rel (Relative to Arc Center)
; x_rel = x1 - Cx
; y_rel = y1 - Cy
; --------------------------------------------------------------
; Direct vector formula — NO x1/y1 dependency
; Formulas:
; x_rel = -dx/2 + h * (dy / d)
; y_rel = -dy/2 - h * (dx / d)
;
; Output:
; mem-0 = x_rel (initial relative X)
; mem-3 = y_rel (initial relative Y)
;===============================================================
            ; stack: -Cy,-yrel_i,Cx,-xrel_i
            RST     28h
            DEFB    $1B                              ; negate → -xrel_i
            DEFB    $c0                              ; xrel_i -> mem-0
            DEFB    $02                              ; delete
            DEFB    $c1                              ; Cx -> mem-1
            DEFB    $02                              ; delete
            DEFB    $1B                              ; negate → -yrel_i
            DEFB    $c3                              ; yrel_i -> mem-3
            DEFB    $02                              ; delete
            DEFB    $c5                              ; Cy -> mem-5
            DEFB    $38                              ; END-CALC
            jr      Arc_Loop

            ORG     $2477
;; LINE-DRAW
L2477:
            call    DRAW_LINE                       ; routine DRAW-LINE draws to the relative
            jp      TEMPS                           ; jump back and exit via TEMPS >>>

;;===============================================================
; MAIN LOOP - Rotational DDA
; mem 0 - x_rel
; mem 1 - cx
; mem 2 - cos(Δθ)
; mem 3 - y_rel
; mem 4 - sin(Δθ)
; mem 5 - cy
;===============================================================
Arc_Loop:
            pop     bc
Loop_Start:
            push    bc
            ; ----------------------------------------------
            ; calculate new x_rel:
            ; x' = x*cos - y*sin
            ; ----------------------------------------------
            RST     28h
            DEFB    $E0                              ; get-mem-0 (x)
            DEFB    $E2                              ; get-mem-2 (cos)
            DEFB    $04                              ; multiply
            DEFB    $E3                              ; get-mem-3 (y)
            DEFB    $E4                              ; get-mem-4 (sin)
            DEFB    $04                              ; multiply
            DEFB    $03                              ; subtract
            DEFB    $C0                              ; st-mem-0 (new x_rel)
            ; X = Cx + x_rel
            DEFB    $E1                              ; Cx
            DEFB    $0F                              ; addition

            ; ----------------------------------------------
            ; calculate new y_rel:
            ; y' = x*sin + y*cos
            ; ----------------------------------------------
            DEFB    $E0                              ; get-mem-0 (x)
            DEFB    $E4                              ; get-mem-4 (sin)
            DEFB    $04                              ; multiply
            DEFB    $E3                              ; get-mem-3 (y)
            DEFB    $E2                              ; get-mem-2 (cos)
            DEFB    $04                              ; multiply
            DEFB    $0F                              ; add
            DEFB    $C3                              ; st-mem-3 (new y_rel)
            ; Y = Cy + y_rel
            DEFB    $E5                              ; Cy
            DEFB    $0F                              ; addition
            DEFB    $38                              ; END-CALC

; --------------------------------------------------------------
; Plot actual point (Cx+x_rel , Cy+y_rel)
; --------------------------------------------------------------
            call    STK_TO_BC
            call    PLOT_SUB                         ; + $4
            pop     bc
            djnz    Loop_Start
            ret

; -----------------------------
; THE 'LINE DRAWING' ROUTINE
; -----------------------------
           
            ORG $24B7
DRAW_LINE:



