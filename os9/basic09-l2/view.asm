********************************************************************
* view - the text window and the status line

* v_fix: work out the cursor column and scroll so the cursor shows
v_fix               lbsr      a_cpos
                    lbsr      p_col
                    std       <curcol
                    tst       <setwant
                    beq       vf0
                    std       <wantcol
vf0                 ldd       <curline            above the window?
                    cmpd      <topline
                    bhs       vf1
                    std       <topline
                    ldd       <cpos
                    std       <tpos
                    ldd       <cpos+2
                    std       <tpos+2
                    ldu       <base
                    leau      tpos,u
                    lbsr      p_bol
                    bra       vf2b
vf1                 subd      <topline            below it?
                    tsta
                    bne       vf2
                    cmpb      <wrows
                    blo       vf3
vf2                 ldd       <cpos               top line = wrows-1 lines above the cursor
                    std       <tpos
                    ldd       <cpos+2
                    std       <tpos+2
                    ldu       <base
                    leau      tpos,u
                    lbsr      p_bol
                    ldb       <wrows
                    decb
                    beq       vf2a
vf2c                lbsr      p_prevln
                    decb
                    bne       vf2c
vf2a                clra
                    ldb       <wrows
                    decb
                    std       <tmp
                    ldd       <curline
                    subd      <tmp
                    std       <topline
vf2b                lda       <redraw             (a scroll: the text only)
                    ora       #RD.TEXT
                    sta       <redraw
vf3                 ldd       <curcol             left of the window?
                    cmpd      <leftcol
                    bhs       vf4
                    subd      #TABW
                    bcc       vf3a
                    ldd       #0
vf3a                std       <leftcol
                    bra       vf5
vf4                 ldd       <leftcol            right of it?
                    addb      <wcols
                    adca      #0
                    cmpd      <curcol
                    bhi       vf9
                    ldd       <curcol
                    subb      <wcols
                    sbca      #0
                    addd      #TABW
                    std       <leftcol
vf5                 lda       <redraw
                    ora       #RD.TEXT
                    sta       <redraw
vf9                 rts

* v_center: put the cursor line in the middle of the window (after a
* jump, when the lines above the window may have changed)
v_center            ldd       <cpos
                    std       <tpos
                    ldd       <cpos+2
                    std       <tpos+2
                    ldd       <curline
                    std       <topline
                    ldu       <base
                    leau      tpos,u
                    lbsr      p_bol
                    ldb       <wrows
                    lsrb
                    beq       vc9
vc1                 ldx       <topline
                    beq       vc9
                    lbsr      p_prevln
                    leax      -1,x
                    stx       <topline
                    decb
                    bne       vc1
vc9                 lbra      rd_text

* v_draw: redraw what the flags ask for, the status line and the cursor
v_draw              lbsr      t_curoff
                    lda       <redraw
                    bita      #RD.ALL+RD.TEXT+RD.BELOW lines may have moved
                    beq       vd00
                    lbsr      bp_lines
vd00                equ       *
                    tst       <selon
                    beq       vd0
                    lbsr      sel_bounds
vd0                 lda       <redraw             (bp_lines and sel_bounds use A)
                    bita      #RD.ALL+RD.TEXT
                    beq       vd1
                    bita      #RD.ALL             a scroll leaves the frame alone
                    beq       vd0w
                    lbsr      v_frame
                    ldx       <base               (a partial redraw is above them)
                    tst       rdlim,x
                    bne       vd0a
vd0x                lbsr      w_draw
                    bra       vd0a
vd0w                bita      #RD.WIN             a stop: the watch window too
                    bne       vd0x
vd0a                equ       *
                    ldd       <tpos
                    std       <wp
                    ldd       <tpos+2
                    std       <wp+2
                    clrb
                    bsr       v_rows
                    bra       vd3
vd1                 bita      #RD.BELOW+RD.LINE
                    beq       vd3
                    lbsr      cp_wp
                    ldu       <base
                    leau      wp,u
                    lbsr      p_bol
                    ldd       <curline
                    subd      <topline
                    lda       <redraw
                    bita      #RD.BELOW
                    beq       vd2
                    bita      #RD.PREV            the line above changed too (Enter)
                    beq       vd1b
                    tstb
                    beq       vd1b
                    decb
                    lbsr      p_prevln            (U = wp)
