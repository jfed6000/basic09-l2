********************************************************************
* rt - l2b09run over the pipe protocol (docs/PROTOCOL.md): Make, Run
* and the user screen
*
* The runtime is forked on the first Make, with pipe A on its standard
* input and pipe B on its standard error, and keeps running for the
* rest of the session.  Pipes cannot be polled, so the editor blocks
* while it waits for a reply.
*
* The procedure table says what the runtime holds: each procedure's
* name, and a signature (two sums and the length) of the text it was
* loaded from.  Make scans the text, and sends only the procedures
* whose signature changed, or that had errors, through a temp file and
* one load.  Procedures gone from the text are killed.

MAXPROC             equ       128
NAMEMAX             equ       32                  with the 0
PR.NAME             equ       0
PR.H1               equ       NAMEMAX             signature of the text
PR.H2               equ       NAMEMAX+2
PR.LEN              equ       NAMEMAX+4           and its length
PR.LINE             equ       NAMEMAX+6           line of the PROCEDURE line (0 = first)
PR.PG               equ       NAMEMAX+8           where it starts (during a Make)
PR.OFF              equ       NAMEMAX+10
PR.FLAG             equ       NAMEMAX+12
PR.SIZE             equ       NAMEMAX+13
PF.SEEN             equ       $01                 found by this Make
PF.SEND             equ       $02                 to be loaded
PF.ERR              equ       $04                 the runtime reported an error in it

pipenm              fcc       "/pipe"
                    fcb       C$CR
prognm              fcc       "l2b09run"
                    fcb       C$CR
vtnm                fcc       "/vt"
                    fcb       C$CR
tmpnm               fcc       "l2b09ed.tmp"
                    fcb       C$CR
errnm               fcc       "/dd/sys/errmsg"
                    fcb       C$CR

* rt_init: the signal handler, the protocol log (-l) and the user
* terminal: -t, or a free one from the /vt factory
rt_init             leax      rt_icpt,pcr
                    ldu       <base
                    os9       F$Icpt
                    ldx       <base
                    leax      inbuf,x
                    tst       ,x
                    beq       ri1
                    lbsr      f_new
                    bcs       ri1
                    sta       <lgpath
ri1                 ldx       <base
                    clr       inbuf,x
                    leax      tname,x
                    tst       ,x
                    bne       ri3
                    leax      vtnm,pcr            no -t: ask the factory for one
                    lda       #UPDAT.
                    os9       I$Open
                    bcs       ri9
                    sta       <upath
                    ldx       <base               its name
                    leax      tname+1,x
                    ldb       #SS.DevNm
                    os9       I$GetStt
                    bcs       ri_no
                    ldx       <base
                    leax      tname,x
                    lda       #'/
                    sta       ,x+
ri2                 lda       ,x+
                    bpl       ri2
                    anda      #$7F
                    sta       -1,x
                    clr       ,x
                    bra       ri4
ri3                 lda       #UPDAT.             -t: is it a terminal?
                    os9       I$Open
                    bcs       ri9
                    sta       <upath
ri4                 ldx       <base
                    leax      rline,x
                    lda       <upath
                    clrb                          SS.Opt
                    os9       I$GetStt
                    bcs       ri_no
                    lda       ,x
                    cmpa      #DT.SCF
                    bne       ri_no
                    clr       PD.EKO-PD.OPT,x     no echo on our own path to it
                    lda       <upath
                    clrb
                    os9       I$SetStt
                    inc       <uterm
ri9                 rts
ri_no               lda       <upath              not a terminal: the runtime has it
                    os9       I$Close
                    clr       <upath
                    rts

* rt_icpt: signal handler.  While a program runs, BREAK and abort on the
* user terminal may come to us (the last process to use it); pass them on.
* A signal ends a pipe read that is waiting with E$EOF, as if the pipe
* had ended, so gotsig tells the two apart.
rt_icpt             inc       gotsig,u
                    cmpb      #S$Abort
                    blo       ric9
                    cmpb      #S$Intrpt
                    bhi       ric9
                    tst       running,u
                    beq       ric9
                    lda       child,u
                    beq       ric9
                    os9       F$Send
ric9                rti

* rt_done: stop the runtime, and close and delete what it used
rt_done             bsr       rt_stop
                    leax      tmpnm,pcr
                    os9       I$Delete
                    lda       <upath
                    beq       rd1
                    os9       I$Close
                    clr       <upath
rd1                 lda       <lgpath
                    beq       rd9
                    os9       I$Close
                    clr       <lgpath
rd9                 rts

* rt_stop: end the runtime: q if it is in the debugger, bye, then the
* end of its input
rt_stop             tst       <child
                    lbeq      rp9
                    tst       <dbgon
                    beq       rp0
                    lbsr      dbg_quit
                    lbcs      rp9
