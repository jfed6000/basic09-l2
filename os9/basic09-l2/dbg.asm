********************************************************************
* dbg - the debugger: where the program stopped, step, continue,
* reset, evaluate and watches
*
* A stop comes as %DEBUG <proc> <line> (rt_wait, dbg_at).  The editor
* then stays in the debugger: the line it stopped at is drawn in
* reverse video, the watches are printed again, and step, cont, print
* and let go to l2b09run until the program ends or is reset (q).

MAXWATCH              equ       6
WTEXMAX             equ       30                  expression, with its 0
WTVMAX              equ       46                  value, with its 0
WT.EXPR             equ       0
WT.VAL              equ       WTEXMAX
WT.SIZE             equ       WTEXMAX+WTVMAX
LASTMAX             equ       64

* dbg_at: rt_wait got %DEBUG (evproc, evline): note where it stopped
dbg_at              ldx       <evproc             the name
                    ldy       <base
                    leay      dbname,y
                    ldb       #NAMEMAX-1
dat1                lda       ,x+
                    beq       dat2
                    sta       ,y+
                    decb
                    bne       dat1
dat2                clr       ,y
                    ldd       <evline
                    std       <dbline
                    ldd       #$FFFF              the file line, if it is ours
                    std       <dbfl
                    ldy       <base
                    leay      dbname,y
                    lbsr      pt_find
                    bcs       dat3
                    ldd       PR.LINE,y
                    addd      <dbline
                    std       <dbfl
dat3                lda       #1
                    sta       <dbgon
                    clr       <evcode
                    andcc     #^Carry
                    rts

* dbg_quit: leave the debugger (q), which ends the program; carry if
* the runtime has gone
dbg_quit            lbsr      a_rline
                    ldd       #$710D              "q", CR
                    std       ,x
                    lbsr      rt_cmd
                    bcs       dq9
                    lbra      rt_wait
dq9                 rts

* dbg_cmd: run command X (ending in CR) as dbg_go does, after sending
* the breakpoints if they changed
dbg_cmd             pshs      x
                    lbsr      bp_sync
                    puls      x
                    lbcs      dg9
                    ldy       <base
                    leay      rline,y
dcm1                lda       ,x+
                    sta       ,y+
                    cmpa      #C$CR
                    bne       dcm1
* dbg_go: send the command in rline (run, cont or step), with the
* program's terminal shown, and wait until the program stops or ends
dbg_go              lbsr      ms_clear
                    lbsr      w_hide
                    tst       <uterm
                    bne       dg1
                    leax      runms,pcr
                    stx       <msgp
                    lbsr      v_hint
                    lbsr      t_flush
dg1                 lbsr      rt_cmd
                    lbcs      dg9
                    inc       <running
                    ldx       <base               a step (F7, F8): our screen stays,
                    leax      rline,x             unless the program waits for
                    ldd       ,x                  INPUT (%INPUT, in rt_wait: u_inp)
                    cmpd      #$7374              "st"ep
                    beq       dg1a
                    cmpd      #$6F76              "ov"er
                    beq       dg1a
                    lbsr      u_inp
dg1a                lbsr      rt_wait
                    pshs      cc
                    clr       <running
                    bcs       dg2                 (the runtime has gone)
                    tst       <dbgon              it ended, not stopped: wait for a
                    bne       dg2                 key on its screen first
                    lbsr      u_inp
                    lbsr      u_pause
dg2                 ldx       <base
                    tst       ushown,x
                    beq       dg2a
                    clr       ushown,x
                    lbsr      u_back
dg2a                puls      cc
                    bcs       dg9
                    lbsr      bp_tmpclr
                    bcs       dg9
                    clr       <msgp
                    clr       <msgp+1
* dbg_stop: show where the program stopped, or that it ended
dbg_stop            tst       <dbgon
                    beq       dst_end
                    lbsr      wt_fetch
                    bcs       dg9
                    ldb       <nmsg               an error: its message
                    beq       dst1
                    lbsr      w_show
                    clrb
                    lbsr      ms_jump