vd1b                bsr       v_rows
                    bra       vd3
vd2                 lbsr      v_line
vd3                 lbsr      sb_upd
                    lbsr      v_stat
                    clr       <redraw
                    ldd       <curline
                    subd      <topline
                    addb      <wtop
                    pshs      b
                    ldd       <curcol
                    subd      <leftcol
                    addb      <wleft
                    tfr       b,a
                    puls      b
                    lbsr      t_xy
                    lbsr      t_curon
                    lbra      t_flush

* v_rows: draw window rows B to the bottom (or to rdlim), starting with
* the line at wp
v_rows              pshs      b
                    bsr       v_lim
                    pshs      a                   ,s = the row to stop at
vr1                 ldb       1,s
                    cmpb      ,s
                    bhs       vr9
                    bsr       v_line
                    inc       1,s
                    bcc       vr1
vr2                 ldb       1,s                 the text ended: blank rows
                    cmpb      ,s
                    bhs       vr9
                    bsr       v_blank
                    inc       1,s
                    bra       vr2
vr9                 leas      1,s
                    puls      b,pc

* v_lim: A = the window rows to redraw: rdlim, or all of them
v_lim               ldx       <base
                    lda       rdlim,x
                    beq       vlm1
                    cmpa      <wrows
                    bls       vlm9
vlm1                lda       <wrows
vlm9                rts

* v_blank: clear window row B
v_blank             pshs      d
                    lda       <wleft
                    addb      <wtop
                    lbsr      t_xy
                    clr       <vcnt
                    bsr       v_pad
                    puls      d,pc

* v_pad: spaces to the right edge of the window
v_pad               pshs      a
vp1                 lda       <vcnt
                    cmpa      <wcols
                    bhs       vp9
                    lda       #C$SPAC
                    bsr       v_put
                    bra       vp1
vp9                 puls      a,pc

* v_colput: v_put, in colour B unless colours are off or the character
* is highlighted (the highlight has colours of its own)
v_colput            bsr       v_synok
                    bne       v_put
                    lbsr      hl_col
                    bra       v_put

* v_synok: Z if syntax colours apply here (colours on, no highlight)
v_synok             tst       <nocolr
                    bne       vsy9
                    tst       <vrev
vsy9                rts

* v_put: A into the current window row, if it still has room
v_put               pshs      a
                    lda       <vcnt
                    cmpa      <wcols
                    bhs       vpt9
                    inc       <vcnt
                    lda       ,s
                    cmpa      #C$SPAC
                    blo       vpt1
                    cmpa      #$7F
                    blo       vpt2
vpt1                lda       #'.                 control characters show as dots
vpt2                lbsr      t_ch
vpt9                puls      a,pc

* v_line: draw window row B from the line at wp; wp moves to the next
* line.  Carry if the text ended in this line.
v_line              pshs      d,x,y,u
                    clra
                    addd      <topline
                    std       <vline
                    ldb       1,s
                    lda       <wleft              the left border: the frame, or a
                    deca                          breakpoint mark
                    addb      <wtop
                    lbsr      t_xy
                    lbsr      fr_on
                    lda       <glyphs+GL.V2
                    ldx       <vline
                    exg       d,x
                    lbsr      bp_on
                    exg       d,x
                    bcc       vl00
                    lda       <glyphs+GL.BP
vl00                lbsr      t_ch
                    clr       <vcnt
                    clr       <vrev
                    clr       <vexec              the line the program stopped at?
                    clr       <vstat
                    tst       <dbgon
                    beq       vl0
                    ldd       <vline
                    cmpd      <dbfl
                    bne       vl0
                    lbsr      vs_init             only its statement dbstm is red
vl0                 clr       <hlst               syntax colours start afresh
                    clr       <hlrun
                    ldu       <base
                    leau      wp,u
                    ldx       #0                  display column