rp0                 leax      byecm,pcr
                    lbsr      rt_send
                    lda       <rpa
                    os9       I$Close
                    clr       <rpa
rp1                 lbsr      rt_line             read to the end
                    bcc       rp1
rt_gone             lda       <rpa
                    beq       rg1
                    os9       I$Close
                    clr       <rpa
rg1                 lda       <rpb
                    beq       rg2
                    os9       I$Close
                    clr       <rpb
rg2                 os9       F$Wait              B = its exit status
                    clr       <child
                    lbsr      mk_bpgone
                    clr       <dbgon
                    clr       <nproc              it held nothing
                    clr       <running
                    ldx       <base               "l2b09run has ended [(error <n>)]"
                    leax      mbuf,x
                    stx       <msgp
                    leay      gonems,pcr
                    lbsr      s_str
                    tstb
                    beq       rg3
                    leay      gonerr,pcr
                    lbsr      s_str
                    clra
                    lbsr      n_dec
                    lda       #')
                    sta       ,x+
rg3                 clr       ,x
rp9                 rts
byecm               fcc       "bye"
                    fcb       C$CR

* rt_start: fork the runtime if it is not running; carry (and a message)
* if it could not be started
rt_start            tst       <child
                    lbne      rs_ok
                    ldx       <base
                    tst       tname,x
                    bne       rs1
                    leax      noterm,pcr
                    stx       <msgp
                    orcc      #Carry
                    rts
rs1                 leay      rline,x             its parameters: -t=<term> [-b=<kb>]
                    ldd       #$2D74              "-t"
                    std       ,y++
                    lda       #'=
                    sta       ,y+
                    leax      tname,x
                    lbsr      s_cpy
                    ldx       <base
                    leax      bopt,x
                    tst       ,x
                    beq       rs2
                    ldd       #$202D              " -"
                    std       ,y++
                    ldd       #$623D              "b="
                    std       ,y++
                    lbsr      s_cpy
rs2                 lda       #C$CR
                    sta       ,y+
                    ldx       <base               to the log as "# <parameters>"
                    leax      rline,x
                    lda       #'#
                    lbsr      lg_line
                    clr       <rpa
                    clr       <rpb
                    clra                          set our paths 0 and 2 aside
                    os9       I$Dup
                    lbcs      rs_err
                    pshs      a
                    lda       #2
                    os9       I$Dup
                    bcc       rs3
                    puls      a
                    os9       I$Close
                    lbra      rs_err
rs3                 pshs      a                   1,s = our 0, ,s = our 2
                    clra                          pipe A becomes path 0
                    os9       I$Close
                    leax      pipenm,pcr
                    lda       #UPDAT.
                    os9       I$Open
                    bcs       rs_back
                    clra
                    os9       I$Dup
                    bcs       rs_back
                    sta       <rpa
                    lda       #2                  pipe B becomes path 2
                    os9       I$Close
                    leax      pipenm,pcr
                    lda       #UPDAT.
                    os9       I$Open
                    bcs       rs_back
                    lda       #2
                    os9       I$Dup
                    bcs       rs_back
                    sta       <rpb
                    ldx       <base               parameter length, the CR included
                    leax      rline,x
                    ldy       #0
rs4                 leay      1,y
                    lda       ,x+
                    cmpa      #C$CR
                    bne       rs4
                    ldu       <base
                    leau      rline,u
                    leax      prognm,pcr
                    clra
                    ldb       <rtmem
                    os9       F$Fork
                    bcs       rs_back
                    sta       <child
                    clrb
rs_back             tfr       cc,a                put our own paths back
                    pshs      d
                    clra
                    os9       I$Close
                    lda       3,s
                    os9       I$Dup
                    lda       3,s
                    os9       I$Close
                    lda       #2
                    os9       I$Close
                    lda       2,s
                    os9       I$Dup
                    lda       2,s
                    os9       I$Close
                    puls      d
                    leas      2,s
                    tfr       a,cc
                    bcc       rs5
                    pshs      b                   failed: drop what was opened
                    lda       <rpa
                    beq       rs_e1
                    os9       I$Close
rs_e1               lda       <rpb
                    beq       rs_e2
                    os9       I$Close
rs_e2               clr       <rpa
                    clr       <rpb
                    puls      b
                    bra       rs_err
rs5                 lbsr      rt_wait             its banner, then %READY
                    bcs       rs_gone
rs_ok               andcc     #^Carry
                    rts
rs_err              stb       <msgerr
                    orcc      #Carry
                    rts
rs_gone             orcc      #Carry
                    rts

noterm              fcn       "No terminal for the program (use -t=)"
gonems              fcn       "l2b09run has ended"
gonerr              fcn       " (error "

