; --------------------
; THE NEW 'CIRCLE' COMMAND
; --------------------
;
;   Initially, the syntax has been partly checked using the class for the DRAW 
;   command which stacks the origin of the circle (X,Y).
;---------------------------------------------------------------------
label_2320:
	rst	18h				; GET-CHAR              x, y.
	cp 	$2C	 			; Is character the required comma ?
	jp	nz, label_1C8A  ; Error Report: Nonsense in BASIC

	rst	20h	 			; NEXT-CHAR advances the parsed character address.
	call	label_1C82  ; routine EXPT-1NUM stacks radius in runtime.
	
	call	label_1BEE   ; routine CHECK-END will return here in runtime
                         ; if nothing follows the command.

;   Now make the radius positive and ensure that it is in floating point form 
;   so that the exponent byte can be accessed for quick testing.

new_circle_entry:
;; FP-CALC              x, y, r.
	rst	28h   		;; FP-CALC              x, y, r.
        DEFB    $2A             ;;abs                   x, y, r.
        DEFB    $3D             ;;re-stack              x, y, r.
        DEFB    $38             ;;end-calc              x, y, r.

        ld      a,(hl)          ; Fetch first, floating-point, exponent byte.
        cp      $81             ; Compare to one.
        jr      nc,label_233B        ; Forward to C-R-GRE-1 
                                ; if circle radius is greater than one.

;    The circle is no larger than a single pixel so delete the radius from the
;    calculator stack and plot a point at the centre.

    	rst     28h             ;; FP-CALC              x, y, r.
        DEFB    $02             ;;delete                x, y.                  
        DEFB    $38             ;;end-calc              x, y.

        jr      label_22DC           ; back to PLOT routine to just plot x,y.

; ---
;; C-R-GRE-1
label_233B:
	CALL label_2314     ;; STK-TO-A  A = radius
   	PUSH AF         ; 
   	CALL label_2307 ;  STK-TO-BC  C=Xc, B=Yc
    	POP AF          ; 

    	ld 	e,c
	ld 	d,b  ; (d,e) contains the center coordinates (yc, xc)
	
	ld      c,a     ; x = r
    	ld      b,0     ; y = 0  	;; (b,c) stores the current arc point coordinates (y,x)
 
    	ld      hl,0    ; error = 0 (I need 16 bits)

	JP C8LOOP   ;label_238D


Plot_circ: 
	push bc
 	exx   ; keep the registers
	pop bc
	call label_22E5 ;+ $4  ;PLOT
    	exx          ; recovers registers.
    	ret

label_2358: 
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
	
	;*** 2 bytes free
	nop
	nop
		

;===============================================================
; DRAW_ARC - ZX Spectrum 48K - Fully compatible with ROM
; Input: FP calculator stack with [dx, dy, A] (angle in radians)
; Output: Draws arc using PLOT (ROM $22E5)

;  Teste: DRAW 100,50,1.5 → perfect arc
;===============================================================	
label_2360:
draw_arc:
;****
	rst	20h	     ; NEXT-CHAR advances the parsed character address.
	call	label_1C82   ; routine EXPT-1NUM stacks radius in runtime.
	call	label_1BEE   ; routine CHECK-END will return here in runtime
                             ; if nothing follows the command.

;;   Now enter the calculator and store the complete rotation angle in mem-5 

        RST     28H             ;; FP-CALC      x, y, A.
        DEFB    $C5             ;;st-mem-5      x, y, A.
;   Test the angle for the special case of 360 degrees.
        DEFB    $A2             ;;stk-half      x, y, A, 1/2.
        DEFB    $04             ;;multiply      x, y, A/2.
        DEFB    $1F             ;;sin           x, y, sin(A/2).
        DEFB    $31             ;;duplicate     x, y, sin(A/2),sin(A/2)
        DEFB    $30             ;;not           x, y, sin(A/2), (0/1).
        DEFB    $30             ;;not           x, y, sin(A/2), (1/0).
        DEFB    $00             ;;jump-true     x, y, sin(A/2).

        DEFB    DR_SIN_NZ - $ ;;to DR_SIN_NZ  ;$06 ;;forward to L23A3, DR-SIN-NZ
						;  
						