vl1                 lbsr      p_char
                    bcs       vl_eof
                    cmpa      #C$CR
                    beq       vl_eol
                    tst       <vstat              the stopped line: which statement?
                    beq       vl1v
                    lbsr      vs_char
vl1v                tst       <nocolr
                    bne       vl1a
                    lbsr      hl_cls              B = its colour
vl1a                cmpa      #C$TAB
                    beq       vl_tab
                    cmpx      <leftcol
                    blo       vl2
                    bsr       v_selat
                    lbsr      v_colput
vl2                 leax      1,x
                    bra       vl3
vl_tab              lbsr      v_selat
                    lbsr      v_synok
                    bne       vlt0
                    lbsr      hl_col
vlt0                equ       *
                    tfr       x,y
                    lbsr      col_adv
                    pshs      x
vlt1                cmpy      <leftcol
                    blo       vlt2
                    lda       #C$SPAC
                    lbsr      v_put
vlt2                leay      1,y
                    cmpy      ,s
                    blo       vlt1
                    leas      2,s
vl3                 lbsr      p_next
                    lda       <vcnt               row full: skip the rest of the line
                    cmpa      <wcols
                    blo       vl1
                    lbsr      p_eol
                    bcs       vl_eof
vl_eol              cmpx      <leftcol            a selected line end shows as a space
                    blo       vle1
                    bsr       v_selat
                    tst       <vrev
                    beq       vle1
                    lda       #C$SPAC
                    lbsr      v_put
vle1                bsr       v_endpad
                    lbsr      p_next
                    andcc     #^Carry
                    puls      d,x,y,u,pc
vl_eof              bsr       v_endpad
                    orcc      #Carry
                    puls      d,x,y,u,pc

* v_endpad: the rest of the row: highlighted on the line the program
* stopped at, otherwise in the normal colours
v_endpad            clra
                    tst       <vexec
                    beq       vep1
                    lda       #VH.EXEC
vep1                bsr       v_hi
                    lbsr      v_synok
                    bne       vep2
                    lbsr      hl_norm
vep2                lbsr      v_pad
                    bra       v_selend

* v_selat: the highlight for display column X of line vline: the
* selection's, the stopped line's, or none
v_selat             pshs      d
                    clra
                    tst       <selon
                    beq       vsa_out
                    ldd       <vline              before the start?
                    cmpd      <sl
                    blo       vsa_out
                    bne       vsa1
                    cmpx      <sc
                    blo       vsa_out
vsa1                ldd       <vline              at or after the end?
                    cmpd      <el
                    bhi       vsa_out
                    bne       vsa_in
                    cmpx      <ec
                    bhs       vsa_out
vsa_in              lda       #VH.SEL
                    bra       vsa2
vsa_out             clra
                    tst       <vexec
                    beq       vsa2
                    lda       #VH.EXEC
vsa2                bsr       v_hi
                    puls      d,pc

* v_selend: the highlight off
v_selend            clra

* v_hi: highlight A (VH.*) from here on.  With colours it is a colour
* pair; without them reverse video, the selection the other way round
* on the stopped line.  Keeps all registers.
VH.SEL              equ       1
VH.EXEC             equ       2
v_hi                cmpa      <vrev
                    beq       vhi9
                    sta       <vrev
                    pshs      d,x
                    tst       <nocolr
                    bne       vhi4
                    ldx       <base
                    tsta
                    bne       vhi1
                    lda       hlnorm,x            none: the normal colours
                    ldb       #CL.BG
                    bra       vhi3
vhi1                cmpa      #VH.SEL
                    bne       vhi2
                    ldd       #CL.SELFG*256+CL.SELBG
                    bra       vhi3
vhi2                ldd       #CL.EXFG*256+CL.EXBG
vhi3                lbsr      hl_pair
                    puls      d,x,pc
vhi4                clrb                          reverse: (selected) xor (stopped line)
                    cmpa      #VH.SEL
                    bne       vhi5
                    incb
vhi5                eorb      <vexec
                    beq       vhi6
                    lbsr      t_rev
                    puls      d,x,pc
vhi6                lbsr      t_norm
                    puls      d,x,pc
vhi9                rts