* s_cpy: copy the string at X (ending in 0) to Y; Y at its end
s_cpy               lda       ,x+
                    beq       sc9a
                    sta       ,y+
                    bra       s_cpy
sc9a                rts

* f_new: create file X (replacing it) for writing; A = the path, carry
* (B = error) on failure
f_new               pshs      x
                    os9       I$Delete
                    puls      x
                    lda       #WRITE.
                    ldb       #PREAD.+UPDAT.
                    os9       I$Create
                    rts

********************************************************************
* The protocol

* rt_cmd: send the command in rline (ending in CR); carry if the
* runtime has gone
rt_cmd              ldx       <base
                    leax      rline,x
                    lda       #'>
                    bsr       lg_line
                    ldy       #256
                    lda       <rpa
                    os9       I$WritLn
                    bcs       rw_gone
                    rts

* rt_line: read a line from the runtime into rline; carry at its end
rt_line             clr       <gotsig
                    ldx       <base
                    leax      rline,x
                    ldy       #256
                    lda       <rpb
                    os9       I$ReadLn
                    bcc       rl1
                    tst       <gotsig             a signal broke the wait: again
                    bne       rt_line
                    orcc      #Carry
                    rts
rl1                 lda       #'<
* lg_line: the line at X (ending in CR) to the log, after A and a space
lg_line             pshs      d,x,y
                    ldb       <lgpath
                    beq       lg9
                    ldb       #C$SPAC
                    pshs      d
                    leax      ,s
                    ldy       #2
                    lda       <lgpath
                    os9       I$Write
                    leas      2,s
                    ldx       2,s
                    ldy       #256
                    lda       <lgpath
                    os9       I$WritLn
lg9                 andcc     #^Carry
                    puls      d,x,y,pc

* rt_wait: read the runtime's output up to %READY, or a stop in the
* debugger (%DEBUG: dbgon, dbname, dbline and dbfl).  Errors go to the
* message window, unless quiet is set.  The last line of text is kept
* in lastout.  Carry if the runtime has gone.
rt_wait             clr       <evcode
rw1                 bsr       rt_line
                    bcc       rw1a
rw_gone             lbsr      rt_gone
                    orcc      #Carry
                    rts
rw1a
                    ldx       <base
                    leax      rline,x
                    lda       ,x+
                    cmpa      #'%
                    lbne      rw_text
                    leay      ev_rdy,pcr
                    lbsr      ev_is
                    bne       rw2
                    clr       <dbgon
                    andcc     #^Carry
                    rts
rw2                 leay      ev_err,pcr
                    lbsr      ev_is
                    bne       rw3
                    tst       <quiet              an error in print: the ERROR line says it
                    bne       rw1
                    lbsr      ev_code
                    lbsr      ms_ev
                    bra       rw1
rw3                 leay      ev_cerr,pcr
                    lbsr      ev_is
                    beq       rw3a
                    leay      ev_berr,pcr
                    lbsr      ev_is
                    bne       rw4
rw3a                lbsr      ev_code
                    ldy       <evproc             load it again next time
                    lbsr      pt_find
                    bcs       rw3b
                    lda       PR.FLAG,y
                    ora       #PF.ERR
                    sta       PR.FLAG,y
rw3b                lbsr      ms_ev
                    inc       <nerr
                    bra       rw1
rw4                 leay      ev_dbg,pcr
                    lbsr      ev_is
                    bne       rw5
                    lbsr      ev_where
                    lbra      dbg_at
rw5                 leay      ev_ask,pcr
                    lbsr      ev_is
                    lbne      rw1
                    pshs      x                   the question, as a 0-terminated string
rw5a                lda       ,x+
                    cmpa      #C$CR
                    bne       rw5a
                    clr       -1,x
                    puls      x
                    lbsr      dlg_ask
                    ldb       #'n
                    bcs       rw5b
                    cmpa      #'Y
                    bne       rw5b
                    ldb       #'y
rw5b                ldx       <base
                    leax      rline,x
                    lda       #C$CR
                    stb       ,x
                    sta       1,x
                    lbsr      rt_cmd
                    lbra      rw1
rw_text             leax      -1,x                keep it, and count "ERROR #" lines
                    lbsr      out_keep            (a load failure has one without an
rwt1                leay      errtx,pcr           event)
                    pshs      x
rwt2                lda       ,y+
                    beq       rwt_hit
                    cmpa      ,x+
                    beq       rwt2
                    puls      x
                    lda       ,x+
                    cmpa      #C$CR
                    bne       rwt1
                    lbra      rw1
rwt_hit             leas      2,s
                    lbsr      getnum
                    stb       <lderr
                    inc       <nerrl
                    lbra      rw1

