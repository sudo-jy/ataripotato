; HOT POTATO

; Source code (C) 2025 Jacob Younan

    processor 6502          ; Import MOS Technology 6502 processor definitions
    include "vcs.h"         ; Import Atari 2600 architecture definitions
    include "macro.h"       ; Import Atari 2600 code macros

; --------------------------- CONSTANTS ------------------------------

PLAYER0WALL     equ #$46                ; P1 Top bound (red)
PLAYER1WALL     equ #$88                ; P2 Left bound (yellow)
PLAYER2WALL     equ #$46                ; P3 Right bound (green)
PLAYER3WALL     equ #$88                ; P4 Bottom bound (blue)
BORDERHEIGHT    equ #$08                ; Top and bottom border width in scanlines
BACKGROUNDCOLOR equ #$02                ; Background color
BALLCOLOR       equ #$0E                ; Ball color

VPLAYER_OFFSET  equ #10                 ; Distance player paddles are from top and bottom walls
HPLAYER_OFFSET  equ #02                 ; Distance player paddles are from left and right walls
P1_X            equ #80                 ; Default X position of P1 sprite
P2_X            equ #20                 ; Default X position of P2 sprite
P2_Y            equ #111                ; Default Y Position of P2 sprite
P3_X            equ #80                 ; Default X position of P3 sprite
P4_X            equ #158                ; Default X position of P4 sprite
P4_Y            equ #111                ; Default Y position of P4 sprite
BALL_X          equ #89                 ; Default X position of Ball
BALL_Y          equ #91                 ; Default Y Position of Ball
HPADDLE_WIDTH	equ #04			; Width of horizontal paddles (P1 & P3)
VPADDLE_WIDTH   equ #28                 ; Width of vertical paddles (P2 & P4)
BALL_WIDTH      equ #6                  ; Width of Ball

VBLANK_NTSC     equ #37                 ; Scanlines of VBLANK
SCANLINES_NTSC  equ #192                ; Scanlines of visible image
OVERSCAN_NTSC   equ #30                 ; Scanlines of overscan before VBLANK for next frame begins

; --------------------------- VARIABLES ------------------------------

    seg.u vars                          ; Variables segment
    org $80                             ; Start of RAM

s0_x            ds 1                    ; Sprite 0 x position
grp0            ds 1                    ; temporary holder of GRP0
colup0          ds 1                    ; temporary holder of COLUP0

colup1          ds 1                    ; temporary holder of COLUP1
s1_x            ds 1                    ; Sprite 1 x position
ts0_x           ds 1                    ; temporary Sprite 0 x position
ts1_x           ds 1                    ; temporary Sprite 1 x position

m0_yL           ds 1                    ; Missile 0 y position lower point
m0_yU           ds 1                    ; Missile 0 y position upper point
m1_yL           ds 1                    ; Missile 1 y position lower point
m1_yU           ds 1                    ; Missile 1 y position upper point

ball_x          ds 1                    ; Ball x position
ball_yL         ds 1                    ; Ball y position lower point
ball_yU         ds 1                    ; Ball y position upper point

framecounter    ds 1                    ; Frame counter

b_bearing        ds 1                   ; (0-15) 16 angles 22.5 deg apart
b_bearing_old    ds 1                   ; holds the original bearing (direction) of the ball before bounce
collision_count  ds 1                   ; collision count

health1          ds 1                   ; Health for P1
health2          ds 1                   ; Health for P2

snd_on           ds 1                   ; Greater that 0 if sound is playing on channel 0

    seg main
    org $F000

