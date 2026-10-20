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
                    lbsr      c_char
                    bra       m_loop
ml2                 cmpa      #EK.ALT             Alt+letter opens a menu
                    blo       ml2a
                    cmpa      #EK.ALT+25
                    bhi       ml2a
                    lbsr      c_altkey
                    bra       m_loop
ml2a                leax      cmdtab,pcr
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
                    fdb       k_left-cmdtab
                    fcb       EK.RIGHT
                    fdb       k_right-cmdtab
                    fcb       EK.UP
                    fdb       k_up-cmdtab
                    fcb       EK.DOWN
                    fdb       k_down-cmdtab
                    fcb       EK.PGUP
                    fdb       k_pgup-cmdtab
                    fcb       EK.PGDN
                    fdb       k_pgdn-cmdtab
                    fcb       EK.WLEFT
                    fdb       k_wleft-cmdtab
                    fcb       EK.WRIGHT
                    fdb       k_wright-cmdtab
                    fcb       EK.TOP
                    fdb       k_top-cmdtab
                    fcb       EK.BOTTOM
                    fdb       k_bottom-cmdtab
                    fcb       EK.HOME
                    fdb       k_home-cmdtab
                    fcb       $0A                 ^J start of line
                    fdb       k_home-cmdtab
                    fcb       $0B                 ^K end of line
                    fdb       k_end-cmdtab
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
                    fcb       $0F                 ^O open
                    fdb       c_open-cmdtab
                    fcb       EK.F1+2             F3 open
                    fdb       c_open-cmdtab
                    fcb       EK.F1
                    fdb       c_help-cmdtab
                    fcb       $02                 ^B make
                    fdb       c_make-cmdtab
                    fcb       $12                 ^R run
                    fdb       c_run-cmdtab
                    fcb       $0E                 ^N next error
                    fdb       c_nexterr-cmdtab
                    fcb       EK.F1+4             F5 user screen
                    fdb       c_user-cmdtab
                    fcb       EK.F1+5             F6 message window
                    fdb       c_msgwin-cmdtab
                    fcb       EK.F1+6             F7 step
                    fdb       c_step-cmdtab
                    fcb       $10                 ^P program reset
                    fdb       c_reset-cmdtab
                    fcb       $05                 ^E evaluate
                    fdb       c_eval-cmdtab
                    fcb       $17                 ^W watch
                    fdb       c_watch-cmdtab
                    fcb       EK.CSPC             Ctrl+Space pretty print all
                    fdb       c_ppall-cmdtab
                    fcb       $14                 ^T breakpoint
                    fdb       c_bptog-cmdtab
                    fcb       EK.F1+3             F4 run to the cursor
                    fdb       c_tocur-cmdtab
                    fcb       EK.F1+7             F8 step over
                    fdb       c_over-cmdtab
                    fcb       $06                 ^F find
                    fdb       c_find-cmdtab
                    fcb       $0C                 ^L find next
                    fdb       c_fnext-cmdtab
                    fcb       EK.FPREV            Ctrl+Shift+L find previous
                    fdb       c_fprev-cmdtab
                    fcb       EK.SP1              Ctrl+1 single spacing
                    fdb       c_sp1-cmdtab
                    fcb       EK.SP2              Ctrl+2 double spacing
                    fdb       c_sp2-cmdtab
                    fcb       $1A                 ^Z undo
                    fdb       c_undo-cmdtab
                    fcb       $19                 ^Y redo
                    fdb       c_redo-cmdtab
                    fcb       $03                 ^C copy
                    fdb       c_copy-cmdtab
                    fcb       $18                 ^X cut
                    fdb       c_cut-cmdtab
                    fcb       $16                 ^V paste
                    fdb       c_paste-cmdtab
                    fcb       $01                 ^A select all
                    fdb       c_selall-cmdtab
                    fcb       EK.SUP
                    fdb       c_sup-cmdtab
                    fcb       EK.SDOWN
                    fdb       c_sdown-cmdtab
                    fcb       EK.SLEFT
                    fdb       c_sleft-cmdtab
                    fcb       EK.SRIGHT
                    fdb       c_sright-cmdtab
                    fcb       EK.SWLEFT
                    fdb       c_swleft-cmdtab
                    fcb       EK.SWRIGHT
                    fdb       c_swright-cmdtab
                    fcb       EK.ESC
                    fdb       c_esc-cmdtab
                    fcb       EK.WHEEL
                    fdb       c_wheel-cmdtab
                    fcb       EK.MOUSE
                    fdb       c_mouse-cmdtab
                    fcb       0

* Redraw requests
rd_all              lda       #RD.ALL
                    bra       rd
rd_text             lda       #RD.TEXT
                    bra       rd
