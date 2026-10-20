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
PF.USE              equ       $08                 it has a USE line
PF.DEF              equ       $10                 a DEFTYPE block, not a procedure

pipenm              fcc       "/pipe"
                    fcb       C$CR
prognm              fcc       "l2b09run"
                    fcb       C$CR
vtnm                fcc       "/vt"
                    fcb       C$CR
tmpnm               equ       ldcmd+5             "basic09-l2.tmp", CR
errnm               fcc       "/dd/sys/errmsg"
                    fcb       C$CR

* rt_init: the signal handler, the protocol log (-l) and the user
* terminal: -t, or a free one from the /vt factory
rt_init             leax      rt_icpt,pcr
                    ldu       <base
                    os9       F$Icpt
                    lbsr      a_inbx
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
ri4                 lbsr      a_rline
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
                    beq       rp9
                    tst       <dbgon
                    beq       rp0
                    lbsr      dbg_quit
                    bcs       rp9
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
                    lbsr      a_mbuf              "l2b09run has ended [(error <n>)]"
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
                    lbsr      a_rline             to the log as "# <parameters>"
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
                    lbsr      a_rline             parameter length, the CR included
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
rt_cmd              lbsr      a_rline
                    lda       #'>
                    bsr       lg_line
                    ldy       #256
                    lda       <rpa
                    os9       I$WritLn
                    bcs       rw_gone
                    rts

* rt_line: read a line from the runtime into rline; carry at its end
rt_line             clr       <gotsig
                    lbsr      a_rline
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
                    ldx       <base
                    clr       colhnt,x
rw1                 bsr       rt_line
                    bcc       rw1a
rw_gone             lbsr      rt_gone
                    orcc      #Carry
                    rts
rw1a
                    lbsr      a_rline
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
rw5                 leay      ev_inp,pcr
                    lbsr      ev_is
                    bne       rw5i
                    lbsr      u_inp               it waits for INPUT: show its screen
                    lbra      rw1
rw5i                leay      ev_ask,pcr
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
rw5b                lbsr      a_rline
                    lda       #C$CR
                    stb       ,x
                    sta       1,x
                    lbsr      rt_cmd
                    lbra      rw1
rw_text             leax      -1,x                keep it, and count "ERROR #" lines
                    lbsr      col_chk             (before out_keep: the line before)
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
                    cmpb      #B9.MEMF            memory full, at any point
                    bne       rwt3
                    ldx       <base
                    inc       memful,x
rwt3                inc       <nerrl
                    lbra      rw1

errtx               fcn       "ERROR #"
ev_rdy              fcn       "READY"
ev_err              fcn       "ERROR "
ev_cerr             fcn       "CERR "
ev_berr             fcn       "BERR "
ev_dbg              fcn       "DEBUG "
ev_ask              fcn       "ASK "
ev_inp              fcn       "INPUT"

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
                    ldy       <base               "<line> <n>": the n+1th statement
                    clr       evstm,y             on the line (none: the first)
                    lda       ,x
                    cmpa      #C$SPAC
                    bne       evw9
                    leax      1,x
                    lbsr      getnum
                    ldy       <base
                    stb       evstm,y
evw9                rts


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
                    ldy       <base
                    tst       colhnt,y            or with a hint, if the error is at
                    beq       mse5                a ":" (col_chk)
                    clr       colhnt,y
                    leay      colhtx,pcr
                    lbsr      s_str
                    bra       mse6
mse5                bsr       er_text
mse6                equ       *
                    clr       ,x
                    puls      x
mse9                rts

colhtx              fcn       " - use \ between statements, not :"

* col_chk: is text line X a compile error's "^" line (spaces, then ^)
* pointing at a ":" (not ":=") in the line before (lastout)?  Then the
* next error message gives a hint (colhnt): Basic09 separates
* statements with "\", and "PRINT 1 : PRINT 2" is error 31 (Missing DO)
col_chk             pshs      d,x,y
                    clrb
cck1                lda       ,x+
                    cmpa      #C$SPAC
                    bne       cck2
                    incb
                    cmpb      #LASTMAX-2
                    blo       cck1
                    bra       cck9
cck2                cmpa      #'^
                    bne       cck9
                    lda       ,x
                    cmpa      #C$CR
                    bne       cck9
                    ldy       <base
                    leay      lastout,y
                    lda       b,y
                    cmpa      #':
                    bne       cck9
                    incb
                    lda       b,y
                    cmpa      #'=
                    beq       cck9
                    ldy       <base
                    inc       colhnt,y
