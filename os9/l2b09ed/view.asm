********************************************************************
* view - the text window and the status line

* v_fix: work out the cursor column and scroll so the cursor shows
v_fix               ldu       <base
                    leau      cpos,u
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
vf2b                lda       <redraw
                    ora       #RD.ALL
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
                    ora       #RD.ALL
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
vc9                 lda       #RD.ALL
                    ora       <redraw
                    sta       <redraw
                    rts

* v_draw: redraw what the flags ask for, the status line and the cursor
v_draw              lbsr      t_curoff
                    lda       <redraw
                    bita      #RD.ALL+RD.BELOW    lines may have moved
                    beq       vd00
                    lbsr      bp_lines
vd00                equ       *
                    tst       <selon
                    beq       vd0
                    lbsr      sel_bounds
vd0                 bita      #RD.ALL
                    beq       vd1
                    lbsr      v_frame
                    lbsr      w_draw
                    ldd       <tpos
                    std       <wp
                    ldd       <tpos+2
                    std       <wp+2
                    clrb
                    bsr       v_rows
                    bra       vd3
vd1                 bita      #RD.BELOW+RD.LINE
                    beq       vd3
                    ldd       <cpos
                    std       <wp
                    ldd       <cpos+2
                    std       <wp+2
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
vd2                 bsr       v_line
vd3                 lbsr      v_stat
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

* v_rows: draw window rows B to the bottom, starting with the line at wp
v_rows              pshs      b
vr1                 ldb       ,s
                    cmpb      <wrows
                    bhs       vr9
                    bsr       v_line
                    inc       ,s
                    bcc       vr1
vr2                 ldb       ,s                  the text ended: blank rows
                    cmpb      <wrows
                    bhs       vr9
                    bsr       v_blank
                    inc       ,s
                    bra       vr2
vr9                 puls      b,pc

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

* v_colput: v_put, in colour B unless colours are off
v_colput            tst       <nocolr
                    bne       v_put
                    lbsr      hl_col
                    bra       v_put

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
                    tst       <dbgon
                    beq       vl0
                    ldd       <vline
                    cmpd      <dbfl
                    bne       vl0
                    inc       <vexec
vl0                 clr       <hlst               syntax colours start afresh
                    clr       <hlrun
                    ldu       <base
                    leau      wp,u
                    ldx       #0                  display column
vl1                 lbsr      p_char
                    bcs       vl_eof
                    cmpa      #C$CR
                    beq       vl_eol
                    tst       <nocolr
                    bne       vl1a
                    lbsr      hl_cls              B = its colour
vl1a                cmpa      #C$TAB
                    beq       vl_tab
                    cmpx      <leftcol
                    blo       vl2
                    lbsr      v_selat
                    lbsr      v_colput
vl2                 leax      1,x
                    bra       vl3
vl_tab              lbsr      v_selat
                    tst       <nocolr
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
                    lbsr      v_selat
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

* v_endpad: the rest of the row, reversed on the line the program
* stopped at; the colour goes back to normal first
v_endpad            lbsr      hl_norm
                    tst       <vexec
                    beq       vep1
                    tst       <vrev
                    bne       vep2
                    inc       <vrev
                    lbsr      t_rev
                    bra       vep2
vep1                bsr       v_selend
vep2                lbsr      v_pad
                    bra       v_selend

* v_selat: reverse video on or off for display column X of line vline,
* by whether it is in the selection (the other way round on the line
* the program stopped at)
v_selat             pshs      d
                    clra
                    tst       <selon
                    beq       vsa2
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
vsa_in              lda       #1
                    bra       vsa2
vsa_out             clra
vsa2                eora      <vexec
                    cmpa      <vrev
                    beq       vsa8
                    sta       <vrev
                    tsta
                    beq       vsa3
                    lbsr      t_rev
                    bra       vsa8
vsa3                lbsr      t_norm
vsa8                puls      d,pc

* v_selend: reverse video off
v_selend            tst       <vrev
                    beq       vse9
                    clr       <vrev
                    lbra      t_norm
vse9                rts

* v_stat: the bottom border (modified mark, line:column) and the hint line
v_stat              ldb       <wtop               bottom border
                    addb      <wrows
                    clra
                    lbsr      t_xy
                    lda       <glyphs+GL.BL2
                    lbsr      t_ch
                    lda       <glyphs+GL.H2
                    tst       <modif
                    beq       vs1
                    lda       #'*
vs1                 lbsr      t_ch
                    lda       <glyphs+GL.H2
                    lbsr      t_ch
                    ldx       <base
                    leax      sbuf,x
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
                    ldx       <base
                    leax      sbuf,x
                    lbsr      t_str
                    ldb       <scrw
                    subb      ,s+
                    lda       <glyphs+GL.H2
                    lbsr      t_rep
                    lda       <glyphs+GL.BR2
                    lbsr      t_ch
* v_hint: the last row: a message, an error, or the key hints
v_hint              ldx       <base
                    leax      sbuf,x
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
                    ldx       <base
                    leax      sbuf,x
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
                    lbsr      v_menubar
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
vfr1                ldx       <base
                    leax      sbuf,x
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
                    ldx       <base
                    leax      sbuf,x
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
                    rts

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
                    lbsr      mb_off
                    puls      a,pc

untitl              fcc       "(untitled)"
                    fcb       0
errmsg              fcc       "Error #"
                    fcb       0
hintms              fcc       "F1 Help  ^S Save  ^O Open  ^G Go to  ^B Make  ^R Run  Alt+letter Menus"
                    fcb       0
dbghint             fcc       "Stopped:  F7 Step  F8 Over  ^R Continue  ^P Reset  ^E Evaluate  ^W Watch"
                    fcb       0