rd_stop             lda       #RD.TEXT+RD.WIN     a debugger stop: the text and the
                    bra       rd                  watches, not the frame or scroll bar
rd_below            lda       #RD.BELOW
                    bra       rd
rd_line             lda       #RD.LINE
rd                  ora       <redraw
                    sta       <redraw
                    rts

* c_char: insert A
c_tab               lda       #C$TAB
c_char              pshs      a
                    lbsr      sel_del
                    puls      a
                    lbsr      ed_ins
                    bcs       c_full
                    bra       rd_line
c_full              leax      fullms,pcr
                    stx       <msgp
                    rts

* c_enter: new line, indented like the one it splits
c_enter             lbsr      sel_del
                    ldu       <base
                    leau      wp,u
                    lbsr      cp_u
                    lbsr      p_bol
                    ldx       #0                  leading spaces before the cursor
                    tst       <noindt
                    bne       ce3
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
ce5                 lda       #RD.BELOW+RD.PREV   the line split above too
                    bra       rd

* c_bs: delete the character before the cursor
c_bs                lbsr      sel_del
                    bcs       cb9
                    lbsr      a_cpos
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
c_del               lbsr      sel_del
                    bcs       cd9
                    lbsr      a_cpos
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
c_delln             lbsr      sel_off
                    lbsr      a_cpos
                    lbsr      p_bol
cdl1                lbsr      ed_del
                    bcs       cdl9
                    cmpa      #C$CR
                    bne       cdl1
cdl9                lbra      rd_below

* Cursor movement.  The cursor line number follows every carriage
* return crossed.
c_left              lbsr      a_cpos
                    lbsr      p_prev
                    bcs       cl9
                    lbsr      p_char
                    cmpa      #C$CR
                    bne       cl9
                    ldd       <curline
                    subd      #1
                    std       <curline
cl9                 rts

c_right             lbsr      a_cpos
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
                    lbsr      a_cpos
                    lbsr      p_prevln
                    ldd       <wantcol
                    lbra      p_tocol
cu9                 rts

c_down              clr       <setwant
                    ldu       <base
                    leau      wp,u
                    lbsr      cp_u
                    lbsr      p_nextln
                    bcs       cdn9
                    ldd       ,u
                    std       <cpos
                    ldd       2,u
                    std       <cpos+2
                    ldd       <curline
                    addd      #1
                    std       <curline
                    lbsr      a_cpos
                    ldd       <wantcol
                    lbra      p_tocol
cdn9                rts

c_home              lbsr      a_cpos
                    lbra      p_bol

c_end               lbsr      a_cpos
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
                    lbra      rd_text

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
                    lbra      rd_text

* c_wheel: the mouse wheel: 3 lines a step (at most a window's worth),
* the cursor with them, as the scroll bar's arrows; a step away from the
* user scrolls up
c_wheel             ldx       <base
                    ldd       muwst,x
                    bpl       cwh1
                    coma
                    comb
                    addd      #1
                    bsr       cwh_n
                    bra       cpu1
cwh1                beq       cwh9
                    bsr       cwh_n
                    bra       cpd1
cwh9                rts
* cwh_n: B = the lines for D steps (D at least 1)
cwh_n               tsta
                    bne       cwn1
                    cmpb      #85
                    bhi       cwn1
                    lda       #3
                    mul
                    pshs      b                   ,s = 3 a step
                    ldb       <wrows
                    decb
                    cmpb      ,s
                    bls       cwn2
                    ldb       ,s
cwn2                leas      1,s
                    rts
cwn1                ldb       <wrows
                    decb
                    rts

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
c_wright            lbsr      a_cpos
                    lbsr      p_char
                    bcs       cwr9
                    bsr       is_word
                    bcc       cwr1
                    lbsr      c_right
                    bra       c_wright
cwr1                lbsr      a_cpos
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
                    lbsr      cp_u
                    lbsr      p_prev
                    bcs       pvc9
                    lbra      p_char
pvc9                rts

* c_goto: ask for a line number and go there
c_goto              lbsr      sel_off
                    leax      gomsg,pcr
                    lbsr      dlg_in
                    bcs       cg9
                    lbsr      a_inbx
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
                    lbsr      a_cpos
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

fullms              fcc       "Out of pages"
                    fcb       0
gomsg               fcn       "Go to line"

* buf_top: cursor and window at the start of a freshly loaded text
buf_top             lbsr      bp_clear
                    ldd       <first
                    std       <cpos
                    std       <tpos
                    std       <apos
                    std       <xpos
                    ldd       #0
                    std       <cpos+2
                    std       <tpos+2
                    std       <apos+2
                    std       <xpos+2
                    std       <curline
                    std       <topline
                    std       <leftcol
                    std       <wantcol
                    lbra      rd_all
