********************************************************************
* undo - undo and redo
*
* A record is a range of the text: where it starts and how long it is
* (24-bit, as the text can pass 64K), and whether its text is in the
* buffer or out of it, in a page chain of its own.  An insertion starts
* with its text in the buffer, a deletion with its text out.  Undo and
* redo both just move the text to the other side.
*
* Positions in records are absolute offsets: pages split and join, so a
* page position would not last.  Typing extends the last insertion;
* Delete and ^D add to the end of the last deletion and Backspace to its
* start.  There are NUNDO records; the oldest goes first.

NUNDO               equ       50
UR.OFF              equ       0                   start (3 bytes)
UR.LEN              equ       3                   length (3 bytes)
UR.CH               equ       6                   text chain while out of the buffer
UR.FL               equ       8
UR.SIZE             equ       9
UF.DEL              equ       $01                 a deletion (otherwise an insertion)
UF.OUT              equ       $02                 its text is out of the buffer
UF.LINK             equ       $04                 undone and redone with the one before

* pos2abs: ua = the offset of position U from the start of the text
pos2abs             pshs      d,x
                    clr       <ua
                    ldd       #0
                    std       <ua+1
                    ldx       <first
p2a1                cmpx      ,u
                    beq       p2a2
                    ldd       <ua+1
                    addd      DS.USED,x
                    std       <ua+1
                    bcc       p2a1a
                    inc       <ua
p2a1a               ldx       DS.NEXT,x
                    bne       p2a1
p2a2                ldd       <ua+1
                    addd      2,u
                    std       <ua+1
                    bcc       p2a9
                    inc       <ua
p2a9                puls      d,x,pc

* abs2pos: position U = offset ua of the text (or its end); D = its line
abs2pos             pshs      x,y
                    ldd       #0
                    std       <tmpc               lines before it
                    lda       <ua
                    sta       <ub
                    ldd       <ua+1
                    std       <ub+1
                    ldx       <first
a2p1                tst       <ub                 inside this page?
                    bne       a2p2
                    ldd       <ub+1
                    cmpd      DS.USED,x
                    blo       a2p3
a2p2                ldy       DS.NEXT,x
                    beq       a2p4
                    ldd       <ub+1
                    subd      DS.USED,x
                    std       <ub+1
                    bcc       a2p2a
                    dec       <ub
a2p2a               ldd       <tmpc
                    addd      DS.LINES,x
                    std       <tmpc
                    leax      ,y
                    bra       a2p1
a2p4                ldd       DS.USED,x           past the end: the end
a2p3                stx       ,u
                    std       2,u
                    beq       a2p9
                    lbsr      pg_map              count the line ends before it
                    pshs      y
                    addd      ,s
                    puls      y
                    pshs      d                   end
a2p5                lda       ,y+
                    cmpa      #C$CR
                    bne       a2p6
                    lbsr      tmpc_inc
a2p6                cmpy      ,s
                    blo       a2p5
                    leas      2,s
a2p9                ldd       <tmpc
                    puls      x,y,pc

* u_ptr: X = record B
u_ptr               lda       #UR.SIZE
                    mul
                    ldx       <base
                    leax      utab,x
                    leax      d,x
                    rts

* u_frec: free the text chain of record X
u_frec              pshs      x
                    ldx       UR.CH,x
                    lbsr      chain_free
                    puls      x
                    clr       UR.CH,x
                    clr       UR.CH+1,x
                    rts

* u_clear: forget all records
u_clear             pshs      d,x
uc1                 ldb       <ucnt
                    beq       uc9
                    decb
                    stb       <ucnt
                    bsr       u_ptr
                    bsr       u_frec
                    bra       uc1
uc9                 clr       <ucur
                    puls      d,x,pc

* u_new: X = a new, cleared record at the end (records that could be
* redone go; with NUNDO records the oldest goes)
u_new               pshs      d,y,u
un1                 lda       <ucnt
                    cmpa      <ucur
                    bls       un2
                    deca
                    sta       <ucnt
                    tfr       a,b
                    bsr       u_ptr
                    bsr       u_frec
                    bra       un1
un2                 cmpa      #NUNDO
                    blo       un4
                    clrb
                    bsr       u_ptr
                    bsr       u_frec
                    leay      UR.SIZE,x           move the others down
                    ldu       #(NUNDO-1)*UR.SIZE