cck9                puls      d,x,y,pc

linetx              fcn       "Line "
errtx2              equ       lderms+6            "Error "

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
                    lbsr      a_rline
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
                    lbcs      cm_gone
                    tstb
                    lbne      cm_keep
                    lbsr      mk_sweep            kill what is gone
                    lbcs      cm_gone
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
                    clr       <lderr
                    ldx       <base
                    clr       memful,x
                    lbsr      mk_bpgone
                    leax      ldcmd,pcr
                    lbsr      rt_send
                    bcs       cm_gone
                    lbsr      rt_wait
                    bcs       cm_gone
                    ldx       <base               memory full: a bigger workspace,
                    tst       memful,x            and Make again (what was sent is
                    beq       cm4                 sent again)
                    lbsr      mk_lderr
                    bsr       ws_grow
                    bcc       c_make
                    bra       cm5
cm4                 ldb       <nerrl              an error without an event: the
                    cmpb      <nerr               load failed as a whole
                    bls       cm5
                    lbsr      mk_lderr
cm5                 lda       #PF.SEND
                    lbsr      pt_flags
                    lbsr      a_mbuf              the result
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

* ws_kb: B = l2b09run's workspace in kilobytes (rtmem is in pages)
ws_kb               ldb       <rtmem
                    lsrb
                    lsrb
                    rts

* ws_grow: 8K more workspace; carry if it cannot be had
ws_grow             bsr       ws_kb
                    addb      #8
                    cmpb      #WSMAX
                    bhi       wsg_no
                    bsr       rt_mem
                    bcs       wsg_no
                    bra       ws_msg
wsg_no              orcc      #Carry
                    rts

* rt_mem: l2b09run's workspace to B kilobytes, with its mem command
* (the cold-command overlay); rtmem becomes what it got.  Carry if that
* is less than asked for, or the runtime has gone.
rt_mem              pshs      b
                    lbsr      a_mbuf              "mem <bytes>"
                    leay      memcmd,pcr
                    lbsr      s_str
                    lda       ,s
                    lsla
                    lsla
                    clrb
                    subd      #1                  (G.WSPS: the size less one)
                    lbsr      n_dec
                    lda       #C$CR
                    sta       ,x
                    lbsr      a_mbuf
                    lbsr      rt_send
                    bcs       rtm_no
                    lbsr      rt_wait
                    bcs       rtm_no
                    ldx       <base               it prints the size it has
                    leax      lastout,x
rtm1                lda       ,x+
                    cmpa      #C$SPAC
                    beq       rtm1
                    leax      -1,x
                    lbsr      getnum
                    tstb                          pages, rounded up
                    beq       rtm2
                    inca
rtm2                sta       <rtmem
                    lsra
                    lsra
                    cmpa      ,s+
                    blo       rtm_no1
                    andcc     #^Carry
                    rts
rtm_no              leas      1,s
rtm_no1             orcc      #Carry
                    rts

* ws_msg: "Workspace: <n>K" on the hint line
ws_msg              lbsr      a_mbuf
                    stx       <msgp
                    leay      wsms,pcr
                    lbsr      s_str
                    bsr       ws_kb
                    clra
                    lbsr      n_dec
                    lda       #'K
                    sta       ,x+
                    clr       ,x
                    andcc     #^Carry
                    rts

* c_memory: Options > Memory...: the workspace size in kilobytes.  Now
* with mem if l2b09run is running, else for its next start.  Not while
* a program is stopped: mem moves the workspace's top.
c_memory            tst       <dbgon
                    beq       cmm1
                    leax      wsdbg,pcr
                    stx       <msgp
                    rts
cmm1                lbsr      ws_kb               the size now, to edit
                    lbsr      a_inbx
                    clra
                    lbsr      n_dec
                    clr       ,x
                    leax      wstl,pcr
                    lbsr      dlg_inp
                    bcs       cmm9
                    lbsr      a_inbx
                    lbsr      getnum
                    tsta
                    bne       cmm_hi
                    cmpb      #WSMAX
                    bls       cmm2
cmm_hi              ldb       #WSMAX
cmm2                cmpb      #8
                    bhs       cmm3
                    ldb       #8
cmm3                tst       <child
                    bne       cmm4
                    lslb                          not running: for its start
                    lslb
                    stb       <rtmem
                    bra       ws_msg
