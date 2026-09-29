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

* v_draw: redraw what the flags ask for, the status line and the cursor
v_draw              lbsr      t_curoff
                    lda       <redraw
                    bita      #RD.ALL
                    beq       vd1
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
                    bsr       v_rows
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
                    lda       <wleft
                    addb      <wtop
                    lbsr      t_xy
                    clr       <vcnt
                    ldu       <base
                    leau      wp,u
                    ldx       #0                  display column
vl1                 lbsr      p_char
                    bcs       vl_eof
                    cmpa      #C$CR
                    beq       vl_eol
                    cmpa      #C$TAB
                    beq       vl_tab
                    cmpx      <leftcol
                    blo       vl2
                    bsr       v_put
vl2                 leax      1,x
                    bra       vl3
vl_tab              tfr       x,y
                    lbsr      col_adv
                    pshs      x
vlt1                cmpy      <leftcol
                    blo       vlt2
                    lda       #C$SPAC
                    bsr       v_put
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
vl_eol              bsr       v_pad
                    lbsr      p_next
                    andcc     #^Carry
                    puls      d,x,y,u,pc
vl_eof              lbsr      v_pad
                    orcc      #Carry
                    puls      d,x,y,u,pc

* v_stat: the status line (a message if there is one)
v_stat              ldx       <base
                    leax      sbuf,x
                    lda       #C$SPAC
                    sta       ,x+
                    ldy       <msgp
                    bne       vs_msg
                    tst       <msgerr
                    bne       vs_err
                    ldy       <base               file name
                    leay      fname,y
                    tst       ,y
                    bne       vs1
                    leay      untitl,pcr
vs1                 bsr       s_str
                    lda       #C$SPAC
                    tst       <modif
                    beq       vs2
                    lda       #'*
vs2                 sta       ,x+
                    leay      lnmsg,pcr
                    bsr       s_str
                    ldd       <curline
                    addd      #1
                    lbsr      n_dec
                    leay      colmsg,pcr
                    bsr       s_str
                    ldd       <curcol
                    addd      #1
                    lbsr      n_dec
                    bra       vs_out
vs_msg              bsr       s_str
                    bra       vs_out
vs_err              leay      errmsg,pcr
                    bsr       s_str
                    clra
                    ldb       <msgerr
                    lbsr      n_dec
vs_out              clr       ,x
                    ldb       <scrh
                    decb
                    clra
                    lbsr      t_xy
                    lbsr      t_rev
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
                    lbra      t_norm

* s_str: copy the string at Y (ending in 0) to X
s_str               lda       ,y+
                    beq       ss9
                    sta       ,x+
                    bra       s_str
ss9                 rts

untitl              fcc       "(untitled)"
                    fcb       0
lnmsg               fcc       "  Line "
                    fcb       0
colmsg              fcc       "  Col "
                    fcb       0
errmsg              fcc       "Error #"
                    fcb       0

* v_prompt: ask for a line on the status line.  X = prompt text.
* The answer is in inbuf (ending in 0); carry if Esc was pressed.
v_prompt            pshs      x
                    ldx       <base
                    leax      inbuf,x
                    clr       ,x
vpr1                ldx       <base               show the prompt and the answer
                    leax      sbuf,x
                    lda       #C$SPAC
                    sta       ,x+
                    ldy       ,s
                    bsr       s_str
                    ldy       <base
                    leay      inbuf,y
                    bsr       s_str
                    tfr       x,d
                    subd      <base
                    subd      #sbuf
                    pshs      b                   cursor column
                    lbsr      vs_out
                    puls      a
                    ldb       <scrh
                    decb
                    lbsr      t_xy
                    lbsr      t_flush
                    lbsr      getkey
                    ldx       <base
                    leax      inbuf,x
vpr2                tst       ,x+                 X = end of the answer
                    bne       vpr2
                    leax      -1,x
                    cmpa      #C$CR
                    beq       vpr_ok
                    cmpa      #EK.ESC
                    beq       vpr_esc
                    cmpa      #EK.EOF
                    beq       vpr_esc
                    cmpa      #EK.BS
                    bne       vpr3
                    tfr       x,d
                    subd      <base
                    cmpd      #inbuf
                    beq       vpr1                nothing to delete
                    clr       ,-x
                    bra       vpr1
vpr3                cmpa      #C$SPAC
                    blo       vpr1
                    cmpa      #$7E
                    bhi       vpr1
                    pshs      a
                    tfr       x,d
                    subd      <base
                    cmpd      #inbuf+60
                    puls      a
                    beq       vpr1                full
                    sta       ,x+
                    clr       ,x
                    bra       vpr1
vpr_ok              andcc     #^Carry
                    puls      x,pc
vpr_esc             orcc      #Carry
                    puls      x,pc