un3                 lda       ,y+
                    sta       ,x+
                    leau      -1,u
                    cmpu      #0                  (leau does not set Z)
                    bne       un3
                    dec       <ucnt
un4                 ldb       <ucnt
                    bsr       u_ptr
                    ldb       #UR.SIZE
                    pshs      x
un5                 clr       ,x+
                    decb
                    bne       un5
                    puls      x
                    inc       <ucnt
                    lda       <ucnt
                    sta       <ucur
                    lda       <ulink              one edit made of several records?
                    beq       un9
                    cmpa      #1
                    beq       un8                 the first one stands alone
                    lda       #UF.LINK
                    sta       UR.FL,x
                    bra       un9
un8                 inc       <ulink
un9                 puls      d,y,u,pc

* u_last: X = the last record, if nothing could be redone; carry if none
u_last              ldb       <ucnt
                    beq       ul9
                    cmpb      <ucur
                    bne       ul9
                    decb
                    lbsr      u_ptr
                    andcc     #^Carry
                    rts
ul9                 orcc      #Carry
                    rts

* u_setoff: record X starts at ua
u_setoff            lda       <ua
                    sta       UR.OFF,x
                    ldd       <ua+1
                    std       UR.OFF+1,x
                    rts

* u_inclen: one more byte in record X
u_inclen            ldd       UR.LEN+1,x
                    addd      #1
                    std       UR.LEN+1,x
                    bcc       uil9
                    inc       UR.LEN,x
uil9                rts

* u_endeq: Z if record X ends at ua
u_endeq             ldd       UR.OFF+1,x
                    addd      UR.LEN+1,x
                    pshs      d                   (leaves the carry)
                    lda       UR.OFF,x
                    adca      UR.LEN,x
                    cmpa      <ua
                    puls      d
                    bne       ue9
                    cmpd      <ua+1
ue9                 rts

* u_ins1: character A is about to be inserted at the cursor
u_ins1              tst       <noundo
                    bne       ui9
                    pshs      d,x,y,u
                    lbsr      a_cpos
                    lbsr      pos2abs
                    bsr       u_last
                    bcs       ui1
                    tst       UR.FL,x             an insertion, in the buffer
                    bne       ui1
                    bsr       u_endeq             ending here?
                    bne       ui1
                    bsr       u_inclen
                    bra       ui8
ui1                 lbsr      u_new
                    bsr       u_setoff
                    ldd       #1
                    std       UR.LEN+1,x
ui8                 puls      d,x,y,u
ui9                 rts

* u_del1: character A at the cursor is about to be deleted
u_del1              tst       <noundo
                    lbne      ud9
                    pshs      d,x,y,u
                    inc       <ubusy
                    lbsr      a_cpos
                    lbsr      pos2abs
                    bsr       u_last
                    bcs       ud3
                    ldb       UR.FL,x
                    cmpb      #UF.DEL+UF.OUT      a deletion, out of the buffer
                    bne       ud3
                    ldb       UR.OFF,x            starting here: add to its end
                    cmpb      <ua
                    bne       ud1
                    ldd       UR.OFF+1,x
                    cmpd      <ua+1
                    bne       ud1
                    lda       ,s
                    lbsr      chain_app
                    bcs       ud_full
                    bra       ud2
ud1                 ldd       <ua+1               starting just after: add to its start
                    addd      #1
                    pshs      d
                    ldb       <ua
                    adcb      #0
                    cmpb      UR.OFF,x
                    puls      d
                    bne       ud3
                    cmpd      UR.OFF+1,x
                    bne       ud3
                    lda       ,s
                    lbsr      chain_pre
                    bcs       ud_full
                    lbsr      u_setoff
ud2                 lbsr      u_inclen
                    bra       ud8
ud3                 lbsr      d_alloc             a new deletion record
                    bcs       ud_full
                    pshs      x                   (the character is now at 2,s)
                    lbsr      pg_map
                    lda       2,s
                    sta       ,y
                    ldd       #1
                    std       DS.USED,x
                    lda       2,s
                    cmpa      #C$CR
                    bne       ud4
                    ldd       #1
                    std       DS.LINES,x