errtx               fcn       "ERROR #"
ev_rdy              fcn       "READY"
ev_err              fcn       "ERROR "
ev_cerr             fcn       "CERR "
ev_berr             fcn       "BERR "
ev_dbg              fcn       "DEBUG "
ev_ask              fcn       "ASK "

* ev_is: Z if the event at X is Y (then X is past it)
ev_is               pshs      x
evi1                lda       ,y+
                    beq       evi_yes
                    cmpa      ,x+
                    beq       evi1
                    puls      x,pc                Z clear from the compare
evi_yes             leas      2,s
                    orcc      #Zero
                    rts

* ev_code: "<code> <proc> <line>" at X -> evcode, evproc, evline
ev_code             lbsr      getnum
                    stb       <evcode
                    leax      1,x
* ev_where: "<proc> <line>" at X -> evproc, evline
ev_where            stx       <evproc
evw1                lda       ,x+
                    cmpa      #C$SPAC
                    beq       evw2
                    cmpa      #C$CR
                    bne       evw1
                    clr       -1,x                no line
                    ldd       #0
                    std       <evline
                    rts
evw2                clr       -1,x
                    lbsr      getnum
                    std       <evline
                    rts


********************************************************************
* Messages from events

* ms_ev: a message for the error event in evcode, evproc and evline:
* "Line <n>, <proc>: Error <code> <text>"
ms_ev               lbsr      ms_new
                    bcs       mse9
                    pshs      x                   ,s = the message
                    ldy       <evproc
                    lbsr      pt_find
                    leax      MS.TEXT,x
                    bcs       mse2                not one of ours: no line
                    ldd       PR.LINE,y
                    addd      <evline
                    ldy       ,s
                    std       MS.LINE,y
                    pshs      d
                    leay      linetx,pcr
                    lbsr      s_str
                    puls      d
                    addd      #1
                    lbsr      n_dec
                    ldd       #$2C20              ", "
                    std       ,x++
mse2                ldy       <evproc             the name (at most NAMEMAX-1)
                    ldb       #NAMEMAX-1
mse3                lda       ,y+
                    beq       mse4
                    sta       ,x+
                    decb
                    bne       mse3
mse4                ldd       #$3A20              ": "
                    std       ,x++
                    leay      errtx2,pcr
                    lbsr      s_str
                    clra
                    ldb       <evcode
                    lbsr      n_dec
                    ldu       ,s                  the text ends with the message
                    leau      MS.SIZE-1,u
                    bsr       er_text
                    clr       ,x
                    puls      x
mse9                rts

linetx              fcn       "Line "
errtx2              fcn       "Error "

* er_text: " <text>" for error evcode, from the error message file, at
* X but not past U; X at its end
er_text             pshs      y,u
                    pshs      x
                    leax      errnm,pcr
                    lda       #READ.
                    os9       I$Open
                    puls      x
                    bcs       et9
                    pshs      a                   ,s = the path, 3,s = the limit
et1                 pshs      x
                    ldx       <base
                    leax      rline,x
                    ldy       #200
                    lda       2,s
                    os9       I$ReadLn
                    bcs       et7
                    lbsr      getnum              "<code> - <text>" or "<code> -- <text>"
                    tsta
                    bne       et_no
                    cmpb      <evcode
                    bne       et_no
et2                 lda       ,x
                    cmpa      #C$SPAC
                    beq       et3
                    cmpa      #'-
                    bne       et4
et3                 leax      1,x
                    bra       et2
et4                 tfr       x,y
                    puls      x
                    lda       #C$SPAC
                    sta       ,x+
et5                 cmpx      3,s
                    bhs       et8
                    lda       ,y+
                    cmpa      #C$CR
                    beq       et8
                    sta       ,x+
                    bra       et5
et_no               puls      x
                    bra       et1
et7                 puls      x
et8                 puls      a
                    os9       I$Close
et9                 puls      y,u,pc

********************************************************************
* The procedure table

* pt_at: X = entry B
pt_at               pshs      d
                    lda       #PR.SIZE
                    mul
                    addd      #ptab
                    addd      <base
                    tfr       d,x
                    puls      d,pc

* pt_find: Y = the entry named by the string at Y; carry if there is none
pt_find             pshs      d,x
                    clrb
pf1                 cmpb      <nproc
                    bhs       pf_no
                    bsr       pt_at
                    pshs      y
pf2                 lda       ,x+
                    cmpa      ,y+
                    bne       pf3
                    tsta
                    bne       pf2
                    puls      y
                    bsr       pt_at
                    tfr       x,y
                    andcc     #^Carry
                    puls      d,x,pc
pf3                 puls      y
                    incb
                    bra       pf1
pf_no               orcc      #Carry
                    puls      d,x,pc

* pt_add: Y = a new entry named nbuf; carry if the table is full
pt_add              ldb       <nproc
                    cmpb      #MAXPROC
                    bhs       pad_full
                    bsr       pt_at
                    inc       <nproc
                    pshs      x
                    ldy       <base
                    leay      nbuf,y
