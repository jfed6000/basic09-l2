********************************************************************
* hl - syntax colours
*
* v_line asks hl_cls for the colour of every character of a line, from
* the line's start (so the state is right even left of the window),
* and hl_col sends a colour change ($1B $32 <colour>, VTIO) only when
* it differs from the one in force.  Basic09 has nothing that spans
* lines, so each line starts afresh.  Rows end in the normal colour,
* so the frame, menus and dialogs never need to set it.

* The editor's own colours, as Turbo C had its own (the Wildbits text
* palette; the CoCo 3's has the same slots).  With colours off the
* terminal's own are used.  $0A and $0D are avoided as colour numbers.
CL.BG               equ       6                   background: blue (#000050 on Wildbits: hl_pal)
CL.NORM             equ       7                   text: yellow (#E6D67A)
CL.KW               equ       1                   keywords: white
CL.FN               equ       3                   functions: pale cyan
CL.STR              equ       5                   strings: green
CL.CMT              equ       15                  comments: light grey
CL.NUM              equ       8                   numbers: orange
CL.FRAME            equ       1                   window frames: white
CL.MBFG             equ       0                   menu bar: black
CL.MBBG             equ       15                  on light grey,
CL.MSBG             equ       5                   the open menu's title on green
CL.SELFG            equ       0                   the selection: black
CL.SELBG            equ       3                   on pale cyan
CL.EXFG             equ       1                   the line the program stopped at:
CL.EXBG             equ       2                   white on red
KC.KW               equ       CL.KW               kwtab.asm classes
KC.FN               equ       CL.FN

HS.STR              equ       1                   hlst: in a string
HS.REM              equ       2                   in REM (to the end of the line)
HS.PCM              equ       3                   in (* ... *)
HLMAX               equ       15                  word buffer

* hl_init: note the terminal's colours (SS.FBRgs, asked only of a
* terminal: a file answers without an error), then set ours
hl_init             ldx       <base
                    clr       hlok,x
                    leax      rline,x
                    lda       <scpath
                    clrb                          SS.Opt
                    os9       I$GetStt
                    bcs       hl_set
                    lda       ,x                  PD.DTP
                    cmpa      #DT.SCF
                    bne       hl_set
                    lda       <scpath
                    ldb       #SS.FBRgs
                    os9       I$GetStt
                    bcs       hl_set
                    ifeq      coco3
                    tfr       a,b                 Wildbits: A = fg<<4 | bg
                    lsra
                    lsra
                    lsra
                    lsra
                    andb      #$0F
                    endc
                    ldx       <base
                    sta       hlsfg,x
                    stb       hlsbg,x
                    inc       hlok,x
                    ifeq      coco3
                    leax      pal_ed,pcr          a dark blue, a softer yellow
                    lbsr      hl_pal
                    endc
* hl_set: the colours to draw with: ours, or the terminal's with colours
* off (then nothing changes if they are not known)
hl_set              ldx       <base
                    lda       #CL.NORM
                    ldb       #CL.BG
                    tst       <nocolr
                    beq       hls1
                    tst       hlok,x
                    beq       hls9
                    lda       hlsfg,x
                    ldb       hlsbg,x
hls1                sta       hlnorm,x
                    bsr       hl_pair
hls9                lda       hlnorm,x
                    sta       <hlout
                    rts

* hl_pair: foreground A, background B, now
hl_pair             pshs      d
                    sta       <hlout
                    lda       #$1B
                    lbsr      t_ch
                    lda       #$33
                    lbsr      t_ch
                    lda       1,s
                    lbsr      t_ch
                    lda       #$1B
                    lbsr      t_ch
                    lda       #$32
                    lbsr      t_ch
                    lda       ,s
                    lbsr      t_ch
                    puls      d,pc

* fr_on: window frames in white, as in Turbo C (nothing with colours
* off); hl_norm goes back.  Keeps all registers.
fr_on               tst       <nocolr
                    bne       fro9
                    pshs      b
                    ldb       #CL.FRAME
                    lbsr      hl_col
                    puls      b
fro9                rts

* mb_on, mb_sel, mb_off: the menu bar grey, as in Turbo C (the open
* menu's title green), then back to the text's colours.  With colours
* off, reverse video as before.  They keep all registers.
mb_on               tst       <nocolr
                    lbne      t_rev
                    pshs      d
                    ldd       #CL.MBFG*256+CL.MBBG
mb1                 bsr       hl_pair
                    puls      d,pc
mb_sel              tst       <nocolr
                    lbne      t_norm
                    pshs      d
                    ldd       #CL.MBFG*256+CL.MSBG
                    bra       mb1
mb_off              tst       <nocolr
                    lbne      t_norm
                    pshs      d,x
                    ldx       <base
                    lda       hlnorm,x
                    ldb       #CL.BG
                    bsr       hl_pair
                    puls      d,x,pc

* mi_on, mi_sel, mi_end: a drop-down menu grey, its selected item
* green; with colours off only the selected item shows, in reverse
* video.  They keep all registers.
mi_on               tst       <nocolr
                    beq       mb_on
                    rts
mi_sel              tst       <nocolr
                    beq       mb_sel
                    lbra      t_rev
mi_end              tst       <nocolr
                    beq       mb_on
                    lbra      t_norm

* hl_done: the terminal's own colours back (before the screen is
* cleared on exit)
hl_done             ldx       <base
                    tst       hlok,x
                    beq       hld9
                    ifeq      coco3
                    leax      pal_def,pcr         the palette's own entries back
                    bsr       hl_pal
                    ldx       <base
                    endc
                    lda       hlsfg,x
                    ldb       hlsbg,x
                    lbra      hl_pair
hld9                rts

                    ifeq      coco3
* hl_pal: send the two palette changes at X (VTIO $1B $61 / $1B $60
* <slot> <red> <green> <blue> <alpha>).  The text palette is the
* screen's, not the terminal's, and cannot be read back, so hl_done
* puts back the defaults (the palette module's), not what was there.
hl_pal              ldb       #14
hpl1                lda       ,x+
                    lbsr      t_ch
                    decb
                    bne       hpl1
                    rts
pal_ed              fcb       $1B,$61,CL.BG,$00,$00,$50,$00     background #000050
                    fcb       $1B,$60,CL.NORM,$E6,$D6,$7A,$00   text #E6D67A
pal_def             fcb       $1B,$61,CL.BG,$00,$00,$AA,$00     the defaults
                    fcb       $1B,$60,CL.NORM,$DD,$DD,$77,$00
                    endc

* hl_norm: back to the normal colour
hl_norm             pshs      b,x
                    ldx       <base
                    ldb       hlnorm,x
                    bsr       hl_col
                    puls      b,x,pc

* hl_col: colour B from here on
hl_col              cmpb      <hlout
                    beq       hco9
                    stb       <hlout
                    pshs      a
                    lda       #$1B
                    lbsr      t_ch
                    lda       #$32
                    lbsr      t_ch
                    tfr       b,a
                    lbsr      t_ch
                    puls      a
hco9                rts

* hl_cls: B = the colour of character A at position U.  Called for
* every character of a line in order; hlst/hlrun carry the state.
hl_cls              pshs      a,x,y,u
                    tst       <hlrun              inside a word, number or "*)"
                    beq       hc1
                    dec       <hlrun
                    ldb       <hlcur
                    puls      a,x,y,u,pc
hc1                 ldb       <hlst
                    beq       hc_n
                    cmpb      #HS.STR
                    bne       hc2
                    cmpa      #'"
                    bne       hc_str
                    clr       <hlst               the closing quote
hc_str              ldb       #CL.STR
                    puls      a,x,y,u,pc
hc2                 cmpb      #HS.PCM
                    bne       hc_cmt
                    cmpa      #'*
                    bne       hc_cmt
                    lbsr      hl_peek
                    cmpa      #')
                    bne       hc_cmt
                    clr       <hlst               "*)": the ")" is a comment too
                    lda       #1
                    bra       hc_run
hc_cmt              ldb       #CL.CMT
                    puls      a,x,y,u,pc
hc_n                cmpa      #'"
                    bne       hc3
                    lda       #HS.STR
                    sta       <hlst
                    bra       hc_str
hc3                 cmpa      #'(
                    bne       hc4
                    lbsr      hl_peek
                    cmpa      #'*
                    bne       hc_norm
                    lda       #HS.PCM
                    sta       <hlst
                    lda       #1                  the "*"
hc_run              sta       <hlrun
                    ldb       #CL.CMT
                    stb       <hlcur
                    puls      a,x,y,u,pc
hc4                 cmpa      #'$                 a number: $hex, digits, .digits
                    beq       hc_num
                    cmpa      #'.
                    bne       hc5
                    bsr       hl_peek
                    cmpa      #'0
                    blo       hc_norm
                    cmpa      #'9
                    bhi       hc_norm
                    lda       #'.
                    bra       hc_num
hc5                 cmpa      #'0
                    blo       hc_norm
                    cmpa      #'9
                    bls       hc_num
                    lbsr      is_word             a word (letters, digits, _)
                    bcs       hc_word
hc_norm             ldx       <base
                    ldb       hlnorm,x
                    puls      a,x,y,u,pc
hc_num              lbsr      hl_num
                    decb
                    stb       <hlrun
                    ldb       #CL.NUM
                    stb       <hlcur
                    puls      a,x,y,u,pc
hc_word             lbsr      hl_word
                    pshs      b
                    decb
                    stb       <hlrun
                    ldb       ,s+
                    lbsr      kw_find
                    tstb
                    bne       hcw1
                    ldx       <base               not a keyword
                    ldb       hlnorm,x
hcw1                stb       <hlcur
                    cmpb      #CL.KW              REM: the rest of the line
                    bne       hcw9
                    ldx       <base
                    ldd       hlbuf,x
                    cmpd      #'R*256+'E
                    bne       hcw8
                    ldd       hlbuf+2,x
                    cmpd      #'M*256
                    bne       hcw8
                    lda       #HS.REM
                    sta       <hlst
                    clr       <hlrun
                    ldb       #CL.CMT
                    puls      a,x,y,u,pc
hcw8                ldb       <hlcur
hcw9                puls      a,x,y,u,pc

* hl_peek: A = the character after position U (a CR at the end)
hl_peek             pshs      x,u
                    bsr       hl_cpy
                    lbsr      p_next
                    bcs       hlp1
                    lbsr      p_char
                    bcc       hlp9
hlp1                lda       #C$CR
hlp9                puls      x,u,pc

* hl_cpy: hp = position U; U = hp
hl_cpy              ldx       <base
                    ldd       ,u
                    std       hp,x
                    ldd       2,u
                    std       hp+2,x
                    leau      hp,x
                    rts

* hl_num: B = the length of the number starting with A at U
hl_num              pshs      a,x,u
                    bsr       hl_cpy
                    clr       ,-s                 1: hexadecimal
                    lda       1,s
                    cmpa      #'$
                    bne       hn0
                    inc       ,s
hn0                 ldb       #1
hn1                 lbsr      p_next
                    bcs       hn9
                    lbsr      p_char
                    bcs       hn9
                    cmpa      #'.
                    beq       hn_ok
                    cmpa      #'0
                    blo       hn9
                    cmpa      #'9
                    bls       hn_ok
                    anda      #$DF
                    tst       ,s
                    beq       hn2
                    cmpa      #'A
                    blo       hn9
                    cmpa      #'F
                    bhi       hn9
                    bra       hn_ok
hn2                 cmpa      #'E                 an exponent
                    bne       hn9
hn_ok               incb
                    bne       hn1
                    decb
hn9                 leas      1,s
                    puls      a,x,u,pc

* hl_word: the word at U (upper case, at most HLMAX, ending in 0) to
* hlbuf; B = its full length.  A "$" ends it and is part of it.
hl_word             pshs      a,x,y,u
                    bsr       hl_cpy
                    leay      hlbuf,x
                    clrb
hlw1                lbsr      p_char
                    bcs       hlw9
                    cmpa      #'$
                    beq       hlw2
                    lbsr      is_word
                    bcc       hlw9
                    cmpa      #'a
                    blo       hlw2
                    cmpa      #'z
                    bhi       hlw2
                    suba      #$20
hlw2                cmpb      #HLMAX
                    bhs       hlw3
                    sta       b,y
hlw3                incb
                    beq       hlw8                (255 at most)
                    cmpa      #'$
                    beq       hlw9
                    lbsr      p_next
                    bcc       hlw1
                    bra       hlw9
hlw8                decb
hlw9                cmpb      #HLMAX
                    bhs       hlw10
                    clr       b,y
hlw10               puls      a,x,y,u,pc

* kw_find: B = the class (colour) of the word in hlbuf of length B, or
* 0 if it is not a keyword
kw_find             lda       #KC.KW              the keywords come first
                    pshs      d,x,y               ,s: the class; 1,s: the length
                    cmpb      #2
                    blo       kwf_no
                    cmpb      #12
                    bhi       kwf_no
                    ldx       <base
                    leax      hlbuf,x
                    lda       ,x+
                    suba      #'A
                    cmpa      #KWLAST-'A
                    bhi       kwf_no
                    lsla
                    leay      kwidx,pcr
                    ldd       a,y
                    leay      kwtab,pcr
                    leay      d,y
kwf1                tst       ,y                  the end of a list?
                    bne       kwf1a
                    leay      1,y
                    lda       ,s
                    cmpa      #KC.FN
                    beq       kwf_no              ..of the functions
                    lda       #KC.FN              the functions follow
                    sta       ,s
                    bra       kwf1
kwf1a               clra                          Y = the rest of a name
kwf2                ldb       ,y+
                    pshs      b
                    andb      #$7F
                    cmpb      a,x
                    puls      b
                    bne       kwf3
                    inca
                    tstb
                    bpl       kwf2
                    inca                          the whole name matched: as long?
                    cmpa      1,s
                    bne       kwf1
                    ldb       ,s
                    leas      2,s
                    puls      x,y,pc
kwf3                tstb                          skip the rest of this entry
                    bmi       kwf1
kwf4                ldb       ,y+
                    bpl       kwf4
                    bra       kwf1
kwf_no              clrb
                    leas      2,s
                    puls      x,y,pc

* c_kwcase: pretty print writes keywords in lower case (the default) or
* in capitals (Options)
c_kwcase            ldx       <base
                    com       kwup,x
                    leax      kwlom,pcr
                    ldy       <base
                    tst       kwup,y
                    beq       ckc1
                    leax      kwupm,pcr
ckc1                stx       <msgp
                    rts
kwlom               fcn       "Pretty print: keywords in lower case"
kwupm               fcn       "Pretty print: keywords in capitals"

* c_colour: syntax colours on or off (Options); the screen is cleared
* in the new background
c_colour            com       <nocolr
                    lbsr      hl_set
                    lbsr      t_cls
                    lbsr      rd_all
                    leax      colon,pcr
                    tst       <nocolr
                    beq       ccl1
                    leax      coloff,pcr
ccl1                stx       <msgp
                    rts
colon               fcn       "Syntax colours on"
coloff              fcn       "Syntax colours off"

                    use       kwtab.asm