reset:
    CLEAN_START

    lda #%00100011          ; Set D0 to reflect playfield, D1 for two-color mode, and D4-D5 for 2x ball size
    sta CTRLPF              ; Apply to CTRLPF register

    lda #BACKGROUNDCOLOR    ; Set background color
    sta COLUBK              ; 
    lda #BALLCOLOR          ; Set ball color
    sta COLUPF              ; 

    lda #P1_X               ; Initial x position
    sta s0_x                ; Store x position
    ldx #0                  ; Sprite 0
    jsr pos_x               ; Set initial coarse position of the Sprite 0 graphic

    lda #P3_X               ; Initial x position
    sta s1_x                ; Store x position
    ldx #1                  ; Sprite 1
    jsr pos_x               ; Set initial coarse position of the Sprite 1 graphic

    lda #P2_X               ; Initial x position
    ldx #2                  ; Missile 0
    jsr pos_x               ; Set initial coarse position of the Missile 0 graphic

    lda #P2_Y               ; Initial y position
    sta m0_yL               ;
    sbc #VPADDLE_WIDTH      ; Subtract offset to get top of P2 paddle 
    sta m0_yU               ; 

    lda #P4_X               ; Initial x position
    ldx #3                  ; Missile 1
    jsr pos_x               ; Set initial coarse position of the Missile 0 graphic

    lda #P4_Y               ; Initial y position
    sta m1_yL               ;
    sbc #VPADDLE_WIDTH      ; Subtract offset to get top of P4 paddle 
    sta m1_yU               ;

    lda #BALL_X             ; Initial x position
    sta ball_x              ; Store x position
    ldx #4                  ; Ball
    jsr pos_x               ; Set initial coarse position of the Ball graphic

    lda #BALL_Y             ; Initial y position
    sta ball_yL             ;
    sbc #BALL_WIDTH         ; Subtract offset to get top of Ball
    sta ball_yU             ;
    
    sta WSYNC               ; Apply all position changes
    sta HMOVE               ;

    lda #9                 ; Set intiial bearing index from bearing_offsets address
    sta b_bearing

    lda #%00010101          ; Stretch all sprites and missiles to 2x size
    sta NUSIZ0              ; 
    sta NUSIZ1              ; 
    
    lda #%00000000          ; Reset horizontal movement to all objects
    sta HMP0                ; 
    sta HMP1                ; 
    sta HMM0                ; 
    sta HMM1                ; 
    sta HMBL                ; 

    sta framecounter        ; Initialize framecounter
    lda #200
    sta health1
    sta health2

nextFrame:
    VERTICAL_SYNC

verticalBlank:
    ldx #43                ; 37sl * 76mc = 2812
    stx TIM64T             ; set 64-clock for 43 intervals. 43 * 64mc = 2752mc before timer ends

; Process sound
    lda snd_on             ; check is sound 0 is active
    beq snd                ; are we playing a sound? Yes
    dec snd_on
    bne snd
    lda #0
    sta AUDV0              ; since we know a = 0, use it to turn off the volume
snd:

; Read controllers for input
; Joystick 0

; Left & Right
    ldx s0_x
    lda #%10000000          ; Check for right movement
    bit SWCHA
    bne pos_noright1
    cpx #142
    bcs pos_noright1
    inx
    inx
pos_noright1:
    lda #%01000000          ; Check left movement
    bit SWCHA
    bne pos_noleft1
    cpx #20
    bcc pos_noleft1
    dex
    dex
pos_noleft1:
    stx s0_x
    stx s1_x

; Up & Down
    ldx m0_yL
    lda #%00010000          ; Check for up movement
    bit SWCHA
    bne pos_nodown1
    cpx #38
    bcc pos_nodown1
    dex
    dex
pos_nodown1:
    lda #%00100000          ; Check for down movement
    bit SWCHA
    bne pos_noup1
    cpx #182
    bcs pos_noup1
    inx
    inx
pos_noup1:
    txa
    sbc #VPADDLE_WIDTH      ; Subtract offset to get top of vertical paddle 0
    txa
    sta m0_yL               ;
    sta m1_yL               ;
    sbc #VPADDLE_WIDTH      ; Subtract offset to get top of vertical paddle 1
    sta m0_yU               ; 
    sta m1_yU               ;

    lda s0_x                ; 
    ldx #0                  ; Set movement of horizontal paddle 0
    jsr pos_x               ; 

    lda s1_x                ; 
    ldx #1                  ; Set movement of horizontal paddle 1
    jsr pos_x               ; 

    sta WSYNC               ; Apply all position changes
    sta HMOVE               ;