;   If sin(A/2) is not zero Then the third parameter is 2*PI (or a multiple of 2*PI) 
;   so a 360 degrees turn would just be a straight line. 
;   Eliminating this case here prevents division by zero at later stage.

        DEFB    $02             ;;delete        x, y.
        DEFB    $38             ;;end-calc      x, y.

        jp      label_2477      ; forward to LINE-DRAW
; ---
;===============================================================
; Valid arc: New Arc algorithm
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

;===============================================================
;Start by computing R, h, Cx, Cy
;===============================================================
label_23A3:
DR_SIN_NZ: 
  	DEFB  	$C0      ; st-mem-0 ← sin(A/2)   dx, dy, sin(A/2).
	DEFB  	$02      ; delete         dx, dy
	defb  	$C2      ; st-mem-2 ← dy
	defb    $31      ; duplicate
        defb    $04      ; multiply -> dy²   

	defb    $01      ; exchange
	defb    $C1      ; st-mem-1 <- dx
        defb    $31      ; duplicate

 	defb    $38      ; end-calc
	
	jp ARC_CIRC8

	ORG $2382
; ------------------
; THE 'DRAW' COMMAND
; ------------------
;   The Spectrum's DRAW command is overloaded and can take two parameters sets.
;
;   With two parameters, it simply draws an approximation to a straight line
;   at offset x,y using the LINE-DRAW routine.
;
;   With three parameters, an arc is drawn to the point at offset x,y turning 
;   through an angle, in radians, supplied by the third parameter.

;;   The ARC drawing implemented here uses a new algorithm.

;; DRAW	
label_2382:
	rst	18h	; GET-CHAR
	cp 	$2C	 ; is it the comma character ?
	jr	z, draw_arc ;forward, if so, to DR-3-PRMS

;   There are two parameters e.g. DRAW 255,175
	call	label_1BEE   ; routine CHECK-END
	jp	label_2477   ;jump forward to LINE-DRAW

; ---
label_238D:
; ============================================================
; Circle routine (optimized)
; Inputs:
;   A  = radius
;   ($5C7D) = Yc (center Y)
;   ($5C7E) = Xc (center X)
; Uses BC=(y,x), DE=(Yc,Xc), HL=error
; ============================================================
C8LOOP:
; ============================================================
; Plot all 8 symmetric points
; ============================================================

   	push hl            ; salvar HL (erro) para usar como temporário
	push bc 	       ; y,x
	
	ld  	h,b
  	ld  	l,c

; ==================================================
; 1º OCTANTE: (Yc + y,Xc + x)
; ==================================================	
	ld  	a,l  ;x
    add 	a,e  ;x+Xc
	ld 	c,a  ;c <-- xo+x
    ld  	a,h
  	add 	a,d
	ld 	b,a  ; yo + y
  	call    Plot_circ       ; (yo + y, xo + x )
; ==================================================
; 2º OCTANTE: ( Yc - y, Xc + x)
; ==================================================
	ld      a,d
    sub     h
    ld      b,a       	; yo - y
    call    Plot_circ       ; (yo - y,xo + x )
; ==================================================
; 3º OCTANTE: (Yc - y , Xc - x )
; ==================================================
	ld      a,e
   	sub     l
	ld 	c,a
   	call    Plot_circ         	; (xo - x, yo - y)
; ==================================================
; 4º OCTANTE: (Yc + y, Xc - x )
; ==================================================
 	ld 	a,h
    add     a,d  	
	ld 	b,a 	; yo + y

   	call    Plot_circ          ; (xo - x, yo + y)
 
; ==================================================
; 5º OCTANTE: (Yc + x, Xc + y )
; ==================================================
	ld 	a,h
   	add     a,e
   	ld      c,a       ; xo + y
  	ld 	a,l
 	add     a,d
   	ld      b,a       ; yo + x
   	call    Plot_circ         ; (xo + y, yo + x)
; ==================================================
; 6º OCTANTE: (Yc - x, Xc + y )
; ==================================================
	ld 	a,d
	sub     l
   	ld      b,a       ; yo - x
   	call    Plot_circ        ; (xo + y, yo - x)
; ==================================================
; 7º OCTANTE: ( Yc - x, Xc - y)
; ==================================================
	ld 	a,e
	sub     h
 	ld      c,a       ; xo - y
  	call    Plot_circ        ; (xo - y, yo - x)

