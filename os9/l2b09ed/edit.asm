********************************************************************
* edit - the main loop and the editing commands

m_loop              lbsr      v_fix
                    lbsr      v_draw
                    lbsr      getkey
                    cmpa      #EK.EOF
                    lbeq      quit                the key script ended
                    ldx       #0
                    stx       <msgp
                    clr       <msgerr
                    ldb       #1
                    stb       <setwant
                    cmpa      #C$SPAC
                    blo       ml2
                    cmpa      #$7E
                    bhi       ml2
                    bsr       c_char
                    bra       m_loop
ml2                 leax      cmdtab,pcr
ml3                 ldb       ,x
                    beq       m_loop              not a command
                    cmpa      ,x
                    beq       ml4
                    leax      3,x
                    bra       ml3
ml4                 ldd       1,x
                    leax      cmdtab,pcr
                    jsr       d,x
                    bra       m_loop

cmdtab              fcb       C$CR
                    fdb       c_enter-cmdtab
                    fcb       C$TAB
                    fdb       c_tab-cmdtab
                    fcb       EK.BS
                    fdb       c_bs-cmdtab
                    fcb       EK.DEL
                    fdb       c_del-cmdtab
                    fcb       EK.LEFT
                    fdb       c_left-cmdtab
                    fcb       EK.RIGHT
                    fdb       c_right-cmdtab
                    fcb       EK.UP
                    fdb       c_up-cmdtab
                    fcb       EK.DOWN
                    fdb       c_down-cmdtab
                    fcb       EK.PGUP
                    fdb       c_pgup-cmdtab
                    fcb       EK.PGDN
                    fdb       c_pgdn-cmdtab
                    fcb       EK.WLEFT
                    fdb       c_wleft-cmdtab
                    fcb       EK.WRIGHT
                    fdb       c_wright-cmdtab
                    fcb       EK.TOP
                    fdb       c_top-cmdtab
                    fcb       EK.BOTTOM
                    fdb       c_bottom-cmdtab
                    fcb       EK.HOME
                    fdb       c_home-cmdtab
                    fcb       $0A                 ^J start of line
                    fdb       c_home-cmdtab
                    fcb       $0B                 ^K end of line
                    fdb       c_end-cmdtab
                    fcb       $04                 ^D delete line
                    fdb       c_delln-cmdtab
                    fcb       $07                 ^G go to line
                    fdb       c_goto-cmdtab
                    fcb       $13                 ^S save
                    fdb       c_save-cmdtab
                    fcb       EK.F2
                    fdb       c_save-cmdtab
                    fcb       $11                 ^Q quit
                    fdb       c_quit-cmdtab
                    fcb       0

* Redraw requests
rd_all              lda       #RD.ALL
                    bra       rd
rd_below            lda       #RD.BELOW
                    bra       rd
rd_line             lda       #RD.LINE
rd                  ora       <redraw
                    sta       <redraw
                    rts

* c_char: insert A
c_tab               lda       #C$TAB
c_char              lbsr      ed_ins
                    bcs       c_full
                    bra       rd_line
c_full              leax      fullms,pcr
                    stx       <msgp
                    rts

* c_enter: new line, indented like the one it splits
c_enter             ldu       <base
                    leau      wp,u
                    ldd       <cpos
                    std       ,u
                    ldd       <cpos+2
                    std       2,u
                    lbsr      p_bol
                    ldx       #0                  leading spaces before the cursor
ce1                 ldd       ,u
                    cmpd      <cpos
                    bne       ce2
                    ldd       2,u
                    cmpd      <cpos+2
                    beq       ce3
ce2                 lbsr      p_char
                    bcs       ce3
                    cmpa      #C$SPAC
                    bne       ce3
                    leax      1,x
                    lbsr      p_next
                    bra       ce1
ce3                 lda       #C$CR
                    lbsr      ed_ins
                    bcs       c_full
                    ldd       <curline
                    addd      #1
                    std       <curline
ce4                 cmpx      #0
                    beq       ce5
                    lda       #C$SPAC
                    lbsr      ed_ins
                    bcs       c_full
                    leax      -1,x
                    bra       ce4
ce5                 bra       rd_below

* c_bs: delete the character before the cursor
c_bs                ldu       <base
                    leau      cpos,u
                    lbsr      p_prev
                    bcs       cb9
                    lbsr      p_char
                    cmpa      #C$CR
                    bne       cb1
                    ldd       <curline
                    subd      #1
                    std       <curline
                    lbsr      ed_del
                    lbra      rd_below