; Calculate ball collisions, current position and direction

    lda CXP0FB              ; Ball collision with players?
    ora CXP1FB              ; 
    ora CXM0FB              ; Ball collision with missiles?
    ora CXM1FB              ; 
    and #%01000000          ;
    cmp #%01000000          ; If colliding with anything other than a wall, bounce
    bne collision           ; 

    lda #0                  ; Otherwise no collision is registered, set collision count to 0
    sta collision_count
    jmp no_collision        ; bypass collision handling

; If collision occurs try a reflected bearing. 
; If still registering collision on the next frame then try a horizontal bearing. 
; If it's collision still registers then reflect it 180 degrees from the original pre-bounce bearing.

; Collision occurs
collision:
    lda collision_count     ; How many times has a collision occured consecutively
    bne col_on              ; Branch if collisions are already ongoing

    lda b_bearing           ; Get the current bearing
    sta b_bearing_old       ; Store current missile b_bearing
    eor #$FF                ; Reverse bearings
    sta b_bearing
    inc b_bearing           ; Additive reverse
    lda b_bearing
    and #$03                ; Is bearing N,S,E,W?
    bne col_no_adj
    inc b_bearing           ; Increment bearing by one offset to prevent continuous reflection

col_no_adj:
    jmp collision_done

col_on:
    cmp #$01                ; Check collision_count
    beq reverse_bearing     ; First collision in series
    cmp #$03                ; cCheck collision_count
    bcc collision_done      ; Second/third collision in series
    bne collision_done      ; More than three collisions in series
    lda b_bearing_old       ; Retrieve pre-bounce bearing
    jmp reverse_org_bearing ; Reverse bearing it 180 degrees

reverse_bearing:
    lda b_bearing           ; Reverse altered bearing
reverse_org_bearing:        ; Reverse original bearing
    clc                     ; Clear carry so it's not included in add on next instruction
    adc #$08                ; Reverse bearing by 180 degrees
    sta b_bearing

collision_done:
    inc collision_count    ; increment the number of consecutive collisions
no_collision:

    ; move the ball
    lda b_bearing
    and #$0F               ; strip the high nibble
    tay
    lda bearing_offsets,y  ; load the x/y offsets based on the current bearing

    sta HMBL                ; update the balls horizontal motion register which will only
                            ; use the high nibble where the x offset is stored.
    and #$0F                ; strip out the high nibble which leaves only the y offset
    sec                     ; set the carry flag
    sbc #$08                ; subtract 8 for 4bit 2's completment +/-
    clc                     ; clear carry flag so it's not used in the following add
    adc ball_yL             ; add y offset to current y position
    and #$FE
    sbc #1
    sta ball_yL             ; store the new y position
    sbc #BALL_WIDTH         ; Set ball upper height
    and #$FE
    sbc #1
    sta ball_yU             ; 

    lda CXP0FB              ; Ball collision with players (P1)?
    ora CXP1FB              ; 
    and #%01000000          ;
    cmp #%01000000          ; If player collides with ball, decrement health
    beq decHealth1

    lda CXM0FB              ; Ball collision with missiles (P2)?
    ora CXM1FB              ; 
    and #%01000000          ;
    cmp #%01000000          ; If player collides with ball, decrement health
    beq decHealth2
    jmp checktimer

decHealth1:
    dec health1
    ; turn on sound for hit
    lda #$9                ; Distortion type
    sta AUDC0              ; Audio control
    sta AUDF0              ; Audio frequency
    lda $6
    sta AUDV0              ; Audio volume
    lda #$1                ; Frames to play sound
    sta snd_on
    jmp checktimer
decHealth2:
    dec health2
    ; turn on sound for hit
    lda #$6                ; Distortion type
    sta AUDC0              ; Audio control
    sta AUDF0              ; Audio frequency
    sta AUDV0              ; Audio volume
    lda #$1                ; Frames to play sound 
    sta snd_on
    ;jmp checktimer

; checkGameOver:
;     lda health1
;     cmp #0
;     beq gameOverP1
;     lda health2
;     cmp #0
;     beq gameOverP2
; gameOverP1:
;     lda #0
;     sta HMBL
; gameOverP2:
;     lda #0
;     sta HMBL

    sta WSYNC
    sta HMOVE