pad1                lda       ,y+
                    sta       ,x+
                    bne       pad1
                    puls      y
                    ldd       #0
                    std       PR.H1,y
                    std       PR.H2,y
                    std       PR.LEN,y
                    clr       PR.FLAG,y
                    andcc     #^Carry
                    rts
pad_full            orcc      #Carry
                    rts

* pt_flags: clear flags A in every entry
pt_flags            coma
                    pshs      a
                    clrb
ptf1                cmpb      <nproc
                    bhs       ptf9
                    bsr       pt_at
                    lda       PR.FLAG,x
                    anda      ,s
                    sta       PR.FLAG,x
                    incb
                    bra       ptf1
ptf9                puls      a,pc

********************************************************************
* Make

* c_make: load the procedures that changed (^B); carry if it failed or
* found errors
c_make              leax      makems,pcr
                    stx       <msgp
                    clr       <msgerr
                    lbsr      v_hint
                    lbsr      t_flush
                    lbsr      rt_start
                    bcc       cm1
                    rts
cm1                 lbsr      ms_clear
                    lbsr      w_hide
                    clr       <nsend
                    lbsr      mk_scan
                    bcc       cm2
                    leax      manyms,pcr
                    stx       <msgp
                    rts
cm2                 lbsr      mk_dbg              stopped in the debugger?
                    bcs       cm_gone
                    tstb
                    bne       cm_keep
                    lbsr      mk_sweep            kill what is gone
                    bcs       cm_gone
                    lbsr      mk_write            the temp file
                    bcc       cm3
                    stb       <msgerr
                    clr       <msgp
                    clr       <msgp+1
                    rts
cm3                 tst       <nsend
                    beq       cm5
                    clr       <nerr
                    clr       <nerrl
                    lbsr      mk_bpgone
                    leax      ldcmd,pcr
                    lbsr      rt_send
                    bcs       cm_gone
                    lbsr      rt_wait
                    bcs       cm_gone
                    ldb       <nerrl              an error without an event: the
                    cmpb      <nerr               load failed as a whole
                    bls       cm5
                    lbsr      mk_lderr
cm5                 lda       #PF.SEND
                    lbsr      pt_flags
                    ldx       <base               the result
                    leax      mbuf,x
                    stx       <msgp
                    leay      makeds,pcr
                    lbsr      s_str
                    clra
                    ldb       <nmsg
                    beq       cm6
                    lbsr      n_dec
                    leay      errsms,pcr
                    lbsr      s_str
                    clr       ,x
                    lbsr      w_show
                    clrb
                    lbsr      ms_jump
                    orcc      #Carry
                    rts
cm6                 ldb       <nsend
                    beq       cm7
                    lbsr      n_dec
                    leay      loadms,pcr
cm7                 bne       cm8
                    leay      uptdms,pcr
cm8                 lbsr      s_str
                    clr       ,x
                    andcc     #^Carry
                    rts
cm_gone             orcc      #Carry
                    rts
cm_keep             leax      keptms,pcr
                    stx       <msgp
                    andcc     #^Carry
                    rts

makems              fcn       "Making..."
manyms              fcn       "Too many procedures"
makeds              fcn       "Make: "
errsms              fcn       " error(s)"
loadms              fcn       " loaded"
uptdms              fcn       "up to date"
keptms              fcn       "Not loaded: the program is stopped (^P resets it)"
rstask              fcn       "The text changed: reset the program (Y/N)?"

* mk_dbg: if the program is stopped in the debugger and the text changed,
* the program has to be reset (q) before anything is loaded: ask.  B = 1
* for no (nothing is loaded, and the changed procedures are sent next
* time), else 0.  Carry to give up: Esc, or the runtime has gone.
mk_dbg              clrb
                    tst       <dbgon
                    beq       mkd9
                    bsr       mk_dirty
                    beq       mkd9
                    leax      rstask,pcr
                    lbsr      dlg_ask
                    bcs       mkd_esc
                    cmpa      #'Y
                    bne       mkd_no
                    lbsr      dbg_quit
                    ldb       #0                  (keeps the carry)
                    rts
mkd_no              bsr       mk_keep
                    ldb       #1
mkd9                andcc     #^Carry
                    rts
mkd_esc             bsr       mk_keep
                    orcc      #Carry
                    rts

* mk_dirty: Z clear if Make has something to send or kill
mk_dirty            clrb
mdy1                cmpb      <nproc
                    bhs       mdy_no
                    lbsr      pt_at
                    lda       PR.FLAG,x
                    bita      #PF.SEND
                    bne       mdy_yes
                    bita      #PF.SEEN
                    beq       mdy_yes
                    incb
                    bra       mdy1