dst1                ldd       <dbfl
                    cmpd      #$FFFF
                    bne       dbg_show
                    lbsr      a_mbuf              not in the text: say where
                    stx       <msgp
                    leay      stopms,pcr
                    lbsr      s_str
                    ldy       <base
                    leay      dbname,y
                    lbsr      s_str
                    leay      lnms,pcr
                    lbsr      s_str
                    ldd       <dbline
                    lbsr      n_dec
                    clr       ,x
                    lbra      rd_all
dst_end             lbsr      wt_clear
                    ldb       <nmsg
                    beq       dst9
                    lbsr      w_show
                    clrb
                    lbra      ms_jump
dst9                lbra      rd_all
dg9                 rts
runms               fcn       "Running..."
stopms              fcn       "Stopped in "
lnms                fcn       " line "

* dbg_show: the cursor to the line the program stopped at; the window
* moves only if that line is not in it
dbg_show            lbsr      sel_off
                    ldd       <dbfl
                    subd      <topline
                    bcs       dsh1
                    tsta
                    bne       dsh1
                    cmpb      <wrows
                    bhs       dsh1
                    ldd       <dbfl
                    lbsr      goto_line
                    lbra      rd_all
dsh1                ldd       <dbfl
                    lbsr      goto_line
                    lbra      v_center

* c_step: one statement, into a called procedure (F7).  If the program
* is not running: Make, then start it, stopped at its first statement.
c_step              tst       <dbgon
                    beq       c_stfirst
                    leax      stepcm,pcr
                    lbra      dbg_cmd
c_stfirst           lbsr      c_make
                    bcs       cst9
                    tst       <dbgon              (Make did not reset it)
                    bne       c_step
                    leax      stepfc,pcr
                    lbra      run_first
cst9                rts
stepcm              fcc       "step"
                    fcb       C$CR
stepfc              fcn       "step "

c_notst             leax      notstms,pcr
                    stx       <msgp
                    rts
notstms             fcn       "The program is not stopped"

* c_reset: end the stopped program (^P)
c_reset             tst       <dbgon
                    beq       c_notst
                    lbsr      dbg_quit
                    bcs       crs9
                    lbsr      wt_clear
                    leax      rstms,pcr
                    stx       <msgp
                    lbra      rd_all
crs9                rts

* dbg_ask: send command X and the string at Y (both ending in 0), and
* wait for the stop that follows.  The answer (the last line of text,
* with an error number turned into its text) is in lastout.  Carry if
* the runtime has gone.
dbg_ask             pshs      y
                    ldy       <base
                    leay      rline,y
                    lbsr      s_cpy
                    puls      x
                    lbsr      s_cpy
                    lda       #C$CR
                    sta       ,y
                    ldx       <base
                    clr       lastout,x
                    inc       <quiet
                    lbsr      rt_cmd
                    bcs       dbq1
                    lbsr      rt_wait
dbq1                pshs      cc
                    clr       <quiet
                    puls      cc
                    bcs       dbq9
                    ldx       <base               "ERROR #<n>" -> "Error <n> <text>"
                    leax      lastout,x
                    leay      errtx,pcr
dbq2                lda       ,y+
                    beq       dbq3
                    cmpa      ,x+
                    beq       dbq2
                    andcc     #^Carry             an answer
                    rts
dbq3                lbsr      getnum
                    stb       <evcode
                    lbsr      a_mbuf
                    leay      errtx2,pcr
                    lbsr      s_str
                    clra
                    ldb       <evcode
                    lbsr      n_dec
                    ldu       <base
                    leau      mbuf+LASTMAX-1,u
                    lbsr      er_text
                    clr       ,x
                    ldx       <base
                    leay      lastout,x
                    leax      mbuf,x
                    lbsr      s_cpy
                    clr       ,y
                    andcc     #^Carry
dbq9                rts
printcm             fcn       "print "
letcm               fcn       "let "
breakcm             fcn       "break "

* out_keep: the line at X (ending in CR) to lastout
out_keep            pshs      d,x,y
                    ldy       <base
                    leay      lastout,y
                    ldb       #LASTMAX-1
ok1                 lda       ,x+
                    cmpa      #C$CR
                    beq       ok2
                    sta       ,y+
                    decb
                    bne       ok1
ok2                 clr       ,y
                    puls      d,x,y,pc