checktimer:
    lda INTIM              ; Time remaining (or past)
    bne checktimer         ; Burn remaining cycles

; End VBLANK
    lda #$0                 ; set D1 to 0 to end VBLANK
    sta WSYNC               ;
    sta VBLANK              ; Turn on the beam
; Clear latched collisions for next frame
    sta CXCLR

    ; --------------------------- 192 lines of playfield ------------------------------
    
    tax                     ; Initialize scanline counter
kernel:
    txa
    and #%1
    beq playfieldTop

    ; Update drawing P2 & P4 paddles and ball on odd-numbered scanlines
    ; and drawing P1 & P3 paddles and playfield on even-numbered scanlines
drawLP:
    cpx m0_yU
    bne drawRP
    jsr draw_P2
drawRP:
    cpx m1_yU
    bne drawBall
    jsr draw_P4
drawBall:
    cpx ball_yU
    bne undrawLP
    jsr draw_Ball
undrawLP:
    cpx m0_yL
    bne undrawRP
    jsr undraw_P2
undrawRP:
    cpx m1_yL
    bne undrawBall
    jsr undraw_P4
    jmp playfieldTop
undrawBall:
    cpx ball_yL
    bne drawdone
    jsr undraw_Ball

playfieldTop:
    cpx #0                                  ; Check if top border is about to be drawn
    bne playfieldWalls                      ; 
    jmp bordertop                           ; Draw top border
playfieldWalls:
    cpx #BORDERHEIGHT                       ; Check if border walls are about to be drawn
    bne drawUP                              ;
    jmp borderwalls                         ; Draw border walls
drawUP:
    cpx #VPLAYER_OFFSET                       ; Check if P1 paddle is about to be drawn
    bne undrawUP                              ;
    jmp draw_P1                               ; Draw Player 1 (Sprite 0)
undrawUP:
    cpx #VPLAYER_OFFSET + #HPADDLE_WIDTH      ; Check if P1 paddle is about to be undrawn
    bne drawDP                                ;
    jmp undraw_P1                             ; Undraw Player 1 (Sprite 0)
drawDP:
    cpx #SCANLINES_NTSC - #VPLAYER_OFFSET - HPADDLE_WIDTH     ; Check if P3 paddle is about to be drawn
    bne undrawDP
    jmp draw_P3                               ; Draw Player 3 (Sprite 1)
undrawDP:
    cpx #SCANLINES_NTSC - #VPLAYER_OFFSET     ; Check if P1 paddle is about to be undrawn
    bne playfieldBottom
    jmp undraw_P3                             ; Undraw Player 1 (Sprite 0)
playfieldBottom:
    cpx #SCANLINES_NTSC - #BORDERHEIGHT     ; Check if bottom border is about to be drawn
    bne drawdone                        ; Draw bottom border
    jmp borderbottom

bordertop:
    lda #%11111111          ; Solid line of pixels
    sta PF0                 ; Set all PF registers
    sta PF1                 ; 
    sta PF2                 ; 
    lda #PLAYER0WALL        ; Set top border to P1 color
    sta COLUP0              ; 
    sta COLUP1              ; 

    jmp drawdone

borderbottom:
    lda #%11111111          ; Solid row of pixels for all PF# registers
    sta PF0                 ; 
    sta PF1                 ; 
    sta PF2                 ; 
    lda #PLAYER2WALL        ; Set bottom border to P3 color
    sta COLUP0              ; 
    sta COLUP1              ; 

    jmp drawdone
    
borderwalls:
    sta WSYNC
    ;inx
    lda #%00110000          ; Set the first pixel of PF0. Uses the 4 hight bits and rendered in reverse.
    sta PF0                 ; Set PF0 register
    lda #%00000000          ; Clear the PF1-2 registers to have an empty middle
    sta PF1                 ; 
    sta PF2                 ; 
    lda #PLAYER1WALL        ; Set left border to P2 color
    sta COLUP0              ; 
    lda #PLAYER3WALL        ; Set right border to P4 color
    sta COLUP1              ; 

    jmp drawdone

drawdone:
    sta WSYNC
    inx
    cpx #SCANLINES_NTSC
    beq endOfScreen
    jmp kernel