mdy_no              orcc      #Zero
                    rts
mdy_yes             andcc     #^Zero
                    rts

* mk_keep: nothing is sent this time: mark what was to be sent as
* failed, so the next Make sends it
mk_keep             clrb
mkp1                cmpb      <nproc
                    bhs       mkp9
                    lbsr      pt_at
                    lda       PR.FLAG,x
                    bita      #PF.SEND
                    beq       mkp2
                    anda      #^PF.SEND
                    ora       #PF.ERR
                    sta       PR.FLAG,x
mkp2                incb
                    bra       mkp1
mkp9                rts
ldcmd               fcc       "load l2b09ed.tmp"
                    fcb       C$CR

* mk_lderr: the load failed without saying where: a message, and every
* procedure sent is sent again next time
mk_lderr            lda       #PF.SEND
                    clrb
mle1                cmpb      <nproc
                    bhs       mle2
                    lbsr      pt_at
                    lda       PR.FLAG,x
                    bita      #PF.SEND
                    beq       mle1a
                    ora       #PF.ERR
                    sta       PR.FLAG,x
mle1a               incb
                    bra       mle1
mle2                lbsr      ms_new
                    bcs       mle9
                    pshs      x
                    leax      MS.TEXT,x
                    leay      lderms,pcr
                    lbsr      s_str
                    clra
                    ldb       <lderr
                    stb       <evcode
                    lbsr      n_dec
                    ldu       ,s
                    leau      MS.SIZE-1,u
                    lbsr      er_text
                    clr       ,x
                    puls      x
mle9                rts
lderms              fcn       "Load: Error "

* mk_scan: find the procedures in the text and their signatures; mark
* those to send.  Carry if the table is full.
mk_scan             lda       #PF.SEEN+PF.SEND
                    lbsr      pt_flags
                    ldd       <first
                    std       <mkp
                    ldd       #0
                    std       <mkp+2
                    std       <mkln
                    std       <curp
                    std       <h1
                    std       <h2
                    std       <hlen
mks1                lbsr      mk_isproc
                    bcs       mks2
                    bsr       mk_close
                    ldy       <base
                    leay      nbuf,y
                    lbsr      pt_find
                    bcc       mks1a
                    lbsr      pt_add
                    bcs       mks9
mks1a               lda       PR.FLAG,y
                    ora       #PF.SEEN
                    sta       PR.FLAG,y
                    ldd       <mkln
                    std       PR.LINE,y
                    ldd       <mkp
                    std       PR.PG,y
                    ldd       <mkp+2
                    std       PR.OFF,y
                    sty       <curp
                    ldd       #0
                    std       <h1
                    std       <h2
                    std       <hlen
mks2                lbsr      mk_line
                    bcs       mks8
                    ldd       <mkln
                    addd      #1
                    std       <mkln
                    bra       mks1
mks8                bsr       mk_close
                    andcc     #^Carry
mks9                rts

* mk_close: the procedure being scanned is complete: send it if its
* signature changed or it had errors
mk_close            ldy       <curp
                    beq       mc9
                    ldd       <h1
                    cmpd      PR.H1,y
                    bne       mc1
                    ldd       <h2
                    cmpd      PR.H2,y
                    bne       mc1
                    ldd       <hlen
                    cmpd      PR.LEN,y
                    bne       mc1
                    lda       PR.FLAG,y
                    bita      #PF.ERR
                    beq       mc9
mc1                 ldd       <h1
                    std       PR.H1,y
                    ldd       <h2
                    std       PR.H2,y
                    ldd       <hlen
                    std       PR.LEN,y
                    lda       PR.FLAG,y
                    anda      #^PF.ERR
                    ora       #PF.SEND
                    sta       PR.FLAG,y
mc9                 rts

* mk_isproc: if the line at mkp is "PROCEDURE <name>" (any case, spaces
* before it), the name to nbuf; carry if it is not
mk_isproc           ldu       <base
                    leau      wp,u
                    ldd       <mkp
                    std       ,u
                    ldd       <mkp+2
                    std       2,u
mip1                 lbsr      p_char
                    bcs       mip_no
                    cmpa      #C$SPAC
                    bne       mip2
                    lbsr      p_next
                    bra       mip1
mip2                 leay      prockw,pcr
mip3                 lda       ,y+
                    beq       mip4
                    pshs      a
                    lbsr      p_char
                    bcs       mip_no1
                    anda      #$DF
                    cmpa      ,s+
                    bne       mip_no
                    lbsr      p_next
                    bra       mip3
mip_no1              leas      1,s
mip_no               orcc      #Carry
                    rts
mip4                 lbsr      p_char
                    bcs       mip_no
                    cmpa      #C$SPAC
                    bne       mip_no
