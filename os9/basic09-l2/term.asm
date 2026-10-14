********************************************************************
* term - terminal setup and screen output
*
* Output goes through a 256-byte buffer; t_flush writes it to the
* screen path.  The control codes are the CoCo/Wildbits VTIO ones.

* t_init: raw key input, screen size, text window
t_init              clr       <kbpath             keys from path 0
                    lda       #1
                    sta       <scpath             screen on path 1
                    ldx       <base
                    leax      optsav,x
                    clra
                    clrb                          SS.Opt
                    os9       I$GetStt
                    bcs       ti2
                    lda       ,x                  PD.DTP: device type
                    cmpa      #DT.SCF
                    bne       ti2                 not a terminal
                    ldx       <base               copy, then clear echo, pause and
                    ldy       <base               the interrupt/abort characters
                    leay      optraw,y
                    leax      optsav,x
                    ldb       #32
ti1                 lda       ,x+
                    sta       ,y+
                    decb
                    bne       ti1
                    ldx       <base
                    leax      optraw,x
                    clr       PD.EKO-PD.OPT,x
                    clr       PD.PAU-PD.OPT,x
                    clr       PD.INT-PD.OPT,x
                    clr       PD.QUT-PD.OPT,x
                    clr       PD.PSC-PD.OPT,x
                    clra
                    clrb
                    os9       I$SetStt
                    lda       #1                  the screen path too (page pause)
                    clrb
                    os9       I$SetStt
                    inc       <kbterm
ti2                 ldx       <base               screen size, from a terminal only
                    leax      rline,x             (a file answers SS.ScSiz without an
                    lda       <scpath             error)
                    clrb                          SS.Opt
                    os9       I$GetStt
                    bcs       ti2a
                    lda       ,x
                    cmpa      #DT.SCF
                    bne       ti2a
                    lda       <scpath
                    ldb       #SS.ScSiz
                    os9       I$GetStt
                    bcc       ti3
ti2a                ldx       #80
                    ldy       #30
ti3                 tfr       x,d
                    cmpb      #128
                    bls       ti4
                    ldb       #128
ti4                 stb       <scrw
                    subb      #2                  inside the frame
                    stb       <wcols
                    tfr       y,d
                    stb       <scrh
                    subb      #4                  menu bar, two borders, hint line
                    stb       <wrows
                    lda       #2
                    sta       <wtop
                    lda       #1
                    sta       <wleft
                    lbsr      t_glyph
                    lbra      hl_init

* t_done: put the terminal back
t_done              lbsr      t_flush
                    lbsr      t_unglyph
                    tst       <kbterm
                    beq       td1
                    ldx       <base
                    leax      optsav,x
                    clra
                    clrb
                    os9       I$SetStt
                    lda       #1
                    clrb
                    os9       I$SetStt
                    lbsr      hl_done             its own colours back
                    lda       #$0C                clear the screen
                    bsr       t_ch
                    lbsr      t_flush
td1                 rts

* t_ch: A to the output buffer
t_ch                pshs      x
                    ldx       <outp
                    sta       ,x+
                    stx       <outp
                    cmpx      <oute
                    blo       tc9
                    bsr       t_flush
tc9                 puls      x,pc

* t_flush: write out the output buffer
t_flush             pshs      d,x,y
                    ldd       <outp
                    subd      <outb
                    beq       tf9
                    tfr       d,y
                    ldx       <outb
                    stx       <outp
                    lda       <scpath
                    os9       I$Write
tf9                 puls      d,x,y,pc

* t_str: X = string ending in 0
t_str               pshs      a,x
ts1                 lda       ,x+
                    beq       ts9
                    bsr       t_ch
                    bra       ts1
ts9                 puls      a,x,pc

* t_xy: move the cursor to column A, row B
t_xy                pshs      d
                    lda       #$02
                    bsr       t_ch
                    lda       ,s
                    adda      #$20
                    bsr       t_ch
                    lda       1,s
                    adda      #$20
                    bsr       t_ch
                    puls      d,pc

* t_rev, t_norm: reverse video on and off
t_rev               pshs      a
                    lda       #$1F
                    bsr       t_ch
                    lda       #$20
                    bsr       t_ch
                    puls      a,pc
t_norm              pshs      a
                    lda       #$1F
                    bsr       t_ch
                    lda       #$21
                    bsr       t_ch
                    puls      a,pc

* t_curoff, t_curon: hide and show the cursor
t_curoff            pshs      a
                    lda       #$05
                    bsr       t_ch
                    lda       #$20
                    bsr       t_ch
                    puls      a,pc
t_curon             pshs      a
                    lda       #$05
                    bsr       t_ch
                    lda       #$21
                    bsr       t_ch
                    puls      a,pc

* t_cls: clear the screen
t_cls               pshs      a
                    lda       #$0C
                    bsr       t_ch
                    puls      a,pc