* word_at: the word at the cursor (or just before it) to inbuf; Z if
* there is none
word_at             ldu       <base
                    leau      wp,u
                    lbsr      cp_u
wa1                 lbsr      p_prev              back to its start
                    bcs       wa2
                    lbsr      p_char
                    lbsr      is_word
                    bcs       wa1
                    lbsr      p_next
wa2                 lbsr      a_inbx
                    ldb       #WTEXMAX-1
wa3                 lbsr      p_char
                    bcs       wa4
                    lbsr      is_word
                    bcc       wa4
                    sta       ,x+
                    lbsr      p_next
                    decb
                    bne       wa3
wa4                 clr       ,x
                    cmpb      #WTEXMAX-1
                    rts

* c_eval: evaluate an expression, or change a variable with
* <name>:=<value>, and show the result (^E)
c_eval              tst       <dbgon
                    lbeq      c_notst
                    bsr       word_at             start with the word at the cursor,
                    bne       cev1
                    ldx       <base               or the last expression
                    leay      inbuf,x
                    leax      estr,x
                    lbsr      s_cpy
                    clr       ,y
cev1                leax      evaltl,pcr
                    lbsr      dlg_inp
                    lbcs      cev9
                    lbsr      a_inbx
                    tst       ,x
                    lbeq      cev9
                    ldy       <base               keep it for next time
                    leay      estr,y
                    ldb       #61
cev2                lda       ,x+
                    sta       ,y+
                    beq       cev3
                    decb
                    bne       cev2
                    clr       ,y
cev3                lbsr      a_inbx              an assignment?
cev4                lda       ,x+
                    beq       cev_prt
                    cmpa      #':
                    bne       cev4
                    lda       ,x
                    cmpa      #'=
                    bne       cev4
                    leax      -1,x
                    pshs      x
                    leax      letcm,pcr
                    lbsr      a_inby
                    lbsr      dbg_ask
                    puls      x
                    bcs       cev9
                    ldy       <base
                    tst       lastout,y
                    bne       cev_err             it failed: say why
                    clr       ,x                  it worked: print the variable
                    lbsr      wt_fetch
                    bcs       cev9
cev_prt             leax      printcm,pcr
                    lbsr      a_inby
                    lbsr      dbg_ask
                    bcs       cev9
                    leay      eqtx,pcr
                    bra       cev5
cev_err             leay      coltx,pcr
cev5                pshs      y                   "<expr> = <value>" in sbuf
                    ldu       <base
                    leau      sbuf,u
                    lda       <scrw               as much as the dialog shows
                    suba      #8
                    cmpa      #56
                    bls       cev6
                    lda       #56
cev6                leau      a,u
                    lbsr      a_sbuf
                    lbsr      a_inby
                    bsr       s_lim
                    puls      y
                    bsr       s_lim
                    ldy       <base
                    leay      lastout,y
                    bsr       s_lim
                    clr       ,x
                    lbsr      a_sbuf
                    leay      evaltl,pcr
                    lbra      dlg_msgt
cev9                rts
evaltl              fcn       "Evaluate"
eqtx                fcn       " = "
coltx               fcn       ": "

* s_lim: copy the string at Y (ending in 0) to X, but not past U
s_lim               pshs      u
sli1                cmpx      ,s
                    bhs       sli9
                    lda       ,y+
                    beq       sli9
                    sta       ,x+
                    bra       sli1
sli9                puls      u,pc