; ==================================================
; 8º OCTANTE: (Yc + x,Xc - y)
; ==================================================
	ld 	a,d
  	add     a,l
 	ld      b,a       ; yo + x
  	call    Plot_circ ; (xo - y, yo + x)

; ==================================================
; ; --- Optimized Bresenham Algorithm ---
; ==================================================
	pop bc ;x,y
	pop hl
	
	ld a,c  ;guarda x

; error += 1 + 2*y (B = y)
	inc     hl          ; error += 1

	;push    bc          ; 
	ld      c,b         ; c <--  y
	ld      b,0         ; BC = y
	add     hl,bc       ; error += y
	add     hl,bc       ; error += y (total: + 2*y)
	;pop     bc         ; restaura x,y

	ld b,c
	ld c,a
	inc     b           ; y++

; Verify if error - x <= 0 (C = x)
	
	push    hl          ; [1] preserva error

	ld a,b
	;push    bc          ; [2] preserva (y,x)
	ld      b,0         ; BC = x
	and a ;xor     a           ; clear carry
	;ld      b,a
	sbc     hl,bc       ; error - x
	dec     hl          ; error - x - 1
	bit     7,h         ; erro - x <= 0?
	ld b,a	
	;pop     bc          ; [2] restaura (y,x)
	pop     hl          ; [1] restaura error
	
	jr      nz,skip_circ8    ; se positivo, salta

 ; Ajusta erro e decrementa x
; error += 1 - 2*x      ;(c = x)
	ld a,b
	;push    bc          ; preserva (y,x)
	ld      b,0         ; BC = x
	and a  ;xor     a   ; clear carry
	;ld 	b,a	    ; BC = x	

	sbc     hl,bc       ; error -= x
	sbc     hl,bc       ; erro  -= x    (total: - 2*x)
	inc     hl          ; error += 1
	ld b,a
	;pop     bc          ; restaura (y,x)
	dec     c           ; x--

skip_circ8:
    	ld      a,c
   	cp      b       ; y <= x?
 	jp      nc,C8LOOP   ; Se sim, continua
	
    	JP	label_0D4D ; TEMPS
 	
;===============================================================
; Arc continuation - 
; d = sqrt(dx^2 + dy^2)   ; - Distancia entre os 2 pontos
;===============================================================
ARC_CIRC8:
	;stack: dx,dy^2
 	rst     28h
        
	defb    $04      ; multiply -> dx^2
        defb    $0F      ; addition -> dx^2 + dy^2
        defb    $28       ; sqr -> d			           ;Destroy mem 3 e mem 4
        defb    $C3      ; st-mem-3 <- d (safe: result pushed)     **********************
      
	; ----------------------------  
        ; R = d / (2 * sin(A/2))    Radius
        ; ----------------------------
	;stack: d
        defb    $31      ; duplicate
        defb    $E0      ; get-mem-0 → sin(A/2)
	defb    $31      ; duplicate 
        defb    $0F      ; add => 2 * sin(A/2)
	defb    $05      ; divide => d / (2*sin(A/2)) = R    Radius
  	defb    $C4      ; st-mem-4 ← R            ***********************

	;--- h² = R² - (d/2)² ---
       	defb    $31            ; duplicate R
        defb    $04            ; multiply → R^2
	 ; ----------------------------
        ; d2 = d / 2
        ; ----------------------------
	; stack: d,R^2
	defb    $01      ; exchange → (d, R²)
        defb    $A2      ; stk-half ;1/2
        defb    $04      ; multiply -> d/2
 	; stack R^2, d/2
        defb    $31      ; duplicate
        defb    $04      ; multiply → (d/2)^2
	defb    $03      ; subtract → h²
         ; guardar em mem-0
	defb    $C0      ; st-mem-0 <- h^2
	defb    $38      ; end-calc


	;--- Check h² >= 0 ---
	; The HL register now addresses the exponent byte
	ld      a, (hl)      ; A = expoente
	and     a
        jr      z,  Calcular_Cy   ; expoente == 0 => value is 0
	inc 	hl
	bit 7,(hl)
	jp      nz,label_24F9 ; REPORT-Bc: impossible arc