mip5                 lbsr      p_next
                    lbsr      p_char
                    bcs       mip_no
                    cmpa      #C$SPAC
                    beq       mip5
                    ldx       <base
                    leax      nbuf,x
                    ldb       #NAMEMAX-1
mip6                 lbsr      p_char
                    bcs       mip7
                    lbsr      is_word
                    bcc       mip7
                    sta       ,x+
                    lbsr      p_next
                    decb
                    bne       mip6
mip7                 clr       ,x
                    cmpb      #NAMEMAX-1
                    beq       mip_no               no name
                    andcc     #^Carry
                    rts
prockw              fcn       "PROCEDURE"

* mk_line: add the line at mkp to the signature (h1 = sum of the bytes,
* h2 = sum of the h1s, hlen = length) and move mkp past its carriage
* return; carry if the text ended in it
mk_line             ldx       <mkp
mkl0                 lbsr      pg_map              Y = the page's data
                    pshs      y                   4,s: its start
                    ldd       DS.USED,x
                    leau      d,y
                    pshs      u                   2,s: its end
                    ldd       <mkp+2
                    leay      d,y
                    pshs      y                   ,s: where this scan started
mkl1                 cmpy      2,s
                    bhs       mkl_pend
                    ldb       ,y+
                    clra
                    addd      <h1
                    std       <h1
                    addd      <h2
                    std       <h2
                    lda       -1,y
                    cmpa      #C$CR
                    bne       mkl1
                    bsr       mkl_len
                    tfr       y,d
                    subd      4,s
                    leas      6,s
                    cmpd      DS.USED,x
                    blo       mkl2
                    ldu       DS.NEXT,x           past the page: the next one's start
                    beq       mkl2
                    stu       <mkp
                    ldd       #0
mkl2                 std       <mkp+2
                    andcc     #^Carry
                    rts
mkl_pend             bsr       mkl_len              the page ended within the line
                    leas      6,s
                    ldd       DS.NEXT,x
                    beq       mkl_eot
                    std       <mkp
                    tfr       d,x
                    ldd       #0
                    std       <mkp+2
                    bra       mkl0
mkl_eot              ldd       DS.USED,x
                    std       <mkp+2
                    orcc      #Carry
                    rts
mkl_len              tfr       y,d                 hlen += Y - the scan start
                    subd      2,s
                    addd      <hlen
                    std       <hlen
                    rts

* mk_sweep: kill the procedures that were not found, and drop them from
* the table; carry if the runtime has gone
mk_sweep            clra                          A = entries kept
                    clrb                          B = entry
msw1                cmpb      <nproc
                    bhs       msw9
                    lbsr      pt_at
                    pshs      d
                    lda       PR.FLAG,x
                    bita      #PF.SEEN
                    bne       msw2
                    bsr       mk_kill
                    puls      d
                    bcs       msw8
                    incb
                    bra       msw1
msw2                lda       ,s                  keep it: move it down
                    cmpa      1,s
                    beq       msw4
                    tfr       x,y
                    tfr       a,b
                    lbsr      pt_at
                    ldb       #PR.SIZE
msw3                lda       ,y+
                    sta       ,x+
                    decb
                    bne       msw3
msw4                puls      d
                    inca
                    incb
                    bra       msw1
msw9                sta       <nproc
                    andcc     #^Carry
msw8                rts

* mk_bpgone: l2b09run forgets its breakpoints at a load or kill
mk_bpgone           tst       <bprt
                    beq       mbg9
                    clr       <bprt
                    inc       <bpdirty
mbg9                rts

* mk_kill: "kill <name>" for entry X; carry if the runtime has gone
mk_kill             bsr       mk_bpgone
                    ldy       <base
                    leay      rline,y
                    pshs      x
                    leax      killcm,pcr
                    lbsr      s_cpy
                    puls      x
                    lbsr      s_cpy
                    lda       #C$CR
                    sta       ,y
                    lbsr      rt_cmd
                    bcs       mkk9
                    lbra      rt_wait
mkk9                rts
killcm              fcn       "kill "

* mk_write: the procedures to send, to the temp file; nsend = how many.
* Carry (B = error) if it could not be written.
mk_write            leax      tmpnm,pcr
                    lbsr      f_new
                    bcs       mw9
                    sta       <flpath
                    clrb
mw1                 cmpb      <nproc
                    bhs       mw8
                    lbsr      pt_at
                    lda       PR.FLAG,x
                    bita      #PF.SEND
                    beq       mw2
                    pshs      b
                    bsr       mk_wproc
                    bcs       mw_err
                    puls      b
                    inc       <nsend
mw2                 incb
                    bra       mw1
mw8                 lda       <flpath
                    os9       I$Close
mw9                 rts
mw_err              leas      1,s
                    pshs      b
                    lda       <flpath
                    os9       I$Close
                    puls      b
                    orcc      #Carry
                    rts