cmm4                lbsr      rt_mem
                    bcc       ws_msg
                    bsr       ws_msg              less than asked for: say what
                    leax      wsfail,pcr          it has
                    stx       <msgp
                    lbsr      a_mbuf
                    ldy       <msgp
cmm5                tst       ,x+
                    bne       cmm5
                    leax      -1,x
                    lbsr      s_str
                    clr       ,x
                    lbsr      a_mbuf
                    stx       <msgp
cmm9                rts

B9.MEMF             equ       32                  Basic09's "memory full"
WSMAX               equ       56                  kilobytes (the mem command takes 16 bits)
memcmd              fcn       "mem "
wsms                fcn       "Workspace: "
wsfail              fcn       " (that is all it could get)"
wsdbg               fcn       "Not while the program is stopped (^P resets it)"
wstl                fcn       "Workspace (K)"

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
                    bita      #PF.DEF             (its users are marked)
                    bne       mdy2
                    bita      #PF.SEND
                    bne       mdy_yes
                    bita      #PF.SEEN
                    beq       mdy_yes
mdy2                incb
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
ldcmd               fcc       "load basic09-l2.tmp"
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
mk_scan             lda       #PF.SEEN+PF.SEND+PF.USE
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
mks1                lbsr      mk_isproc           PROCEDURE <name>
                    bcc       mks1p
                    ldx       <base               DEFTYPE <name>: an entry too
                    leax      mkp,x
                    lbsr      ln_def
                    bcs       mks2
                    lda       #PF.DEF
                    bra       mks1q
mks1p               clra
mks1q               pshs      a
                    lbsr      mk_close
                    ldy       <base
                    leay      nbuf,y
                    lbsr      pt_find
                    bcc       mks1a
                    lbsr      pt_add
                    bcc       mks1a
                    puls      a,pc                (carry)
mks1a               lda       PR.FLAG,y
                    anda      #^PF.DEF
                    ora       #PF.SEEN
                    ora       ,s+
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
mks2                ldx       <base               a USE line?
                    leax      mkp,x
                    lbsr      ln_use
                    bcs       mks2a
                    ldy       <curp
                    beq       mks2a
                    lda       PR.FLAG,y
                    ora       #PF.USE
                    sta       PR.FLAG,y
mks2a               ldx       <base               END DEFTYPE?
                    leax      mkp,x
                    lbsr      ln_enddef
                    tfr       cc,a
                    pshs      a
                    lbsr      mk_line
                    puls      a
                    bcs       mks8
                    ldx       <mkln
                    leax      1,x
                    stx       <mkln
                    bita      #Carry
                    lbne      mks1
                    ldy       <curp               it ends a DEFTYPE block: what
                    lbeq      mks1                follows up to the next PROCEDURE
                    lda       PR.FLAG,y           belongs to nothing
                    bita      #PF.DEF
                    lbeq      mks1
                    bsr       mk_close
                    clr       <curp
                    clr       <curp+1
                    lbra      mks1
mks8                lbsr      mk_close
                    bsr       mk_uses
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

* mk_uses: a procedure with a "USE <name>" line is sent too when the
* DEFTYPE block it names changed, or is not there
mk_uses             clrb
mu1                 cmpb      <nproc
                    bhs       mu9
                    lbsr      pt_at
                    lda       PR.FLAG,x
                    anda      #PF.USE+PF.SEND+PF.DEF
                    cmpa      #PF.USE
                    bne       mu8
                    pshs      b,x
                    bsr       us_set
mu2                 bsr       us_xu               its lines, after PROCEDURE
                    bsr       ln_next
                    bcs       mu7
                    bsr       us_xu
                    bsr       ln_use
                    bcs       mu2
                    ldy       <base
                    leay      nbuf,y
                    lbsr      pt_find
                    bcs       mu6                 ..not there
                    lda       PR.FLAG,y
                    bita      #PF.DEF
                    beq       mu6                 ..a procedure, not a block
                    bita      #PF.SEND
                    beq       mu2
mu6                 ldx       1,s
                    lda       PR.FLAG,x
                    ora       #PF.SEND
                    sta       PR.FLAG,x
mu7                 puls      b,x
mu8                 incb
                    bra       mu1
mu9                 rts

* us_set: usep = where entry X starts (its PROCEDURE line)
us_set              ldd       PR.PG,x
                    ldu       <base
                    std       usep,u
                    ldd       PR.OFF,x
                    std       usep+2,u
                    rts