endOfScreen:
    ; --------------------------- End of screen - enter blanking ----------------------

    ; ------- 76543210 ---------- Bit order
    lda #%01000010          ; Set D0, D6 of vblank register
    sta VBLANK              ; 

    ; -------------------------- 30 scanlines of overscan -----------------------------

    ldx #OVERSCAN_NTSC
overscan:
    sta WSYNC
    inc framecounter
    ;---------------------------------------
    dex
    bne overscan            ; branch up to 'overscan' label, compare if not equal
    jmp nextFrame           ; frame completed, branch up to the 'nextFrame' label
    ;------------------------------------------------

draw_P1:
    sta WSYNC
    ;inx
    lda #PLAYER0WALL
    sta COLUP0
    lda #$FF                ; Graphics for Sprite 0
    sta GRP0                ; 
    jmp drawdone

undraw_P1:
    sta WSYNC
    ;inx
    lda #PLAYER1WALL
    sta COLUP0
    lda #0
    sta GRP0
    jmp drawdone

draw_P3:
    sta WSYNC
    ;inx
    lda #PLAYER2WALL
    sta COLUP1
    lda #$FF                ; Graphics for Sprite 1
    sta GRP1                ; 
    jmp drawdone

undraw_P3:
    sta WSYNC
    ;inx
    lda #PLAYER3WALL
    sta COLUP1
    lda #0
    sta GRP1
    jmp drawdone

draw_P2:
    sta WSYNC
    ;inx
    lda #%00000010
    sta ENAM0
    rts

draw_P4:
    sta WSYNC
    ;inx
    lda #%00000010
    sta ENAM1
    rts

draw_Ball:
    sta WSYNC
    ;inx
    lda #%00000010
    sta ENABL
    rts

undraw_P2:
    lda #%00000000
    sta ENAM0
    rts

undraw_P4:
    lda #%00000000
    sta ENAM1
    rts

undraw_Ball:
    lda #%00000000
    sta ENABL
    rts

; SetHorizPos routine
; A = X coordinate
; X = player number (0 or 1)
pos_x
    sta WSYNC               ; start a new line
    sec                     ; set carry flag
pos_x_loop
    sbc #15                 ; subtract 15
    bcs pos_x_loop          ; branch until negative
    eor #7                  ; calculate fine offset
    asl                     ; Shift left x4
    asl                     ; 
    asl                     ; 
    asl                     ; 
    sta RESP0,x             ; fix coarse position
    sta HMP0,x              ; set fine offset
    rts                     ; return to caller

bearing_offsets
    ;                      index   x-move          y-move  deg     direction
    ;-------------------------------------------------------------------------
    .byte #%11101000       ; 0     -2      (8-8)   0       90      right
    .byte #%11100111       ; 1     -2      (7-8)  -1       112.5
    .byte #%11100110       ; 2     -2      (6-8)  -2       135
    .byte #%11110110       ; 3     -1      (6-8)  -2       157.5
    .byte #%00000110       ; 4      0      (6-8)  -2       180     down
    .byte #%00010110       ; 5     +1      (6-8)  -2       202.5
    .byte #%00100110       ; 6     +2      (6-8)  -2       225
    .byte #%00100111       ; 7     +2      (7-8)  -1       247.5
    .byte #%00101000       ; 8     +2      (8-8)   0       270     left
    .byte #%00101001       ; 9     +2      (9-8)  +1       292.5
    .byte #%00101010       ; 10    +2      (10-8) +2       315
    .byte #%00011010       ; 11    +1      (10-8) +2       337.5
    .byte #%00001010       ; 12     0      (10-8) +2       0/360   up
    .byte #%11111010       ; 13    -1      (10-8) +2       22.5
    .byte #%11101010       ; 14    -2      (10-8) +2       45
    .byte #%11101001       ; 15    -2      (9-8)  +1       67.5

; -------------------------- END OF ROM -----------------------------
    org $fffa               ; set origin to last 6 bytes of 4k rom
interruptVectors:
    .word reset             ; nmi
    .word reset             ; reset
    .word reset             ; irq