* v_stat: the bottom border (modified mark, line:column) and the hint line
v_stat              ldb       <wtop               bottom border
                    addb      <wrows
                    clra
                    lbsr      t_xy
                    lbsr      fr_on
                    lda       <glyphs+GL.BL2
                    lbsr      t_ch
                    lda       <glyphs+GL.H2
                    tst       <modif
                    beq       vs1
                    lda       #'*
vs1                 lbsr      t_ch
                    lda       <glyphs+GL.H2
                    lbsr      t_ch
                    lbsr      a_sbuf
                    lda       #C$SPAC
                    sta       ,x+
                    ldd       <curline
                    addd      #1
                    lbsr      n_dec
                    lda       #':
                    sta       ,x+
                    ldd       <curcol
                    addd      #1
                    lbsr      n_dec
                    lda       #C$SPAC
                    sta       ,x+
                    clr       ,x
                    tfr       x,d
                    subd      <base
                    subd      #sbuf
                    addb      #4                  columns used so far, and the corner
                    pshs      b
                    lbsr      a_sbuf
                    lbsr      t_str
                    ldb       <scrw
                    subb      ,s+
                    lda       <glyphs+GL.H2
                    lbsr      t_rep
                    lda       <glyphs+GL.BR2
                    lbsr      t_ch
                    lbsr      hl_norm
* v_hint: the last row: a message, an error, or the key hints
v_hint              lbsr      a_sbuf
                    lda       #C$SPAC
                    sta       ,x+
                    ldy       <msgp
                    bne       vh_msg
                    tst       <msgerr
                    bne       vh_err
                    leay      hintms,pcr
                    tst       <dbgon
                    beq       vh_msg
                    leay      dbghint,pcr
vh_msg              bsr       s_str
                    bra       vs_out
vh_err              leay      errmsg,pcr
                    bsr       s_str
                    clra
                    ldb       <msgerr
                    lbsr      n_dec
* vs_out: sbuf (up to X) on the last row: grey like the menu bar, or
* in reverse video with colours off
vs_out              clr       ,x
                    ldb       <scrh
                    decb
                    clra
                    lbsr      t_xy
                    lbsr      mb_on
                    lbsr      a_sbuf
                    ldb       <scrw               all but the last column (no scroll)
                    decb
vs3                 lda       ,x
                    beq       vs4
                    leax      1,x
                    bra       vs5
vs4                 lda       #C$SPAC
vs5                 lbsr      t_ch
                    decb
                    bne       vs3
                    lbra      mb_off

* s_str: copy the string at Y (ending in 0) to X
s_str               lda       ,y+
                    beq       ss9
                    sta       ,x+
                    bra       s_str
ss9                 rts

* v_frame: menu bar, the top border with the file name, the side borders
v_frame             lda       #$FF
                    ldx       <base               the scroll bar too
                    sta       sbpos,x
                    lbsr      v_menubar
                    lbsr      fr_on               frames in white
                    clra                          top border
                    ldb       #1
                    lbsr      t_xy
                    lda       <glyphs+GL.TL2
                    lbsr      t_ch
                    ldy       <base               title: " name "
                    leay      fname,y
                    tst       ,y
                    bne       vfr1
                    leay      untitl,pcr
vfr1                lbsr      a_sbuf
                    lda       #C$SPAC
                    sta       ,x+
                    bsr       s_str
                    lda       #C$SPAC
                    sta       ,x+
                    clr       ,x
                    tfr       x,d
                    subd      <base
                    subd      #sbuf
                    pshs      b                   title length
                    ldb       <scrw
                    subb      #2
                    subb      ,s
                    lsrb                          border on the left of it
                    pshs      b
                    lda       <glyphs+GL.H2
                    lbsr      t_rep
                    lbsr      a_sbuf
                    lbsr      t_str
                    ldb       <scrw               the rest of the border
                    subb      #2
                    subb      ,s+
                    subb      ,s+
                    lda       <glyphs+GL.H2
                    lbsr      t_rep
                    lda       <glyphs+GL.TR2
                    lbsr      t_ch
                    ldb       <wtop               side borders