cb1                 lbsr      ed_del
                    lbra      rd_line
cb9                 rts

* c_del: delete the character at the cursor
c_del               ldu       <base
                    leau      cpos,u
                    lbsr      p_char
                    bcs       cd9
                    cmpa      #C$CR
                    bne       cd1
                    lbsr      ed_del
                    lbra      rd_below
cd1                 lbsr      ed_del
                    lbra      rd_line
cd9                 rts

* c_delln: delete the cursor line
c_delln             ldu       <base
                    leau      cpos,u
                    lbsr      p_bol
cdl1                lbsr      ed_del
                    bcs       cdl9
                    cmpa      #C$CR
                    bne       cdl1
cdl9                lbra      rd_below

* Cursor movement.  The cursor line number follows every carriage
* return crossed.
c_left              ldu       <base
                    leau      cpos,u
                    lbsr      p_prev
                    bcs       cl9
                    lbsr      p_char
                    cmpa      #C$CR
                    bne       cl9
                    ldd       <curline
                    subd      #1
                    std       <curline
cl9                 rts

c_right             ldu       <base
                    leau      cpos,u
                    lbsr      p_char
                    bcs       cr9
                    cmpa      #C$CR
                    bne       crt1
                    ldd       <curline
                    addd      #1
                    std       <curline
crt1                 lbsr      p_next
                    andcc     #^Carry
cr9                 rts

c_up                clr       <setwant
                    ldd       <curline
                    beq       cu9
                    subd      #1
                    std       <curline
                    ldu       <base
                    leau      cpos,u
                    lbsr      p_prevln
                    ldd       <wantcol
                    lbra      p_tocol
cu9                 rts

c_down              clr       <setwant
                    ldu       <base
                    leau      wp,u
                    ldd       <cpos
                    std       ,u
                    ldd       <cpos+2
                    std       2,u
                    lbsr      p_nextln
                    bcs       cdn9
                    ldd       ,u
                    std       <cpos
                    ldd       2,u
                    std       <cpos+2
                    ldd       <curline
                    addd      #1
                    std       <curline
                    ldu       <base
                    leau      cpos,u
                    ldd       <wantcol
                    lbra      p_tocol
cdn9                rts

c_home              ldu       <base
                    leau      cpos,u
                    lbra      p_bol

c_end               ldu       <base
                    leau      cpos,u
                    lbra      p_eol

c_top               ldd       <first
                    std       <cpos
                    ldd       #0
                    std       <cpos+2
                    std       <curline
                    rts

c_bottom            ldx       <first
cbt1                ldd       DS.NEXT,x
                    beq       cbt2
                    tfr       d,x
                    bra       cbt1
cbt2                stx       <cpos
                    ldd       DS.USED,x
                    std       <cpos+2
                    ldd       <nlines
                    std       <curline
                    rts

* c_pgup, c_pgdn: scroll a window's worth, and the cursor with it
c_pgup              ldb       <wrows
                    decb
cpu1                pshs      b
                    ldu       <base
                    leau      tpos,u
                    lbsr      p_prevln
                    bcs       cpu2
                    ldd       <topline
                    subd      #1
                    std       <topline
cpu2                lbsr      c_up
                    puls      b
                    decb
                    bne       cpu1
                    lbra      rd_all

c_pgdn              ldb       <wrows
                    decb
cpd1                pshs      b
                    ldu       <base
                    leau      wp,u
                    ldd       <tpos
                    std       ,u
                    ldd       <tpos+2
                    std       2,u
                    lbsr      p_nextln
                    bcs       cpd2
                    ldd       ,u
                    std       <tpos
                    ldd       2,u
                    std       <tpos+2
                    ldd       <topline
                    addd      #1
                    std       <topline
cpd2                lbsr      c_down
                    puls      b
                    decb
                    bne       cpd1
                    lbra      rd_all

* Words are letters, digits and underscores
is_word             cmpa      #'0
                    blo       iw0
                    cmpa      #'9
                    bls       iw1
                    cmpa      #'A
                    blo       iw0
                    cmpa      #'Z
                    bls       iw1
                    cmpa      #'_
                    beq       iw1
                    cmpa      #'a
                    blo       iw0
                    cmpa      #'z
                    bls       iw1