ud4                 lbsr      pg_dirt0
                    lbsr      u_new
                    puls      d
                    std       UR.CH,x
                    lbsr      u_setoff
                    ldd       #1
                    std       UR.LEN+1,x
                    lda       #UF.DEL+UF.OUT
                    sta       UR.FL,x
                    bra       ud8
ud_full             lbsr      u_clear             no pages for it: forget the history
ud8                 dec       <ubusy
                    puls      d,x,y,u
ud9                 rts

* u_delto: the text from the cursor to xpos is about to be deleted
u_delto             tst       <noundo
                    bne       udt9
                    pshs      d,x,y,u
                    inc       <ubusy
                    ldd       <cpos               nothing at all?
                    cmpd      <xpos
                    bne       udt1
                    ldd       <cpos+2
                    cmpd      <xpos+2
                    beq       udt8
udt1                lbsr      cp_wp
                    ldd       <xpos
                    std       <cend
                    ldd       <xpos+2
                    std       <cend+2
                    lbsr      chain_copy
                    bcc       udt2
                    lbsr      chain_free
                    lbsr      u_clear
                    bra       udt8
udt2                pshs      x
                    ldu       <base               length = end - start
                    leau      xpos,u
                    lbsr      pos2abs
                    lda       <ua
                    sta       <ub
                    ldd       <ua+1
                    std       <ub+1
                    lbsr      a_cpos
                    lbsr      pos2abs
                    lbsr      u_new
                    lbsr      u_setoff
                    ldd       <ub+1
                    subd      <ua+1
                    std       UR.LEN+1,x
                    lda       <ub
                    sbca      <ua
                    sta       UR.LEN,x
                    puls      d
                    std       UR.CH,x
                    lda       #UF.DEL+UF.OUT
                    ora       UR.FL,x
                    sta       UR.FL,x
udt8                dec       <ubusy
                    puls      d,x,y,u
udt9                rts

* u_paste: record an insertion of ulen bytes at uoff (from chain_paste)
u_paste             tst       <noundo
                    bne       upa9
                    lda       <ulen
                    ora       <ulen+1
                    ora       <ulen+2
                    beq       upa9
                    pshs      x
                    lbsr      u_new
                    lda       <uoff
                    sta       UR.OFF,x
                    ldd       <uoff+1
                    std       UR.OFF+1,x
                    lda       <ulen
                    sta       UR.LEN,x
                    ldd       <ulen+1
                    std       UR.LEN+1,x
                    puls      x
upa9                rts

* chain_app: add A to the end of the chain of record X; carry if no page
chain_app           pshs      a,x,y,u
                    ldx       UR.CH,x
cap1                ldy       DS.NEXT,x           the last page
                    beq       cap2
                    leax      ,y
                    bra       cap1
cap2                ldd       DS.USED,x
                    cmpd      #PGFILL
                    blo       cap3
                    tfr       x,u                 full: another page
                    lbsr      d_alloc
                    bcs       cap9
                    stu       DS.PREV,x
                    stx       DS.NEXT,u
cap3                lbsr      pg_map
                    ldd       DS.USED,x
                    leay      d,y
                    addd      #1
                    std       DS.USED,x
                    lda       ,s
                    sta       ,y
                    bsr       chain_cr
                    lbsr      pg_dirt0
                    andcc     #^Carry
cap9                puls      a,x,y,u,pc

* chain_pre: add A to the start of the chain of record X; carry if no page
chain_pre           pshs      a,x,y,u
                    ldu       UR.CH,x
                    ldd       DS.USED,u
                    cmpd      #PGFILL
                    blo       cpr2
                    lbsr      d_alloc             full: a new first page
                    bcs       cpr9
                    stx       DS.PREV,u
                    stu       DS.NEXT,x
                    ldu       1,s
                    stx       UR.CH,u
                    bra       cpr3
cpr2                tfr       u,x
cpr3                lbsr      pg_map              move the text up one
                    ldd       DS.USED,x
                    beq       cpr5
                    leau      d,y
                    pshs      x
                    tfr       d,x
cpr4                lda       ,-u
                    sta       1,u
                    leax      -1,x
                    bne       cpr4
                    puls      x
cpr5                lda       ,s
                    sta       ,y
                    ldd       DS.USED,x
                    addd      #1
                    std       DS.USED,x
                    bsr       chain_cr
                    lbsr      pg_dirt0
                    andcc     #^Carry