H_pos_expo:
        rst     28h
	defb    $e4  	; R
	defb    $01     ; exchange
	defb    $e3  	; d
	defb    $01     ; exchange
	defb    $28     ; sqrt(h²)    <<<<<<<<<<<<<<<<   ;Destroy mem 3 e mem 4 wihth the new SQR.
	defb    $c0     ; h-> mem 0
	defb    $02     ; delete
	defb    $c3     ; d → mem-3
	defb    $02     ; delete
	defb    $c4     ; R → mem-4
	defb    $02     ; delete
	defb    $38     ; end-calc

;===============================================================
; Cx = x1 + dx/2 + h * (-dy / d)
; Cy = y1 + dy/2 + h * (dx / d)
;===============================================================
Calcular_Cy:
	
	ld      a, ($5C7E)              ; A = y1 (COORDS high byte)
    call    label_2D28              ; ROM: push y1 as FP value
   	rst     28h                     ; Start FP calculator block
	;--- Compute Cy ---
	; stack: y1
	defb     $E0                     ; get-mem-0 → h
	defb     $01   					 ; exchange
	; stack: h,y1
	defb     $E2                     ; get-mem-2 → dy
   	defb     $A2                     ; stk-half (0.5)
   	defb     $04                     ; multiply → dy/2
   	;defb     $0F                     ; add → y1 + dy/2
   	defb     $E0                     ; get-mem-0 → h
   	defb     $E1                     ; get-mem-1 → dx
   	defb     $E3                     ; get-mem-3 → d
   	defb     $05                     ; divide → dx / d
   	defb     $04                     ; multiply → h * (dx/d)
   	defb     $0F                     ; add → dy/2 + h * (dx/d)
	defb     $c0                    ; st-mem-0 → -yrel_i
	defb     $0F                     ; add → Cy= y1 + dy/2 + h * (dx/d)

	; stack: h,Cy
	defb     $01   			 ; exchange
	; stack: Cy,h
	defb     $E0                     ; get-mem-0 → -yrel_i
	defb     $01   			 ; exchange
	; stack: Cy,-yrel_i,h
   	defb    $38                      ; end-calc
	
	ld      a, ($5C7D)              ; A = x1 (COORDS low byte)
    call    label_2D28              ; ROM: push x1 as FP value
	
	rst     28h                     ; Start FP calculator block
	;--- Compute Cx ---
	; stack: Cy,-yrel_i,h,x1
	defb     $01   			 ; exchange
	; stack: Cy,-yrel_i,x1,h
	;defb    $E0                     ; get-mem-0 → h
   	 defb    $E2                     ; get-mem-2 → dy
   	 defb    $1B                     ; negate → -dy
   	 defb    $E3                     ; get-mem-3 → d
   	 defb    $05                     ; divide → -dy / d
  	 defb    $04                     ; multiply → h * (-dy/d)
	 defb    $E1                     ; get-mem-1 → dx
   	 defb    $A2                     ; stk-half (0.5)
   	 defb    $04                     ; multiply → dx/2
   	; defb    $0F                     ; add → x1 + dx/2
   	 defb    $0F                     ; add dx/2 + h * (-dy/d)
	 defb    $c0                     ; st-mem-0 → -xrel_i
  	 defb    $0F                     ; add → Cx
	 defb    $E0                     ; get-mem-0 → ;-xrel_i
  	    	

    			
;-------------------------------------------
; Calc  N = INT(R * A)  and  Δθ = A / N
;  mem-3 = N
;;-------------------------------------------
	;stack ;-Cy,-yrel_i,Cx,-xrel_i

    defb    $E5             ; get-mem-5 -> A (input angle in radians)
	defb    $31	        ; duplicate
	defb    $E4             ; get-mem-4 -> R (arc radius)
 	defb    $04             ; multiply ; N = R * A
	defb    $27             ; INT → N = floor(R*A)	— number of steps
	
    defb    $C3             ; st-mem-3 ← N

 	; Δθ = A / N 
	defb    $05             ; Division: Δθ = A / N  (angular step)

    

