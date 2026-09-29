********************************************************************
* hl - syntax colours
*
* v_line asks hl_cls for the colour of every character of a line, from
* the line's start (so the state is right even left of the window),
* and hl_col sends a colour change ($1B $32 <colour>, VTIO) only when
* it differs from the one in force.  Basic09 has nothing that spans
* lines, so each line starts afresh.  Rows end in the normal colour,
* so the frame, menus and dialogs never need to set it.

* Colours (the Wildbits text palette; the CoCo 3's has the same slots)
CL.NORM             equ       1                   when the terminal's are unknown
CL.KW               equ       14                  keywords
CL.FN               equ       3                   functions
CL.STR              equ       5                   strings
CL.CMT              equ       12                  comments
CL.NUM              equ       8                   numbers
KC.KW               equ       CL.KW               kwtab.asm classes
KC.FN               equ       CL.FN

HS.STR              equ       1                   hlst: in a string
HS.REM              equ       2                   in REM (to the end of the line)
HS.PCM              equ       3                   in (* ... *)
HLMAX               equ       15                  word buffer

* hl_init: the terminal's colours (SS.FBRgs): text is drawn in its
* foreground, and that is what is left on exit.  Only a terminal is
* asked (a file answers SS.FBRgs without an error).
hl_init             ldx       <base
                    lda       #CL.NORM
                    sta       hlnorm,x
                    leax      rline,x
                    lda       <scpath
                    clrb                          SS.Opt
                    os9       I$GetStt
                    bcs       hli8
                    lda       ,x                  PD.DTP
                    cmpa      #DT.SCF
                    bne       hli8
                    lda       <scpath
                    ldb       #SS.FBRgs
                    os9       I$GetStt
                    bcs       hli9
                    ifeq      coco3
                    lsra                          Wildbits: A = fg<<4 | bg
                    lsra
                    lsra
                    lsra
                    endc
                    ldx       <base
                    sta       hlnorm,x
hli8                ldx       <base
hli9                lda       hlnorm,x
                    sta       <hlout
                    rts

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
                    lbsr      hl_peek
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
kw_find             pshs      x,y,u
                    pshs      b                   ,s: the length
                    cmpb      #2
                    blo       kwf_no
                    cmpb      #12
                    bhi       kwf_no
                    ldx       <base
                    leax      hlbuf,x
                    lda       ,x+
                    suba      #'A
                    cmpa      #25
                    bhi       kwf_no
                    lsla
                    leay      kwidx,pcr
                    ldd       a,y
                    leay      kwtab,pcr
                    leay      d,y
kwf1                leau      ,y                  U = the entry: its class, then the
                    lda       ,y+                 rest of its name
                    beq       kwf_no
                    clra
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
                    cmpa      ,s
                    bne       kwf1
                    ldb       ,u
                    leas      1,s
                    puls      x,y,u,pc
kwf3                tstb                          skip the rest of this entry
                    bmi       kwf1
kwf4                ldb       ,y+
                    bpl       kwf4
                    bra       kwf1
kwf_no              clrb
                    leas      1,s
                    puls      x,y,u,pc

* c_colour: syntax colours on or off (Options)
c_colour            com       <nocolr
                    lda       #RD.ALL
                    ora       <redraw
                    sta       <redraw
                    leax      colon,pcr
                    tst       <nocolr
                    beq       ccl1
                    leax      coloff,pcr
ccl1                stx       <msgp
                    rts
colon               fcn       "Syntax colours on"
coloff              fcn       "Syntax colours off"

                    use       kwtab.asm