vfr2                clra
                    lbsr      t_xy
                    lda       <glyphs+GL.V2
                    lbsr      t_ch
                    lda       <scrw
                    deca
                    lbsr      t_xy
                    lda       <glyphs+GL.V2
                    lbsr      t_ch
                    incb
                    lda       <wtop
                    adda      <wrows
                    pshs      a
                    cmpb      ,s+
                    blo       vfr2
                    bsr       v_gaps
                    lbra      hl_norm

* v_menubar: the menu titles on row 0; menu A (or none if $FF) is shown
* selected
v_menubar           pshs      a
                    clra
                    clrb
                    lbsr      t_xy
                    lbsr      mb_on
                    lda       #C$SPAC
                    lbsr      t_ch
                    ldb       #1                  columns written
                    leax      mtitle,pcr
                    clra                          menu number
vmb1                tst       ,x
                    beq       vmb5
                    cmpa      ,s
                    bne       vmb2
                    lbsr      mb_sel
vmb2                pshs      a
                    lda       #C$SPAC
                    lbsr      t_ch
                    incb
vmb3                lda       ,x+
                    beq       vmb4
                    lbsr      t_ch
                    incb
                    bra       vmb3
vmb4                lda       #C$SPAC
                    lbsr      t_ch
                    incb
                    puls      a
                    cmpa      ,s
                    bne       vmb4a
                    lbsr      mb_on
vmb4a               inca
                    bra       vmb1
vmb5                pshs      b
                    ldb       <scrw
                    subb      ,s+
                    lda       #C$SPAC
                    lbsr      t_rep
                    tst       <dblsp              double spacing: the gap under it
                    beq       vmb6                grey too
                    clra
                    clrb
                    lbsr      t_xyg
                    lda       #C$SPAC
                    ldb       <scrw
                    lbsr      t_rep
vmb6                lbsr      mb_off
                    puls      a,pc

* v_gaps: with double spacing, the gap rows from under the top border to
* under the last text row: the side borders, and spaces between them if
* a box was drawn over them (gapdty)
v_gaps              tst       <dblsp
                    beq       vgp9
                    ldb       <wtop
                    decb
                    pshs      b
vgp1                clra
                    ldb       ,s
                    lbsr      t_xyg
                    lda       <glyphs+GL.V2
                    lbsr      t_ch
                    ldx       <base
                    tst       gapdty,x
                    beq       vgp2
                    lda       #C$SPAC
                    ldb       <wcols
                    lbsr      t_rep
                    bra       vgp3
vgp2                lda       <scrw
                    deca
                    ldb       ,s
                    lbsr      t_xyg
vgp3                lda       <glyphs+GL.V2
                    lbsr      t_ch
                    inc       ,s
                    lbsr      v_lim
                    tfr       a,b
                    addb      <wtop
                    cmpb      ,s
                    bhi       vgp1
                    leas      1,s
                    ldx       <base
                    clr       gapdty,x
vgp9                rts

untitl              fcc       "(untitled)"
                    fcb       0
errmsg              fcc       "Error #"
                    fcb       0
hintms              fcc       "F1 Help  ^S Save  ^O Open  ^G Go to  ^B Make  ^R Run  Alt+letter Menus"
                    fcb       0
dbghint             fcc       "Stopped:  F7 Step  F8 Over  ^R Continue  ^P Reset  ^E Evaluate  ^W Watch"
                    fcb       0

