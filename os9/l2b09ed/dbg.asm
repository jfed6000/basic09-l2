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
dbg_quit            ldx       <base
                    leax      rline,x
                    ldd       #$710D              "q", CR
                    std       ,x
                    lbsr      rt_cmd
                    bcs       dq9
                    lbra      rt_wait
dq9                 rts

* dbg_cmd: run command X (ending in CR) as dbg_go does
dbg_cmd             ldy       <base
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
                    bcs       dg9
                    inc       <running
                    lbsr      u_show
                    lbsr      rt_wait
                    pshs      cc
                    clr       <running
                    lbsr      u_back
                    puls      cc
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
                    ldx       <base               not in the text: say where
                    leax      mbuf,x
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

* c_step: one statement, into a called procedure (F7)
c_step              tst       <dbgon
                    beq       c_notst
                    leax      stepcm,pcr
                    lbra      dbg_cmd
stepcm              fcc       "step"
                    fcb       C$CR

c_notst             leax      notstms,pcr
                    stx       <msgp
                    rts
notstms             fcn       "The program is not stopped (PAUSE or BREAK stops it)"

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
rstms               fcn       "Program reset"

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
                    ldx       <base
                    leax      mbuf,x
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
                    ldd       <cpos
                    std       ,u
                    ldd       <cpos+2
                    std       2,u
wa1                 lbsr      p_prev              back to its start
                    bcs       wa2
                    lbsr      p_char
                    lbsr      is_word
                    bcs       wa1
                    lbsr      p_next
wa2                 ldx       <base
                    leax      inbuf,x
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
                    ldx       <base
                    leax      inbuf,x
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
cev3                ldx       <base               an assignment?
                    leax      inbuf,x
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
                    ldy       <base
                    leay      inbuf,y
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
                    ldy       <base
                    leay      inbuf,y
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
                    ldx       <base
                    leax      sbuf,x
                    ldy       <base
                    leay      inbuf,y
                    bsr       s_lim
                    puls      y
                    bsr       s_lim
                    ldy       <base
                    leay      lastout,y
                    bsr       s_lim
                    clr       ,x
                    ldx       <base
                    leax      sbuf,x
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
                    ldy       <base
                    leay      inbuf,y
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
                    ldy       <base
                    leay      inbuf,y
                    tst       ,y
                    beq       cwa9
                    ldb       <nwatch
                    lbsr      wt_at
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
                    ldx       <base
                    leax      inbuf,x
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
                    lbsr      bx_draw
                    leax      wttl,pcr
                    lbsr      bx_title
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
                    ldx       <base
                    leax      sbuf,x
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
                    ldx       <base
                    leax      sbuf,x
                    lbsr      t_str
                    puls      b
                    incb
                    bra       wwd1
wwd9                puls      d,x,y,u,pc
wttl                fcn       "Watch"
wsep                fcn       ": "