* ln_next: position X to the next line of its procedure; carry at the
* end of the text or at the next PROCEDURE or DEFTYPE line.  Keeps X
* and Y.
ln_next             pshs      x,y
                    leau      ,x
                    lbsr      p_nextln
                    bcs       lnx9
                    ldx       ,s
                    bsr       ln_proc
                    bcc       lnx8
                    ldx       ,s
                    bsr       ln_def
                    tfr       cc,a                carry the other way round
                    eora      #Carry
                    tfr       a,cc
lnx9                puls      x,y,pc
lnx8                orcc      #Carry
                    puls      x,y,pc

* us_xu: X = U = usep
us_xu               ldx       <base
                    leax      usep,x
                    leau      ,x
                    rts

* mk_isproc: if the line at mkp is "PROCEDURE <name>" (any case, spaces
* before it), the name to nbuf; carry if it is not
mk_isproc           ldx       <base
                    leax      mkp,x
* ln_proc: the same for the line at position X
ln_proc             bsr       ln_at
                    leay      prockw,pcr
                    bsr       ln_word
                    bcc       ln_name
                    rts

* ln_use, ln_def: if the line at position X is "USE <name>" or
* "DEFTYPE <name>" (any case, spaces before the words), the name to
* nbuf; carry if it is not
ln_use              leay      usekw,pcr
                    bra       lnu1
ln_def              leay      defkw,pcr
lnu1                bsr       ln_at
                    bsr       ln_word
                    bcc       ln_name
                    rts

* ln_enddef: carry clear if the line at position X is "END DEFTYPE"
ln_enddef           bsr       ln_at
                    leay      endkw,pcr
                    bsr       ln_word             "END"
                    bcs       lnw9
                    bra       ln_word             "DEFTYPE"
lnw9                rts

* ln_at: U = wp = a copy of the position at X
ln_at               ldu       <base
                    leau      wp,u
                    ldd       ,x
                    std       ,u
                    ldd       2,x
                    std       2,u
                    rts

* ln_word: past spaces at position U, then past the word at Y (ending
* in 0, letters in capitals; Y after its 0); carry if it is not there
ln_word             lbsr      p_char
                    bcs       lnw_no
                    cmpa      #C$SPAC
                    bne       lnw1
                    lbsr      p_next
                    bra       ln_word
lnw1                lda       ,y+
                    beq       lnw8
                    anda      #$DF
                    pshs      a
                    lbsr      p_char
                    bcs       lnw_no1
                    anda      #$DF
                    cmpa      ,s+
                    bne       lnw_no
                    lbsr      p_next
                    bra       lnw1
lnw8                andcc     #^Carry
                    rts
lnw_no1             leas      1,s
lnw_no              orcc      #Carry
                    rts

* ln_name: spaces at position U, then a name: to nbuf; carry if there
* is none
ln_name             lbsr      p_char
                    bcs       lnw_no
                    cmpa      #C$SPAC
                    bne       lnw_no
lnn1                lbsr      p_next
                    lbsr      p_char
                    bcs       lnw_no
                    cmpa      #C$SPAC
                    beq       lnn1
                    ldx       <base
                    leax      nbuf,x
                    ldb       #NAMEMAX-1
lnn2                lbsr      p_char
                    bcs       lnn3
                    lbsr      is_word
                    bcc       lnn3
                    sta       ,x+
                    lbsr      p_next
                    decb
                    bne       lnn2
lnn3                clr       ,x
                    cmpb      #NAMEMAX-1
                    beq       lnw_no              no name
                    andcc     #^Carry
                    rts
prockw              fcn       "PROCEDURE"
usekw               fcn       "USE"
endkw               fcn       "END"
defkw               fcn       "DEFTYPE"
typekw              fcn       "TYPE"

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
                    bita      #PF.DEF             (l2b09run never had a DEFTYPE)
                    bne       msw1a
                    bsr       mk_kill
msw1a               puls      d
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
                    bita      #PF.DEF             a DEFTYPE block is not sent
                    beq       mw1a
                    anda      #^PF.SEND
                    sta       PR.FLAG,x
mw1a                bita      #PF.SEND
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
mk_wproc            lda       PR.FLAG,x
                    bita      #PF.USE
                    bne       mk_wuse
                    ldd       PR.LEN,x
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

