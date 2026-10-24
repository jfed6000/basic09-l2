********************************************************************
* keys - read a key and turn it into an editor key code
*
* The Wildbits keyboard drivers send a character plus key sense bits
* (SS.KySns, buffered with each character).  Both keyboards (Jr2 PS/2
* and K2) are folded into one set of editor key codes here; see
* docs/EDITOR.md for what each driver sends.

KB.SHF              equ       $01                 SS.KySns bits
KB.CTRL             equ       $02
KB.ALT              equ       $04
KB.UP               equ       $08
KB.DOWN             equ       $10
KB.LEFT             equ       $20
KB.RIGHT            equ       $40

* Editor key codes.  $01-$1A are Ctrl+letter, $09 Tab, $0D Enter and
* $20-$7E printable characters.  The arrows are $80-$8F: plain, +4 with
* Ctrl, +8 with Shift, +12 with both.
EK.UP               equ       $80
EK.DOWN             equ       $81
EK.LEFT             equ       $82
EK.RIGHT            equ       $83
EK.PGUP             equ       $84                 Ctrl+Up
EK.PGDN             equ       $85                 Ctrl+Down
EK.WLEFT            equ       $86                 Ctrl+Left
EK.WRIGHT           equ       $87                 Ctrl+Right
EK.SUP              equ       $88                 Shift+arrows select
EK.SDOWN            equ       $89
EK.SLEFT            equ       $8A
EK.SRIGHT           equ       $8B
EK.TOP              equ       $8C                 Ctrl+Shift+Up
EK.BOTTOM           equ       $8D                 Ctrl+Shift+Down
EK.SWLEFT           equ       $8E                 Ctrl+Shift+Left
EK.SWRIGHT          equ       $8F                 Ctrl+Shift+Right
EK.BS               equ       $90                 Backspace
EK.DEL              equ       $91                 Shift+Backspace
EK.ESC              equ       $92                 Esc (PS/2), BREAK (K2)
EK.HOME             equ       $93                 Home (K2)
EK.CSPC             equ       $94                 Ctrl+Space (unbound; kept for completion)
EK.MOUSE            equ       $95                 a mouse event (mouse.asm)
EK.FPREV            equ       $96                 Ctrl+Shift+L find previous
EK.SP1              equ       $97                 Ctrl+1 single spacing
EK.SP2              equ       $98                 Ctrl+2 double spacing
EK.SCR              equ       $99                 Ctrl+3 80x30 / 80x60 screen
EK.WHEEL            equ       $9A                 the mouse wheel: muwst steps (mouse.asm)
EK.F1               equ       $A1                 F1-F8 are $A1-$A8
EK.F2               equ       $A2
EK.SF1              equ       $A9                 Shift+F1 (PS/2)
EK.SF2              equ       $AA                 Shift+F2 (PS/2)
EK.ALT              equ       $C1                 Alt+A to Alt+Z are $C1-$DA
EK.EOF              equ       $FF                 end of the key input

* getkey: A = the next key (EK.EOF at the end of the input)
getkey              pshs      b,x,y
gk0                 lbsr      mu_wait             (A = EK.MOUSE or EK.WHEEL)
                    bcs       gk3
                    bsr       k_byte
                    bcs       gk_eof
                    cmpa      #$FD                script wheel: $FD <steps, signed>
                    bne       gk0w
                    bsr       k_byte
                    bcs       gk_eof
                    tfr       a,b
                    sex
                    ldx       <base
                    std       muwst,x
                    lda       #EK.WHEEL
                    bra       gk3
gk0w                cmpa      #$FE                script mouse: $FE <buttons> <col> <row>
                    bne       gk0a
                    leas      -3,s
                    leax      ,s
                    ldy       #3
                    lda       <kbpath
                    os9       I$Read
                    puls      a,x                 A = buttons, X = the cell
                    bcs       gk_eof
                    lbsr      mu_new
                    bcc       gk0                 no event: the next key
gk_mouse            lda       #EK.MOUSE
                    bra       gk3
gk0a                cmpa      #$FF                script prefix: $FF <kysns> <char>
                    bne       gk1
                    bsr       k_byte
                    bcs       gk_eof
                    sta       <ksns
                    bsr       k_byte
                    bcs       gk_eof
                    bra       gk2
gk1                 pshs      a
                    lda       <kbpath
                    ldb       #SS.KySns
                    os9       I$GetStt
                    bcc       gk1a
                    clra
gk1a                sta       <ksns
                    puls      a
gk2                 bsr       k_norm
gk3                 sta       <key
                    puls      b,x,y,pc
gk_eof              tst       <hold               -h: keep the screen for a snapshot
                    beq       gk_eof1
                    lbsr      t_flush
gk_hold             ldx       #0
                    os9       F$Sleep
                    bra       gk_hold