;---------------------------------------------------
; Precompute_SinCos: calculate sin(Δθ) e cos(Δθ)
; Guarda: mem-2 = cos(Δθ)
;           mem-4 = sin(Δθ)
;---------------------------------------------------
 ;   Note: 'sin' and 'cos' trash locations mem-0 to mem-2

    ; stack: ;-Cy,-yrel_i,Cx,-xrel_i,Δθ
   	defb   $31	       ; duplicate Δθ
	defb   $1f             ; sin
	defb   $C4	       ; st-mem-4 ← sin(Δθ)
	defb   $01             ; exchange
	defb   $20	       ; cos
	defb   $C2             ; st-mem-2 ← cos(Δθ)

	
	defb   $02             ; delete
	defb   $02             ; delete
	
	 ; stack: ;-Cy,-yrel_i,Cx,-xrel_i

	defb   $e3             ;N
    defb   $38             ; END-CALC
	
	call   label_1E94      ; routine FIND-INT1 fetches N from stack to A.
	ld b,a                 ; B = loop counter (N)   
	push bc
	;or      a              ; Test if N = 0
    ;ret     z              ; Exit early if N=0 (degenerate case)

Draw_Arc_DDA:
ARC_DRAW:
;===============================================================
; INITIALIZATION OF x_rel AND y_rel (Relative to Arc Center)
; x_rel = x1 - Cx
; y_rel = y1 - Cy
;-------------------------------------
; Direct vector formula — NO x1/y1 dependency
; Formulas:
;   x_rel = -dx/2 + h * (dy / d)
;   y_rel = -dy/2 - h * (dx / d)
;
; Output:
;   mem-0 = x_rel  (initial relative X)
;   mem-3 = y_rel  (initial relative Y)
;===============================================================
    	 ; stack: ;-Cy,-yrel_i,Cx,-xrel_i
   	 rst  28h
	 defb   $1B             ; negate → -xrel_i
	 defb   $c0             ; xrel_i  - mem-0
	 defb   $02             ; delete
	 defb   $c1             ; Cx  - mem-1
	 defb   $02             ; delete
	 defb   $1B             ; negate → -yrel_i
	 defb   $c3             ; yrel_i  - mem-3
	 defb   $02             ; delete
	 defb   $c5             ; Cy  - mem-5
	 defb   $38             ; END-CALC

	jr Arc_Loop

;---------------------------------------------------------------
	ORG $2477
;; LINE-DRAW
label_2477:  
	call    label_24B7           ; routine DRAW-LINE draws to the relative 
        JP      label_0D4D           ; jump back and exit via TEMPS          >>>

;;===============================================================
; MAIN LOOP - Rotational DDA

   ; mem 0 - x_rel
   ; mem 1 - cx
   ; mem-2 - cos(Δθ)
   ; mem 3 - y_rel
   ; mem-4 - sin(Δθ)
   ; mem 5 - cy 
;===============================================================
Arc_Loop:
	pop bc

Loop_Start:
	push bc
	
    ;----------------------------------
    ; calculate new  x_rel:
    ; x' = x*cos - y*sin
    ;----------------------------------
	RST     28h
        DEFB    $E0         ; get-mem-0 (x)
        DEFB    $E2         ; get-mem-2 (cos)
    	DEFB    $04         ; multiply
    	DEFB    $E3         ; get-mem-3 (y)
    	DEFB    $E4         ; get-mem-4 (sin)
    	DEFB    $04         ; multiply
    	DEFB    $03         ; subtract
    	DEFB    $C0         ; st-mem-0 (novo x_rel)

    ; X = Cx + x_rel
        DEFB    $E1         ; Cx
        DEFB    $0F         ; addition

    ;----------------------------------
    ; calcular novo y_rel:
    ; y' = x*sin + y*cos
    ;----------------------------------
	DEFB    $E0         ; get-mem-0 (x)
    	DEFB    $E4         ; get-mem-4 (sin)
    	DEFB    $04         ; multiply
    	DEFB    $E3         ; get-mem-3 (y)
    	DEFB    $E2         ; get-mem-2 (cos)
    	DEFB    $04         ; multiply
    	DEFB    $0F         ; add
    	DEFB    $C3         ; st-mem-3 (novo y_rel)
    	
   ; Y = Cy + y_rel
        DEFB    $E5          ; Cy
        DEFB    $0F          ; addition
 	
	defb    $38          ; END-CALC

;---------------------------------------
; Plot actual point (Cx+x_rel , Cy+y_rel)
;---------------------------------------

	;; STK-TO-BC
	call label_2307
 	;call    Plot_circ        ; desenha pixel
	call label_22E5 ;+ $4
	
	pop bc
	djnz Loop_Start
	ret

; --------------------------
; THE 'LINE DRAWING' ROUTINE
; --------------------------

	ORG $24B7