* c_retbrk: stop when the program returns to a procedure (the Basic09
* debugger's BREAK <procedure>)
c_retbrk            tst       <dbgon
                    lbeq      c_notst
                    leax      rettl,pcr
                    lbsr      dlg_in
                    bcs       crb9
                    lbsr      a_inby
                    tst       ,y
                    beq       crb9
                    leax      breakcm,pcr
                    lbsr      dbg_ask
                    bcs       crb9
                    ldx       <base               "ok", or why not
                    leax      lastout,x
                    ldd       ,x
                    cmpd      #$6F6B              "ok"
                    bne       crb1
                    tst       2,x
                    bne       crb1
                    leax      retms,pcr
crb1                stx       <msgp
crb9                rts
rettl               fcn       "Stop on return to procedure"
retms               fcn       "^R continues until it returns there"

********************************************************************
* Watches

* wt_at: X = watch B
wt_at               pshs      d
                    lda       #WT.SIZE
                    mul
                    addd      #wtab
                    addd      <base
                    tfr       d,x
                    puls      d,pc

* wt_fetch: if the program is stopped, print every watch again; carry
* if the runtime has gone
wt_fetch            tst       <dbgon
                    beq       wtf8
                    clrb
wtf1                cmpb      <nwatch
                    bhs       wtf8
                    pshs      b
                    bsr       wt_at
                    pshs      x
                    leay      WT.EXPR,x
                    leax      printcm,pcr
                    lbsr      dbg_ask
                    puls      x
                    bcs       wtf_gone
                    leax      WT.VAL,x
                    ldy       <base
                    leay      lastout,y
                    ldb       #WTVMAX-1
wtf2                lda       ,y+
                    sta       ,x+
                    beq       wtf3
                    decb
                    bne       wtf2
                    clr       ,x
wtf3                puls      b
                    incb
                    bra       wtf1
wtf8                andcc     #^Carry
                    lbra      rd_all
wtf_gone            puls      b,pc

* wt_clear: the program ended: no values
wt_clear            clrb
wtc1                cmpb      <nwatch
                    bhs       wtc9
                    bsr       wt_at
                    clr       WT.VAL,x
                    incb
                    bra       wtc1
wtc9                lbra      rd_all

* c_watch: add a watch (^W)
c_watch             ldb       <nwatch
                    cmpb      #MAXWATCH
                    bhs       cwa_no
                    addb      #3                  the window with one more row
                    lbsr      w_fits
                    bcs       cwa_no
                    lbsr      word_at
                    leax      watchtl,pcr
                    lbsr      dlg_inp
                    bcs       cwa9
                    lbsr      a_inby
                    tst       ,y
                    beq       cwa9
                    ldb       <nwatch
                    bsr       wt_at
                    clr       WT.VAL,x
                    ldb       #WTEXMAX-1
cwa1                lda       ,y+
                    sta       ,x+
                    beq       cwa2
                    decb
                    bne       cwa1
                    clr       ,x
cwa2                inc       <nwatch
                    lbsr      w_layout
                    lbra      wt_fetch
cwa_no              leax      nowtms,pcr
                    stx       <msgp
cwa9                rts
watchtl             fcn       "Add watch"
nowtms              fcn       "No room for another watch"

* c_wdel: delete watch <n>, or all of them with 0
c_wdel              tst       <nwatch
                    beq       cwd_none
                    leax      wdeltl,pcr
                    lbsr      dlg_in
                    bcs       cwd9
                    lbsr      a_inbx
                    tst       ,x
                    beq       cwd9
                    lbsr      getnum
                    tsta
                    bne       cwd9
                    tstb
                    beq       cwd_all
                    cmpb      <nwatch
                    bhi       cwd9
                    decb                          move the ones after it down
                    lbsr      wt_at
                    pshs      b
                    ldb       <nwatch
                    subb      ,s+
                    decb
                    lda       #WT.SIZE
                    mul
                    tfr       d,y
cwd1                leay      ,y
                    beq       cwd2
                    lda       WT.SIZE,x
                    sta       ,x+
                    leay      -1,y
                    bra       cwd1
cwd2                dec       <nwatch
                    lbra      w_layout
cwd_all             clr       <nwatch
                    lbra      w_layout
cwd_none            leax      nowatms,pcr
                    stx       <msgp
cwd9                rts
wdeltl              fcn       "Delete watch (its number, 0 = all)"
nowatms             fcn       "No watches"

* ww_draw: the watch window, under the text window: "<n> <expr>: <value>"
ww_draw             pshs      d,x,y,u
                    clr       <bx.col
                    lda       <wtop
                    adda      <wrows
                    inca
                    sta       <bx.row
                    lda       <scrw
                    sta       <bx.w
                    lda       <wwh
                    sta       <bx.h
                    lda       #GL.TL1
                    sta       <bx.st
                    lbsr      fr_on
                    lbsr      bx_draw
                    leax      wttl,pcr
                    lbsr      bx_title
                    lbsr      hl_norm
                    clrb
wwd1                cmpb      <nwatch
                    bhs       wwd9
                    pshs      b
                    lda       #2
                    ldb       <bx.row
                    addb      ,s
                    incb
                    lbsr      t_xy
                    ldu       <base               the line, as wide as the window
                    leau      sbuf,u
                    ldb       <scrw
                    subb      #4
                    leau      b,u
                    lbsr      a_sbuf
                    lda       ,s
                    adda      #'1
                    sta       ,x+
                    lda       #C$SPAC
                    sta       ,x+
                    ldb       ,s
                    lbsr      wt_at
                    pshs      x
                    tfr       x,y
                    ldx       <base
                    leax      sbuf+2,x
                    leay      WT.EXPR,y
                    lbsr      s_lim
                    leay      wsep,pcr
                    lbsr      s_lim
                    puls      y
                    leay      WT.VAL,y
                    lbsr      s_lim
                    clr       ,x
                    lbsr      a_sbuf
                    lbsr      t_str
                    puls      b
                    incb
                    bra       wwd1
wwd9                puls      d,x,y,u,pc
wttl                fcn       "Watch"
wsep                equ       coltx

********************************************************************
* Breakpoints
*
* A breakpoint is a tracked position (bppos) at the carriage return
* ending its line, so it moves with the text: Enter at the end of the
* line leaves it there, Enter at the start moves it down with the text.
* l2b09run holds its own copy, by procedure and line, and forgets it
* at every load and kill; bp_sync sends them all again before the
* program next runs.

* bp_lines: the line of each breakpoint to bpline ($FFFF = unused)
bp_lines            pshs      d,x,y,u
                    ldu       <base
                    leay      bpline,u
                    leau      bppos,u
                    ldb       #MAXBP
bpl1                pshs      b
                    ldd       #$FFFF
                    ldx       ,u
                    beq       bpl2
                    bsr       pos_line
bpl2                std       ,y++
                    leau      4,u
                    puls      b
                    decb
                    bne       bpl1
                    puls      d,x,y,u,pc

* pos_line: D = the line of position U (the carriage returns before it)
pos_line            pshs      x,y,u
                    ldd       #0
                    ldx       <first
pln1                cmpx      ,u                  the pages before its own
                    beq       pln2
                    addd      DS.LINES,x
                    ldx       DS.NEXT,x
                    bne       pln1
                    puls      x,y,u,pc
pln2                pshs      d                   then its own, up to it
                    lbsr      pg_map
                    ldd       2,u
                    leau      d,y
                    puls      x
                    pshs      u
pln3                cmpy      ,s
                    bhs       pln4
                    lda       ,y+
                    cmpa      #C$CR
                    bne       pln3
                    leax      1,x
                    bra       pln3
pln4                leas      2,s
                    tfr       x,d
                    puls      x,y,u,pc

* bp_keep: note the breakpoints' lines (in bpsave), for an edit that
* keeps the line count but replaces whole lines (pretty print)
bp_keep             pshs      d,x,u
                    bsr       bp_lines
                    ldx       <base
                    leau      bpline,x
                    leax      bpsave,x
                    ldb       #MAXBP*2
bpk1                lda       ,u+
                    sta       ,x+
                    decb
                    bne       bpk1
                    puls      d,x,u,pc

* bp_back: the breakpoints back on the lines bp_keep noted (the cursor
* moves: the caller puts it back)
bp_back             ldx       <base
                    leax      bpsave,x
                    ldu       <base
                    leau      bppos,u
                    ldb       #MAXBP
bpb1                pshs      b,x,u
                    ldd       ,x
                    cmpd      #$FFFF
                    beq       bpb2
                    lbsr      goto_line
                    ldu       3,s
                    lbsr      cp_u
                    lbsr      p_eol
bpb2                puls      b,x,u
                    leax      2,x
                    leau      4,u
                    decb
                    bne       bpb1
                    rts

* bp_on: carry if a breakpoint is on line D (by bpline)
bp_on               pshs      d,x
                    ldx       <base
                    leax      bpline,x
                    lda       #MAXBP
                    pshs      a
bpo1                ldd       ,x++
                    cmpd      1,s
                    beq       bpo_yes
                    dec       ,s
                    bne       bpo1
                    leas      1,s
                    andcc     #^Carry
                    puls      d,x,pc
bpo_yes             leas      1,s
                    orcc      #Carry
                    puls      d,x,pc

* bp_del: clear the breakpoints on line D (by bpline); carry if there
* were any
bp_del              pshs      d,x,y,u
                    clr       ,-s                 how many
                    ldu       <base
                    leay      bpline,u
                    leau      bppos,u
                    ldb       #MAXBP
bpd1                ldx       ,y++
                    cmpx      1,s
                    bne       bpd2
                    clr       ,u
                    clr       1,u
                    ldx       #$FFFF
                    stx       -2,y
                    inc       ,s
bpd2                leau      4,u
                    decb
                    bne       bpd1
                    lda       ,s+
                    beq       bpd3
                    inc       <bpdirty
                    orcc      #Carry
                    puls      d,x,y,u,pc
bpd3                andcc     #^Carry
                    puls      d,x,y,u,pc

* bp_clear: no breakpoints (a new text)
bp_clear            pshs      d,x
                    ldx       <base
                    leax      bppos,x
                    ldb       #MAXBP*4
bpc1                clr       ,x+
                    decb
                    bne       bpc1
                    ldb       #MAXBP*2
                    lda       #$FF
bpc2                sta       ,x+
                    decb
                    bne       bpc2
                    inc       <bpdirty
                    puls      d,x,pc

* c_bptog: set or clear a breakpoint on the cursor line (^T)
c_bptog             lbsr      bp_lines
                    ldd       <curline
                    bsr       bp_del
                    bcc       tgl1
                    leax      bpclms,pcr
                    bra       tgl8
tgl1                ldu       <base               a free entry
                    leau      bppos,u
                    ldb       #MAXBP
tgl2                ldx       ,u
                    beq       tgl3
                    leau      4,u
                    decb
                    bne       tgl2
                    leax      nobpms,pcr
                    stx       <msgp
                    rts
tgl3                lbsr      cp_u                at the end of the cursor line
                    lbsr      p_eol
                    inc       <bpdirty
                    leax      bpsetms,pcr
tgl8                stx       <msgp
                    lbra      rd_all
bpsetms             fcn       "Breakpoint set"
bpclms              fcn       "Breakpoint cleared"
nobpms              fcn       "No room for another breakpoint"

* c_bpclr: clear all the breakpoints
c_bpclr             lbsr      bp_clear
                    leax      bpallms,pcr
                    bra       tgl8
bpallms             fcn       "Breakpoints cleared"

* bp_proc: the procedure holding file line D: Y = its entry, D = the
* line in it (1 = the line after PROCEDURE); carry if there is none
bp_proc             pshs      d,x
                    ldy       #0
                    clrb
bpp1                cmpb      <nproc
                    bhs       bpp3
                    lbsr      pt_at
                    pshs      b
                    lda       PR.FLAG,x
                    bita      #PF.SEEN
                    beq       bpp2
                    ldd       PR.LINE,x
                    cmpd      1,s
                    bhs       bpp2                it starts at the line or after it
                    cmpy      #0
                    beq       bpp1a
                    cmpd      PR.LINE,y
                    bls       bpp2                an earlier one than the best so far
bpp1a               tfr       x,y
bpp2                puls      b
                    incb
                    bra       bpp1
bpp3                cmpy      #0
                    beq       bpp_no
                    lda       PR.FLAG,y           a DEFTYPE block is no procedure
                    bita      #PF.DEF
                    bne       bpp_no
                    ldd       ,s
                    subd      PR.LINE,y
                    std       ,s
                    andcc     #^Carry
                    puls      d,x,pc
bpp_no              orcc      #Carry
                    puls      d,x,pc

* bp_cmd: "<command U><procedure> <line>" in rline for file line D;
* carry if that line is not in a procedure l2b09run holds as it is
bp_cmd              pshs      d,y,u
                    bsr       bp_proc
                    bcs       bpm9
                    std       ,s
                    lda       PR.FLAG,y
                    bita      #PF.SEND+PF.ERR
                    bne       bpm_no              changed since it was loaded
                    lbsr      a_rline
                    pshs      y
                    ldy       6,s
                    lbsr      s_str
                    puls      y
                    lbsr      s_str
                    lda       #C$SPAC
                    sta       ,x+
                    ldd       ,s
                    lbsr      n_dec
                    lda       #C$CR
                    sta       ,x
                    andcc     #^Carry
                    puls      d,y,u,pc
bpm_no              orcc      #Carry
bpm9                puls      d,y,u,pc

* bp_ask: send rline (bp or bc) and wait for the answer; Z if
* it was "ok".  Carry if the runtime has gone.
bp_ask              ldx       <base
                    clr       lastout,x
                    lbsr      rt_cmd
                    bcs       bpa9
                    lbsr      rt_wait
                    bcs       bpa9
                    ldx       <base
                    ldd       lastout,x
                    cmpd      #$6F6B              "ok"
                    bne       bpa8
                    tst       lastout+2,x
bpa8                andcc     #^Carry
bpa9                rts

* bp_sync: if the breakpoints changed, send them to l2b09run again ("bc",
* then "bp <procedure> <line>" for each).  The text is scanned first,
* for the procedures' lines as they are now; a procedure changed since
* it was loaded gets none (and is sent at the next Make).  Carry if the
* runtime has gone.
bp_sync             tst       <bpdirty
                    beq       bps8
                    tst       <child
                    beq       bps8
                    lbsr      mk_scan
                    bcs       bps8                (Make says the table is full)
                    lbsr      mk_keep
                    tst       <bprt
                    beq       bps1
                    lbsr      a_rline
                    ldd       #$6263              "bc"
                    std       ,x
                    lda       #C$CR
                    sta       2,x
                    bsr       bp_ask
                    bcs       bps9
                    clr       <bprt
bps1                lbsr      bp_lines
                    ldx       <base
                    leax      bpline,x
                    ldb       #MAXBP
bps2                pshs      b,x
                    ldd       ,x
                    cmpd      #$FFFF
                    beq       bps3
                    leau      bpcm,pcr
                    lbsr      bp_cmd
                    bcs       bps3
                    bsr       bp_ask
                    bcs       bps_gone
                    bne       bps3
                    inc       <bprt
bps3                puls      b,x
                    leax      2,x
                    decb
                    bne       bps2
                    clr       <bpdirty
bps8                andcc     #^Carry
bps9                rts
bps_gone            puls      b,x,pc
bpcm                fcn       "bp "

* bp_tmpclr: after a run to the cursor, its breakpoint has to go: l2b09run
* can only clear them all, so all are sent again before the next run
bp_tmpclr           tst       <bptemp
                    beq       btc9
                    clr       <bptemp
                    inc       <bpdirty
btc9                andcc     #^Carry
                    rts

* c_tocur: run until the program reaches the cursor line (F4): Make, a
* breakpoint there for this run only, then run or continue
c_tocur             lbsr      c_make
                    bcs       ctc9
                    bsr       bp_sync
                    bcs       ctc9
                    lbsr      bp_lines
                    ldd       <curline
                    lbsr      bp_on
                    bcs       ctc_go              one is there already
                    leau      bpcm,pcr
                    lbsr      bp_cmd
                    bcs       ctc_no
                    lbsr      bp_ask
                    bcs       ctc9
                    bne       ctc_no
                    inc       <bprt
                    inc       <bptemp
ctc_go              tst       <dbgon
                    beq       ctc1
                    leax      contcm,pcr
                    lbra      dbg_cmd
ctc1                leax      runcm,pcr
                    lbra      run_first
ctc_no              leax      nolnms,pcr
                    stx       <msgp
ctc9                rts
nolnms              fcn       "The cursor is not on a statement of a loaded procedure"

* c_over: one statement, but a RUN runs the whole call (F8); starts the
* program if it is not running, as F7 does
c_over              tst       <dbgon
                    lbeq      c_stfirst
                    leax      overcm,pcr
                    lbra      dbg_cmd
overcm              fcc       "over"
                    fcb       C$CR