* mk_wproc: write the text of entry X, ending it with a carriage return
mk_wproc            ldd       PR.LEN,x
                    std       <tmpc
                    ldd       PR.PG,x
                    std       <wp
                    ldd       PR.OFF,x
                    std       <wp+2
                    clr       ,-s                 the last byte written
mwp1                ldd       <tmpc
                    beq       mwp8
                    ldx       <wp
                    lbsr      pg_map
                    ldd       DS.USED,x           bytes left in this page
                    subd      <wp+2
                    beq       mwp_next
                    cmpd      <tmpc
                    bls       mwp2
                    ldd       <tmpc
mwp2                std       <tmp
                    ldd       <wp+2
                    leay      d,y
                    ldd       <tmp
                    leau      d,y
                    lda       -1,u
                    sta       ,s
                    pshs      x
                    tfr       y,x
                    ldy       <tmp
                    lda       <flpath
                    os9       I$Write
                    puls      x
                    bcs       mwp_err
                    ldd       <tmpc
                    subd      <tmp
                    std       <tmpc
                    ldd       <wp+2
                    addd      <tmp
                    std       <wp+2
                    bra       mwp1
mwp_next            ldd       DS.NEXT,x
                    beq       mwp8
                    std       <wp
                    ldd       #0
                    std       <wp+2
                    bra       mwp1
mwp8                lda       ,s+
                    cmpa      #C$CR
                    beq       mwp9
                    leax      crbyte,pcr
                    ldy       #1
                    lda       <flpath
                    os9       I$Write
                    rts
mwp9                andcc     #^Carry
                    rts
mwp_err             leas      1,s
                    rts
crbyte              fcb       C$CR

* rt_send: send command X (ending in CR); carry if the runtime has gone
rt_send             ldy       <base
                    leay      rline,y
rsd1                lda       ,x+
                    sta       ,y+
                    cmpa      #C$CR
                    bne       rsd1
                    lbra      rt_cmd

********************************************************************
* Run and the user screen

* c_run: Make, then run the first procedure in the text (^R), or
* continue the program if it is stopped in the debugger.  Its terminal
* is shown while it runs.
c_run               lbsr      c_make
                    bcs       crn9
                    tst       <dbgon
                    beq       crn0
                    leax      contcm,pcr
                    lbra      dbg_cmd
crn0                leax      runcm,pcr
* run_first: "<command X> <the first procedure in the text>" (run, or
* step to stop at its first statement), then as dbg_go
run_first           pshs      x
                    lbsr      bp_sync
                    bcs       crn8
                    ldb       <nproc
                    bne       crn1
                    leax      noprms,pcr
                    stx       <msgp
crn8                puls      x
crn9                rts
crn1                clrb                          the entry with the lowest line
                    lbsr      pt_at
                    tfr       x,y
crn2                incb
                    cmpb      <nproc
                    bhs       crn3
                    lbsr      pt_at
                    ldd       PR.LINE,x
                    cmpd      PR.LINE,y
                    bhs       crn2
                    tfr       x,y
                    bra       crn2
crn3                ldx       <base               "run <name>"
                    leax      rline,x
                    exg       x,y
                    pshs      x
                    ldx       2,s
                    lbsr      s_cpy
                    puls      x
                    lbsr      s_cpy
                    leas      2,s
                    lda       #C$CR
                    sta       ,y
                    lbra      dbg_go
noprms              fcn       "No procedures"
runcm               fcn       "run "
contcm              fcc       "cont"
                    fcb       C$CR

* u_show: show the program's terminal
u_show              tst       <uterm
                    beq       ush9
                    leax      selwin,pcr
                    ldy       #2
                    lda       <upath
                    os9       I$Write
ush9                rts

* u_back: show ours again
u_back              tst       <uterm
                    beq       ubk9
                    lbsr      t_flush
                    leax      selwin,pcr
                    ldy       #2
                    lda       <scpath
                    os9       I$Write
                    lbra      rd_all
ubk9                rts
selwin              fcb       $1B,$21             select this terminal

* c_user: show the program's terminal until a key is pressed (F5)
c_user              tst       <uterm
                    bne       cus1
                    leax      nousms,pcr
                    stx       <msgp
                    rts
cus1                lbsr      t_flush
                    bsr       u_show
                    tst       <kbterm
                    beq       cus3
cus2                clr       <gotsig             the key goes to that terminal
                    ldx       <base
                    leax      kraw,x
                    ldy       #1
                    lda       <upath
                    os9       I$Read
                    bcc       cus4
                    tst       <gotsig             a signal (BREAK): again
                    bne       cus2
                    bra       cus4
cus3                lbsr      getkey
cus4                bra       u_back
nousms              fcn       "No user screen"