iw0                 andcc     #^Carry
                    rts
iw1                 orcc      #Carry
                    rts

* c_wright: to the start of the next word
c_wright            ldu       <base
                    leau      cpos,u
                    lbsr      p_char
                    bcs       cwr9
                    bsr       is_word
                    bcc       cwr1
                    lbsr      c_right
                    bra       c_wright
cwr1                ldu       <base
                    leau      cpos,u
                    lbsr      p_char
                    bcs       cwr9
                    bsr       is_word
                    bcs       cwr9
                    lbsr      c_right
                    bra       cwr1
cwr9                rts

* c_wleft: to the start of this or the previous word
c_wleft             bsr       prevch
                    bcs       cwl9
                    bsr       is_word
                    bcs       cwl1
                    lbsr      c_left
                    bra       c_wleft
cwl1                bsr       prevch
                    bcs       cwl9
                    bsr       is_word
                    bcc       cwl9
                    lbsr      c_left
                    bra       cwl1
cwl9                rts

* prevch: A = the character before the cursor; carry at the start
prevch              ldu       <base
                    leau      wp,u
                    ldd       <cpos
                    std       ,u
                    ldd       <cpos+2
                    std       2,u
                    lbsr      p_prev
                    bcs       pvc9
                    lbra      p_char
pvc9                rts

* c_goto: ask for a line number and go there
c_goto              leax      gomsg,pcr
                    lbsr      v_prompt
                    bcs       cg9
                    ldx       <base
                    leax      inbuf,x
                    lbsr      getnum
                    subd      #1
                    bcc       cgo1
                    ldd       #0
cgo1                 bsr       goto_line
cg9                 rts

* goto_line: cursor to the start of line D (0 = first)
goto_line           cmpd      <nlines
                    bls       gl1
                    ldd       <nlines
gl1                 std       <curline
                    std       <tmp                carriage returns still to pass
                    ldx       <first
                    ldd       <tmp
                    beq       gl5
gl2                 ldd       DS.LINES,x          the page holding that many
                    cmpd      <tmp
                    bhs       gl3
                    ldd       <tmp
                    subd      DS.LINES,x
                    std       <tmp
                    ldx       DS.NEXT,x
                    bne       gl2
gl3                 stx       <cpos
                    ldd       #0
                    std       <cpos+2
                    ldu       <base
                    leau      cpos,u
gl4                 lbsr      p_char
                    lbsr      p_next
                    cmpa      #C$CR
                    bne       gl4
                    ldd       <tmp
                    subd      #1
                    std       <tmp
                    bne       gl4
                    rts
gl5                 stx       <cpos
                    std       <cpos+2
                    rts

* c_save: write the file (asking for a name if there is none);
* carry if it was not saved
c_save              ldx       <base
                    leax      fname,x
                    tst       ,x
                    bne       cs2
                    leax      samsg,pcr
                    lbsr      v_prompt
                    bcs       cs9
                    ldx       <base
                    leax      inbuf,x
                    ldy       <base
                    leay      fname,y
                    ldb       #63
cs1                 lda       ,x+
                    sta       ,y+
                    beq       cs1a
                    decb
                    bne       cs1
                    clr       ,y
cs1a                ldx       <base
                    tst       fname,x
                    beq       cs9
cs2                 lbsr      f_save
                    bcs       cs_err
                    leax      savedm,pcr
                    stx       <msgp
                    andcc     #^Carry
                    rts
cs_err              stb       <msgerr
cs9                 orcc      #Carry
                    rts

* c_quit: leave, offering to save first
c_quit              tst       <modif
                    beq       cq_go
                    leax      qmsg,pcr
                    lbsr      v_prompt
                    bcs       cq9
                    ldx       <base
                    lda       inbuf,x
                    anda      #$DF
                    cmpa      #'N
                    beq       cq_go
                    cmpa      #'Y
                    bne       cq9
                    bsr       c_save
                    bcs       cq9
cq_go               lbra      quit
cq9                 rts

fullms              fcc       "Out of pages"
                    fcb       0
gomsg               fcc       "Go to line: "
                    fcb       0
samsg               fcc       "Save as: "
                    fcb       0
savedm              fcc       "Saved"
                    fcb       0
qmsg                fcc       "Save changes (Y/N)? "
                    fcb       0