* n_dec: D in decimal to X (no leading zeros); X past it
n_dec               pshs      d,y,u
                    tfr       d,u                 U = what is left
                    leay      n_dect,pcr
                    clr       ,-s                 a digit has been written
nd1                 lda       #'0-1
                    pshs      a
                    tfr       u,d
nd2                 inc       ,s
                    subd      ,y
                    bcc       nd2
                    addd      ,y
                    tfr       d,u
                    puls      a
                    cmpa      #'0
                    bne       nd3
                    tst       ,s
                    beq       nd4
nd3                 sta       ,x+
                    inc       ,s
nd4                 leay      2,y
                    ldd       ,y
                    bne       nd1
                    tfr       u,d
                    addb      #'0
                    stb       ,x+
                    leas      1,s
                    puls      d,y,u,pc
n_dect              fdb       10000,1000,100,10,0

* t_rep: B copies of A
t_rep               tstb
                    beq       tr9
tr1                 lbsr      t_ch
                    decb
                    bne       tr1
tr9                 rts

********************************************************************
* Frame glyphs.  Fonts differ, so the editor draws its own: the
* originals of characters GLYPH0.. in font set 0 are kept and put back
* on exit.  SS.FntChar takes the font set from the caller's A, which
* for I$SetStt is the path, so the calls go through path 0.  Where
* that fails (keys from a file, or no SS.FntChar) the frames are ASCII.

* t_glyph: install the glyphs; glyphs = the codes to draw them with
t_glyph             ldx       <base
                    leax      glyphs,x
                    leay      gl_asc,pcr
                    ldb       #NGL1
tg0                 lda       ,y+
                    sta       ,x+
                    decb
                    bne       tg0
                    tst       <kbterm
                    beq       tg9
                    ldx       <base               keep the originals
                    leax      fntsav,x
                    ldy       #GLYPH0
tg1                 clra
                    ldb       #SS.FntChar
                    os9       I$GetStt
                    bcs       tg9
                    leax      8,x
                    leay      1,y
                    cmpy      #GLYPH0+NGLYPH
                    blo       tg1
                    leax      gl_bits,pcr
                    ldy       #GLYPH0
tg2                 clra
                    ldb       #SS.FntChar
                    os9       I$SetStt
                    bcs       tg9
                    leax      8,x
                    leay      1,y
                    cmpy      #GLYPH0+NGLYPH
                    blo       tg2
                    inc       <glyok
                    ldx       <base
                    leax      glyphs,x
                    lda       #GLYPH0
                    ldb       #NGL1
tg3                 sta       ,x+
                    inca
                    decb
                    bne       tg3
tg9                 rts

* t_unglyph: put the original characters back
t_unglyph           tst       <glyok
                    beq       tu9
                    clr       <glyok
                    ldx       <base
                    leax      fntsav,x
                    ldy       #GLYPH0
tu1                 clra
                    ldb       #SS.FntChar
                    os9       I$SetStt
                    leax      8,x
                    leay      1,y
                    cmpy      #GLYPH0+NGLYPH
                    blo       tu1
tu9                 rts

* The glyphs, in GL.* order: double frame, single frame, single tees,
* the breakpoint mark, then the scroll bar's (SB.* order)
gl_asc              fcc       "++++=|++++-|++*"
gl_bits             fcb       $00,$00,$3F,$20,$2F,$28,$28,$28      double top left
                    fcb       $00,$00,$F8,$08,$E8,$28,$28,$28      top right
                    fcb       $28,$28,$2F,$20,$3F,$00,$00,$00      bottom left
                    fcb       $28,$28,$E8,$08,$F8,$00,$00,$00      bottom right
                    fcb       $00,$00,$FF,$00,$FF,$00,$00,$00      horizontal
                    fcb       $28,$28,$28,$28,$28,$28,$28,$28      vertical
                    fcb       $00,$00,$00,$1F,$10,$10,$10,$10      single top left
                    fcb       $00,$00,$00,$F0,$10,$10,$10,$10      top right
                    fcb       $10,$10,$10,$1F,$00,$00,$00,$00      bottom left
                    fcb       $10,$10,$10,$F0,$00,$00,$00,$00      bottom right
                    fcb       $00,$00,$00,$FF,$00,$00,$00,$00      horizontal
                    fcb       $10,$10,$10,$10,$10,$10,$10,$10      vertical
                    fcb       $10,$10,$10,$1F,$10,$10,$10,$10      left tee
                    fcb       $10,$10,$10,$F0,$10,$10,$10,$10      right tee
                    fcb       $28,$38,$7C,$7C,$7C,$38,$28,$28      breakpoint: a dot on the border
                    fcb       $00,$10,$38,$7C,$FE,$00,$00,$00      scroll bar: up arrow
                    fcb       $00,$00,$00,$FE,$7C,$38,$10,$00      down arrow
                    fcb       $22,$88,$22,$88,$22,$88,$22,$88      track
                    fcb       $00,$7C,$7C,$7C,$7C,$7C,$7C,$00      thumb