cpr9                puls      a,x,y,u,pc

* chain_cr: count the line end if the byte added (A on the caller's
* stack) was one
chain_cr            lda       2,s
                    cmpa      #C$CR
                    bne       ccr9
                    ldd       DS.LINES,x
                    addd      #1
                    std       DS.LINES,x
ccr9                rts

* c_undo, c_redo (records linked with UF.LINK go together)
c_undo              ldb       <ucur
                    beq       cun8
                    decb                          a group (pretty print)? then the
                    lbsr      u_ptr               breakpoints keep their lines
                    lda       UR.FL,x
                    anda      #UF.LINK
                    sta       <ugrp
                    beq       cun0
                    lbsr      bp_keep
cun0                ldb       <ucur
cun1                decb
                    stb       <ucur
                    lbsr      u_ptr
                    lbsr      u_toggle
                    lda       UR.FL,x
                    bita      #UF.LINK
                    beq       cun9
                    ldb       <ucur
                    bne       cun1
cun9                bra       u_grpend
cun8                leax      noundm,pcr
                    stx       <msgp
                    rts
c_redo              ldb       <ucur
                    cmpb      <ucnt
                    beq       crd8
                    clr       <ugrp
                    incb                          a group (pretty print)?
                    cmpb      <ucnt
                    bhs       crd1
                    lbsr      u_ptr
                    lda       UR.FL,x
                    anda      #UF.LINK
                    sta       <ugrp
                    beq       crd1
                    lbsr      bp_keep
crd1                ldb       <ucur               (u_ptr does not keep B)
                    lbsr      u_ptr
                    inc       <ucur
                    bsr       u_toggle
                    ldb       <ucur
                    cmpb      <ucnt
                    beq       crd9
                    lbsr      u_ptr
                    lda       UR.FL,x
                    bita      #UF.LINK
                    bne       crd1
crd9                bra       u_grpend
crd8                leax      noredm,pcr
                    stx       <msgp
                    rts
* u_grpend: after a group, the breakpoints back on their lines; the
* cursor stays on its line
u_grpend            tst       <ugrp
                    beq       uge9
                    ldd       <curline
                    pshs      d
                    lbsr      bp_back
                    puls      d
                    lbsr      goto_line
                    lbsr      v_center
uge9                rts
noundm              fcn       "Nothing to undo"
noredm              fcn       "Nothing to redo"

* u_toggle: move the text of record X to the other side
u_toggle            pshs      x
                    inc       <noundo
                    inc       <ubusy
                    lbsr      sel_off
                    lda       UR.OFF,x            the cursor goes to its start
                    sta       <ua
                    ldd       UR.OFF+1,x
                    std       <ua+1
                    lbsr      a_cpos
                    lbsr      abs2pos
                    std       <curline
                    ldx       ,s
                    lda       UR.FL,x
                    bita      #UF.OUT
                    bne       ut_in
                    ldd       <ua+1               out: xpos at its end
                    addd      UR.LEN+1,x
                    std       <ua+1
                    lda       <ua
                    adca      UR.LEN,x
                    sta       <ua
                    ldu       <base
                    leau      xpos,u
                    lbsr      abs2pos
                    lbsr      cp_wp
                    ldd       <xpos
                    std       <cend
                    ldd       <xpos+2
                    std       <cend+2
                    lbsr      chain_copy
                    bcc       ut1
                    lbsr      chain_free          no pages for it: give up the history
                    lbsr      u_clear
                    lbsr      c_full
                    bra       ut9
ut1                 ldy       ,s
                    stx       UR.CH,y
                    lbsr      ed_delto
                    ldx       ,s
                    lda       UR.FL,x
                    ora       #UF.OUT
                    sta       UR.FL,x
                    bra       ut8
ut_in               ldx       UR.CH,x             in: paste it back
                    lbsr      chain_paste
                    ldx       ,s
                    lbsr      u_frec
                    lda       UR.FL,x
                    anda      #^UF.OUT
                    sta       UR.FL,x
ut8                 lda       #1
                    sta       <modif
                    lbsr      v_center
ut9                 clr       <noundo
                    clr       <ubusy
                    puls      x,pc