* mk_wuse: write the text of entry X a line at a time.  A "USE <name>"
* line goes as the TYPE lines of the DEFTYPE block it names, joined by
* backslashes, then "(* " and the line, so that every line stays one
* line.  If there is no such block it goes as it is, and the compiler
* says so.
mk_wuse             ldd       PR.LEN,x
                    std       <tmpc
                    lbsr      us_set
mwu1                ldd       <tmpc
                    beq       mwu9
                    lbsr      us_xu
                    lbsr      ln_use
                    lbsr      a_rline
                    leay      ,x                  Y = where the line goes
                    bcs       mwu2
                    bsr       mk_types
                    bcs       mwu2
                    ldd       #'(*256+'*
                    std       ,y++
                    lda       #C$SPAC
                    sta       ,y+
mwu2                ldd       <tmpc               the line itself
                    beq       mwu4
                    lbsr      us_xu
                    lbsr      p_char
                    bcs       mwu4
                    lbsr      p_next
                    sta       ,y+
                    ldd       <tmpc
                    subd      #1
                    std       <tmpc
                    lda       -1,y
                    cmpa      #C$CR
                    beq       mwu5
                    lbsr      a_rline
                    leax      256,x
                    pshs      x
                    cmpy      ,s++
                    blo       mwu2
                    bsr       mwu_out             (too long for one line anyway)
                    bcs       mwu8
                    lbsr      a_rline
                    leay      ,x
                    bra       mwu2
mwu4                lda       #C$CR               the text ended without one
                    sta       ,y+
                    clr       <tmpc
                    clr       <tmpc+1
mwu5                bsr       mwu_out
                    bcc       mwu1
mwu8                rts
mwu9                andcc     #^Carry
                    rts
mwu_out             lbsr      a_rline             write rline up to Y
                    tfr       y,d
                    pshs      x
                    subd      ,s++
                    tfr       d,y
                    lda       <flpath
                    os9       I$Write
                    rts

* mk_types: the TYPE lines of the DEFTYPE block named by nbuf to Y,
* each without its comment (and a backslash in front of it) and
* followed by " \ "; Y after them.  At most TYMAX bytes go, so that the
* line stays under l2b09run's 256.  Carry (Y as it was) if there is no
* such block.
TYMAX               equ       200
mty_no              orcc      #Carry
mty9                rts
hd_x                ldx       <base               X = hdrp
                    leax      hdrp,x
                    rts
mk_types            pshs      y
                    ldy       <base
                    leay      nbuf,y
                    lbsr      pt_find
                    tfr       y,x
                    puls      y
                    bcs       mty9                ..not there
                    lda       PR.FLAG,x
                    bita      #PF.DEF
                    beq       mty_no              ..a procedure, not a block
                    ldd       PR.PG,x
                    ldu       <base
                    std       hdrp,u
                    ldd       PR.OFF,x
                    std       hdrp+2,u
mty1                bsr       hd_x                its lines, after DEFTYPE, up to
                    lbsr      ln_next             END DEFTYPE
                    bcs       mty8
                    pshs      y
                    lbsr      ln_enddef
                    puls      y
                    bcc       mty8
                    lbsr      ln_at               "TYPE" and a space?
                    pshs      y
                    leay      typekw,pcr
                    lbsr      ln_word
                    puls      y
                    bcs       mty1
                    lbsr      p_char
                    cmpa      #C$SPAC
                    bne       mty1
                    leax      typekw,pcr
mty2                lda       ,x+
                    beq       mty3
                    bsr       ty_put
                    bra       mty2
mty3                lbsr      p_char              the rest of the line (U = wp),
                    bcs       mty4                up to a comment: it would hide
                    cmpa      #C$CR               the rest of the joined line
                    beq       mty4
                    lbsr      p_next
                    cmpa      #'(
                    bne       mty3a
                    lbsr      p_char
                    cmpa      #'*
                    beq       mty4
                    lda       #'(
mty3a               bsr       ty_put
                    bra       mty3
mty4                lda       -1,y                drop the spaces and the backslash
                    cmpa      #C$SPAC             in front of a comment
                    beq       mty4a
                    cmpa      #$5C
                    bne       mty4b
mty4a               leay      -1,y
                    bra       mty4
mty4b               lda       #C$SPAC
                    bsr       ty_put
                    lda       #$5C                backslash
                    bsr       ty_put
                    lda       #C$SPAC
                    bsr       ty_put
                    bra       mty1
mty8                andcc     #^Carry
                    rts