gk_eof1             lda       #EK.EOF
                    sta       <key
                    puls      b,x,y,pc

* k_byte: A = one byte from the key path; carry at the end
k_byte              ldx       <base
                    leax      kraw,x
                    ldy       #1
                    lda       <kbpath
                    os9       I$Read
                    bcs       kb9
                    lda       <kraw
kb9                 rts

* k_norm: A = character, ksns = key sense bits -> A = editor key code
k_norm              ldb       <ksns
                    bitb      #KB.UP
                    beq       kn1
                    cmpa      #$0C
                    bne       kn1
                    lda       #EK.UP
                    bra       kn_arrow
kn1                 bitb      #KB.DOWN
                    beq       kn2
                    cmpa      #$0A
                    bne       kn2
                    lda       #EK.DOWN
                    bra       kn_arrow
kn2                 bitb      #KB.LEFT
                    beq       kn3
                    cmpa      #$08
                    bne       kn3
                    lda       #EK.LEFT
                    bra       kn_arrow
kn3                 bitb      #KB.RIGHT
                    beq       kn4
                    cmpa      #$09
                    bne       kn4
                    lda       #EK.RIGHT
kn_arrow            bitb      #KB.CTRL
                    beq       kna1
                    adda      #4
kna1                bitb      #KB.SHF
                    beq       kna2
                    adda      #8
kna2                rts
kn4                 bitb      #KB.ALT             Alt+letter
                    beq       kn6
                    cmpa      #$81                K2 sends letter+$40
                    blo       kn4a
                    cmpa      #$9A
                    bhi       kn6
                    suba      #$81-'A
                    bra       kn5
kn4a                cmpa      #'a                 PS/2 sends the letter
                    blo       kn4b
                    cmpa      #'z
                    bhi       kn6
                    suba      #$20
kn4b                cmpa      #'A
                    blo       kn6
                    cmpa      #'Z
                    bhi       kn6
kn5                 adda      #EK.ALT-'A
                    rts
kn6                 bitb      #KB.CTRL            Ctrl+Space: $20 (K2) or
                    beq       kn6b                $20-$60 = $C0 (PS/2)
                    cmpa      #C$SPAC
                    beq       kn6a
                    cmpa      #$C0
                    bne       kn6c
kn6a                lda       #EK.CSPC
                    rts
kn6c                cmpa      #'1                 Ctrl+1 to Ctrl+3: the digit (K2) or
                    blo       kn6h                the digit-$60 (PS/2)
                    cmpa      #'3
                    bls       kn6e
kn6h                cmpa      #'1-$60
                    blo       kn6g
                    cmpa      #'3-$60
                    bhi       kn6g
                    adda      #$60
kn6e                adda      #EK.SP1-'1
                    rts
kn6g                bitb      #KB.SHF             Ctrl+Shift+L: $0C (K2) or
                    beq       kn6b                'L-$60 = $EC (PS/2)
                    cmpa      #$0C
                    beq       kn6d
                    cmpa      #$EC
                    bne       kn6b
kn6d                lda       #EK.FPREV
                    rts
kn6b                cmpa      #$08                Backspace (no LEFT bit)
                    bne       kn7
                    lda       #EK.BS
                    rts
kn7                 cmpa      #$18                Shift+Backspace; Ctrl+X stays $18
                    bne       kn8
                    bitb      #KB.CTRL
                    bne       kn_ret
                    bitb      #KB.SHF
                    beq       kn_ret
                    lda       #EK.DEL
                    rts
kn8                 cmpa      #$05                Esc/BREAK; Ctrl+E stays $05
                    bne       kn9
                    bitb      #KB.CTRL
                    bne       kn_ret
                    bitb      #KB.SHF             Shift+RUN/STOP (K2; Shift+Esc on
                    beq       kn8a                the PS/2): Run, as ^R (the K2's
                    lda       #$12                load-and-run key, as on Commodores)
                    rts
kn8a                lda       #EK.ESC
                    rts
kn9                 cmpa      #$01                K2 Home; Ctrl+A stays $01
                    bne       kn10
                    bitb      #KB.CTRL
                    bne       kn_ret
                    lda       #EK.HOME
                    rts
kn10                cmpa      #$B1                PS/2 F1, F2, Shift+F1, Shift+F2
                    blo       kn11
                    cmpa      #$B4
                    bhi       kn_none
                    suba      #$10
                    cmpa      #$A3
                    blo       kn_ret
                    adda      #EK.SF1-$A3
                    rts
kn11                cmpa      #$A1                K2 F1-F8
                    blo       kn12
                    cmpa      #$A8
                    bls       kn_ret
                    bra       kn_none
kn12                cmpa      #$7F
                    blo       kn_ret              controls and printable characters
kn_none             clra
kn_ret              rts