* The line the program stopped at: only the statement it stopped at
* (dbstm, from %DEBUG's third number) is drawn red.  vs_char follows
* the line a character at a time: a "\" outside strings starts the
* next statement (it is part of it); a statement that starts with
* REM, "(*" or "!" is a comment to the end of the line, as the compiler
* has it.
VS.EXL              equ       $01                 this is the stopped line
VS.INQ              equ       $02                 in a string
VS.COM              equ       $04                 in a comment, to the end
VS.ST               equ       $08                 at a statement's start (spaces, line number)
VS.REM              equ       $30                 REM so far: $10 R, $20 RE, $30 REM
* vs_init: start the stopped line (vexec: its first statement?)
vs_init             pshs      x
                    lda       #VS.EXL+VS.ST
                    sta       <vstat
                    ldx       <base
                    clr       vseg,x
                    clr       vlast,x
                    clr       <vexec
                    tst       <dbstm
                    bne       vsi9
                    inc       <vexec
vsi9                puls      x,pc
* vs_char: character A of the stopped line; keeps all registers
vs_char             pshs      d,x
                    ldx       <base
                    ldb       <vstat
                    bitb      #VS.COM
                    lbne      vsc9
                    bitb      #VS.INQ
                    beq       vsc1
                    cmpa      #'"
                    lbne      vsc9
                    andb      #^VS.INQ            the string ends
                    lbra      vsc8
vsc1                pshs      b                   "REM" and then?
                    andb      #VS.REM
                    cmpb      #VS.REM
                    puls      b
                    bne       vsc2
                    andb      #^(VS.REM+VS.ST)
                    lbsr      vs_word             a name goes on: not REM
                    bcc       vsc2
                    orb       #VS.COM
                    bra       vsc8
vsc2                cmpa      #'"
                    bne       vsc3
                    orb       #VS.INQ
                    andb      #^(VS.ST+VS.REM)
                    bra       vsc8
vsc3                cmpa      #'\
                    bne       vsc4
                    inc       vseg,x              the next statement
                    lda       vseg,x
                    clr       <vexec
                    cmpa      <dbstm
                    bne       vsc3a
                    inc       <vexec
vsc3a               andb      #^VS.REM
                    orb       #VS.ST
                    bra       vsc8
vsc4                cmpa      #'!                "!": a comment too
                    beq       vsc4c
                    cmpa      #'*
                    bne       vsc5
                    lda       vlast,x
                    cmpa      #'(
                    bne       vsc7
vsc4c               orb       #VS.COM             "(*" or "!"
                    bra       vsc8
vsc5                bitb      #VS.ST
                    beq       vsc8
                    cmpa      #C$SPAC             spaces and a line number keep it
                    beq       vsc8
                    cmpa      #'0
                    blo       vsc6
                    cmpa      #'9
                    bhi       vsc6
                    bitb      #VS.REM
                    beq       vsc8
vsc6                anda      #$DF                upper case
                    pshs      b
                    andb      #VS.REM
                    cmpb      #$00
                    bne       vsc6a
                    cmpa      #'R
                    beq       vsc6r
                    bra       vsc6n
vsc6a               cmpb      #$10
                    bne       vsc6b
                    cmpa      #'E
                    beq       vsc6r
                    bra       vsc6n
vsc6b               cmpa      #'M
                    bne       vsc6n
vsc6r               puls      b                   one more letter of REM
                    addb      #$10
                    bra       vsc8
vsc6n               puls      b                   not REM: the statement has begun
vsc7                andb      #^(VS.ST+VS.REM)
vsc8                stb       <vstat
vsc9                lda       ,s
                    sta       vlast,x
                    puls      d,x,pc
* vs_word: carry clear if A goes on a name (a letter, digit, _ or $)
vs_word             pshs      a
                    cmpa      #'_
                    beq       vsw8
                    cmpa      #'$
                    beq       vsw8
                    cmpa      #'0
                    blo       vsw9
                    cmpa      #'9
                    bls       vsw8
                    anda      #$DF
                    cmpa      #'A
                    blo       vsw9
                    cmpa      #'Z
                    bhi       vsw9
vsw8                andcc     #^Carry
                    puls      a,pc
vsw9                orcc      #Carry
                    puls      a,pc

* vs_cur: the cursor, at the start of the stopped line, to the start of
* its statement dbstm (on its "\")
vs_cur              tst       <dbstm
                    beq       vsu9
                    lbsr      vs_init
vsu1                lbsr      a_cpos
                    lbsr      p_char
                    bcs       vsu8
                    cmpa      #C$CR
                    beq       vsu8
                    lbsr      vs_char
                    ldx       <base
                    lda       vseg,x
                    cmpa      <dbstm
                    beq       vsu8
                    lbsr      c_right
                    bra       vsu1
vsu8                clr       <vstat
vsu9                rts