ty_put              pshs      x                   A to Y, while there is room
                    lbsr      a_rline
                    leax      TYMAX,x
                    pshs      x
                    cmpy      ,s++
                    puls      x
                    bhs       typ9
                    sta       ,y+
typ9                rts

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
* step to stop at its first statement), then as dbg_go.  A new run
* starts on a clear screen (what an earlier one left is gone).
run_first           pshs      x
                    lbsr      bp_sync
                    bcs       crn8
                    ldy       #0                  the procedure with the lowest line
                    clrb                          (not a DEFTYPE block)
crn2                cmpb      <nproc
                    bhs       crn3
                    lbsr      pt_at
                    pshs      b
                    lda       PR.FLAG,x
                    bita      #PF.DEF
                    bne       crn2b
                    cmpy      #0
                    beq       crn2a
                    ldd       PR.LINE,x
                    cmpd      PR.LINE,y
                    bhs       crn2b
crn2a               tfr       x,y
crn2b               puls      b
                    incb
                    bra       crn2
crn3                cmpy      #0
                    bne       crn3a
                    leax      noprms,pcr
                    stx       <msgp
crn8                puls      x
crn9                rts
crn3a               bsr       u_cls
                    lbsr      a_rline             "run <name>"
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

* u_inp: show the program's terminal, once per dbg_go (ushown)
u_inp               ldx       <base
                    tst       ushown,x
                    bne       ush9
                    inc       ushown,x
* u_show: show the program's terminal
u_show              tst       <uterm
                    beq       ush9
                    leax      selwin,pcr
                    ldy       #2
                    lda       <upath
                    os9       I$Write
ush9                rts

* u_cls: clear the program's terminal; keeps all registers
u_cls               tst       <uterm
                    beq       ucl9
                    pshs      d,x,y
                    leax      clsch,pcr
                    ldy       #1
                    lda       <upath
                    os9       I$Write
                    puls      d,x,y
ucl9                rts
clsch               fcb       $0C

* u_pause: after a run that ended, "Press any key" on the program's
* terminal and wait for one there (unless Options turned it off)
u_pause             tst       <uterm
                    beq       ups9
                    ldx       <base
                    tst       nopaus,x
                    bne       ups9
                    leax      pausms,pcr
                    ldy       #PAUSLN
                    lda       <upath
                    os9       I$Write
                    bra       u_key
ups9                rts
pausms              fcb       C$CR,C$LF
                    fcc       "Press any key"
PAUSLN              equ       *-pausms

* u_key: wait for a key while the program's terminal is shown.  Keys
* already waiting there (typed during the run, or a repeat of F5) are
* dropped first; then a key on either terminal will do (one pressed as
* the screens switch can land on ours).  From a key script: getkey.
u_key               tst       <kbterm
                    lbeq      getkey
uk0                 lda       <upath              drop what is waiting
                    ldb       #SS.Ready
                    os9       I$GetStt
                    bcs       uk1
                    bsr       uk_rd
                    bra       uk0
uk1                 lda       <upath              wait for one
                    ldb       #SS.Ready
                    os9       I$GetStt
                    bcc       uk_rd
                    lda       <kbpath
                    ldb       #SS.Ready
                    os9       I$GetStt
                    bcc       uk2
                    ldx       #1                  (a signal ends the sleep early)
                    os9       F$Sleep
                    bra       uk1
uk2                 lda       <kbpath
                    fcb       $8C                 cmpx #: skip the lda
uk_rd               lda       <upath
                    ldx       <base               read the key at path A
                    leax      kraw,x
                    ldy       #1
                    os9       I$Read
                    rts

* u_back: show ours again
u_back              tst       <uterm
                    beq       ubk9
                    lbsr      t_flush
                    bsr       ubk_sel
                    ldx       #2                  and again a moment later: a switch
                    os9       F$Sleep             to the program's terminal can come
                    bsr       ubk_sel             after ours, behind its output
                    lbra      rd_all
ubk_sel             leax      selwin,pcr
                    ldy       #2
                    lda       <scpath
                    os9       I$Write
ubk9                rts
selwin              fcb       $1B,$21             select this terminal

* c_user: show the program's terminal until a key is pressed (F5)
c_user              tst       <uterm
                    bne       cus1
                    leax      nousms,pcr
                    stx       <msgp
                    rts
cus1                lbsr      t_flush
                    lbsr      u_show
                    bsr       u_key
                    bra       u_back
nousms              fcn       "No user screen"
