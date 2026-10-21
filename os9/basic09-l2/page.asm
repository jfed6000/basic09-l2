********************************************************************
* page - the paged text buffer
*
* The text is a doubly linked chain of pages.  Each page holds up to
* PGSZ bytes and owns one PGSZ slot in the swap file.  A few pages are
* cached in memory (LRU, written back when dirty).  A pointer into a
* page buffer stays good only until another page is mapped, except
* that the page mapped last is never the one evicted.
*
* Positions are (page, offset).  They are canonical: the offset is
* below the page's byte count, except at the very end of the text.

* pg_init: every descriptor free, every cache buffer empty
pg_init             pshs      d,x,y,u
                    ldx       <descp
                    stx       <freed
                    ldy       #0                  slot number
                    ldu       #NDESC
pi1                 sty       DS.SLOT,x
                    clr       DS.FLAG,x
                    clra
                    clrb
                    std       DS.CE,x
                    std       DS.PREV,x
                    std       DS.USED,x
                    std       DS.LINES,x
                    leay      1,y
                    leau      -1,u
                    cmpu      #0                  (leau does not set Z)
                    beq       pi2
                    tfr       x,d
                    addd      #DS.SIZE
                    std       DS.NEXT,x
                    tfr       d,x
                    bra       pi1
pi2                 ldd       #0
                    std       DS.NEXT,x
                    ldx       <cachp
                    ldy       <cbufp
                    ldb       <ncache
pi3                 clr       CE.DIRT,x
                    clr       CE.DESC,x
                    clr       CE.DESC+1,x
                    clr       CE.AGE,x
                    clr       CE.AGE+1,x
                    sty       CE.BUF,x
                    leay      PGSZ,y
                    leax      CE.SIZE,x
                    decb
                    bne       pi3
                    puls      d,x,y,u,pc

* d_alloc: X = a new empty page; carry (B = error) if there are none.
* When they run out the undo history is given up for its pages (unless
* undo itself is asking).
d_alloc             ldx       <freed
                    bne       da1
                    tst       <ubusy
                    bne       da9
                    tst       <ucnt
                    beq       da9
                    lbsr      u_clear
                    ldx       <freed
                    beq       da9
da1
                    pshs      d
                    ldd       DS.NEXT,x
                    std       <freed
                    clra
                    clrb
                    std       DS.NEXT,x
                    std       DS.PREV,x
                    std       DS.USED,x
                    std       DS.LINES,x
                    std       DS.CE,x
                    lda       #DF.CHG
                    sta       DS.FLAG,x
                    puls      d
                    andcc     #^Carry
                    rts
da9                 ldb       #E$MemFul
                    comb
                    rts

* d_free: give page X back, dropping its cache buffer
d_free              pshs      d,y
                    ldy       DS.CE,x
                    beq       df1
                    clra
                    clrb
                    std       CE.DESC,y
                    std       CE.AGE,y
                    clr       CE.DIRT,y
df1                 ldd       #0
                    std       DS.CE,x
                    ldd       <freed
                    std       DS.NEXT,x
                    stx       <freed
                    puls      d,y,pc

* pg_unlink: take page X out of the chain
pg_unlink           pshs      y,u
                    ldy       DS.PREV,x
                    ldu       DS.NEXT,x
                    leay      ,y
                    bne       pu1
                    stu       <first
                    bra       pu2
pu1                 stu       DS.NEXT,y
pu2                 cmpu      #0
                    beq       pu3
                    sty       DS.PREV,u
pu3                 puls      y,u,pc

* pg_map: Y = the data of page X (read in from the swap file if needed)
pg_map              ldy       DS.CE,x
                    beq       pm_miss
pm_hit              pshs      d
                    ldd       <clock
                    addd      #1
                    cmpd      #$F000
                    blo       pm1
                    bsr       ce_renorm
                    ldd       <clock
                    addd      #1
pm1                 std       <clock
                    std       CE.AGE,y
                    ldy       CE.BUF,y
                    puls      d,pc
pm_miss             pshs      d,x,u
                    bsr       ce_get              Y = a free cache entry
                    stx       CE.DESC,y
                    sty       DS.CE,x
                    clr       CE.DIRT,y
                    lda       DS.FLAG,x
                    bita      #DF.SWAP
                    beq       pm2                 never written out: nothing to read
                    ldd       DS.USED,x
                    beq       pm2
                    lbsr      sw_seek
                    pshs      y
                    ldx       CE.BUF,y
                    tfr       d,y
                    lda       <swpath
                    os9       I$Read
                    lbcs      fatal
                    puls      y
pm2                 puls      d,x,u
                    bra       pm_hit

* ce_renorm: the LRU clock is about to wrap; age everything down
ce_renorm           pshs      d,x
                    ldx       <cachp
                    ldb       <ncache
                    pshs      b
cr1                 ldd       CE.AGE,x
                    subd      #$8000
                    bcc       cr2
                    ldd       #0
cr2                 std       CE.AGE,x
                    leax      CE.SIZE,x
                    dec       ,s
                    bne       cr1
                    leas      1,s
                    ldd       <clock
                    subd      #$8000
                    std       <clock
                    puls      d,x,pc

* ce_get: Y = a cache entry with no page in it (the least recently used
* one is written back and emptied); X is kept
ce_get              pshs      d,x,u
                    ldx       <cachp
                    ldb       <ncache
                    ldy       #0
cg1                 ldu       CE.DESC,x
                    beq       cg_free
                    leay      ,y
                    beq       cg2
                    pshs      b
                    ldd       CE.AGE,x
                    cmpd      CE.AGE,y
                    puls      b
                    bhs       cg3
cg2                 tfr       x,y
cg3                 leax      CE.SIZE,x
                    decb
                    bne       cg1
                    ldx       CE.DESC,y           Y = the victim
                    tst       CE.DIRT,y
                    beq       cg5
                    ldd       DS.USED,x
                    beq       cg4
                    bsr       sw_seek
                    pshs      x,y
                    ldx       CE.BUF,y
                    tfr       d,y
                    lda       <swpath
                    os9       I$Write
                    lbcs      fatal
                    puls      x,y
cg4                 lda       DS.FLAG,x
                    ora       #DF.SWAP
                    sta       DS.FLAG,x
cg5                 ldd       #0
                    std       DS.CE,x
                    std       CE.DESC,y
                    clr       CE.DIRT,y
                    puls      d,x,u,pc
cg_free             tfr       x,y
                    puls      d,x,u,pc

* pg_dirty: page X (mapped) has changed
pg_dirty            pshs      a,y
                    ldy       DS.CE,x
                    beq       pd1
                    lda       #1
                    sta       CE.DIRT,y
pd1                 lda       DS.FLAG,x
                    ora       #DF.CHG
                    sta       DS.FLAG,x
                    lda       #1
                    sta       <modif
                    puls      a,y,pc

* pg_dirt0: page X (mapped) has changed, but it is not part of the text
pg_dirt0            pshs      a,y
                    ldy       DS.CE,x
                    beq       pdz1
                    lda       #1
                    sta       CE.DIRT,y
pdz1                puls      a,y,pc

* sw_seek: seek the swap file to the slot of page X
sw_seek             pshs      d,x,u
                    ldd       DS.SLOT,x
                    pshs      d
                    andb      #$1F                low word = (slot & 31) << 11
                    aslb
                    aslb
                    aslb
                    tfr       b,a
                    clrb
                    tfr       d,u
                    puls      d                   high word = slot >> 5
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    tfr       d,x
                    lda       <swpath
                    os9       I$Seek
                    lbcs      fatal
                    puls      d,x,u,pc

* sw_open: create (or reuse) the swap file in the data directory
sw_open             leax      swpnm,pcr
                    lda       #UPDAT.
                    ldb       #UPDAT.
                    os9       I$Create
                    bcc       so1
                    cmpb      #E$CEF
                    lbne      fatal
                    leax      swpnm,pcr
                    lda       #UPDAT.
                    os9       I$Open
                    lbcs      fatal
so1                 sta       <swpath
                    rts

* sw_close: close and delete the swap file
sw_close            lda       <swpath
                    beq       sc9
                    os9       I$Close
                    clr       <swpath
                    leax      swpnm,pcr
                    os9       I$Delete
sc9                 rts

********************************************************************
* Tracked positions

* trk_ins: positions in page X past offset D move up by one
trk_ins             pshs      d,y,u
                    lbsr      a_cpos
                    ldy       #NPOS
tin1                 cmpx      ,u
                    bne       tin2
                    ldd       2,u
                    cmpd      ,s
                    bls       tin2
                    addd      #1
                    std       2,u
tin2                 leau      4,u
                    leay      -1,y
                    bne       tin1
                    puls      d,y,u,pc

* trk_del: positions in page X past offset D move down by one
trk_del             pshs      d,y,u
                    lbsr      a_cpos
                    ldy       #NPOS
tdl1                cmpx      ,u
                    bne       tdl2
                    ldd       2,u
                    cmpd      ,s
                    bls       tdl2
                    subd      #1
                    std       2,u
tdl2                leau      4,u
                    leay      -1,y
                    bne       tdl1
                    puls      d,y,u,pc

* trk_move: positions in page tf at offset tm or above go to page tt,
* with tk added to the offset
trk_move            pshs      d,x,y,u
                    lbsr      a_cpos
                    ldy       #NPOS
tm1                 ldx       ,u
                    cmpx      <tf
                    bne       tm2
                    ldd       2,u
                    cmpd      <tm
                    blo       tm2
                    addd      <tk
                    std       2,u
                    ldx       <tt
                    stx       ,u
tm2                 leau      4,u
                    leay      -1,y
                    bne       tm1
                    puls      d,x,y,u,pc

* trk_canon: positions at the end of a page that has a next page move
* to the start of that page
trk_canon           pshs      d,x,y,u
                    lbsr      a_cpos
                    ldy       #NPOS
tc1                 ldx       ,u
                    beq       tc2
                    ldd       2,u
                    cmpd      DS.USED,x
                    blo       tc2
                    ldx       DS.NEXT,x
                    beq       tc2
                    stx       ,u
                    ldd       #0
                    std       2,u
tc2                 leau      4,u
                    leay      -1,y
                    bne       tc1
                    puls      d,x,y,u,pc

********************************************************************
* Moving a position (U points at it)

* p_char: A = the character at U; carry at the end of the text
p_char              pshs      b,x,y
                    ldx       ,u
                    ldd       2,u
                    cmpd      DS.USED,x
                    bhs       pch9
                    lbsr      pg_map
                    lda       d,y
                    andcc     #^Carry
                    puls      b,x,y,pc
pch9                clra
                    orcc      #Carry
                    puls      b,x,y,pc

* p_next: one character on; carry (and no move) at the end
p_next              pshs      d,x
                    ldx       ,u
                    ldd       2,u
                    cmpd      DS.USED,x
                    bhs       pn9
                    addd      #1
                    std       2,u
                    cmpd      DS.USED,x
                    blo       pn1
                    ldx       DS.NEXT,x
                    beq       pn1
                    stx       ,u
                    clr       2,u
                    clr       3,u
pn1                 andcc     #^Carry
                    puls      d,x,pc
pn9                 orcc      #Carry
                    puls      d,x,pc

* p_prev: one character back; carry (and no move) at the start
p_prev              pshs      d,x
                    ldd       2,u
                    beq       pp1
                    subd      #1
                    std       2,u
                    bra       pp8
pp1                 ldx       ,u
                    ldx       DS.PREV,x
                    beq       pp9
                    stx       ,u
                    ldd       DS.USED,x
                    subd      #1
                    std       2,u
pp8                 andcc     #^Carry
                    puls      d,x,pc
pp9                 orcc      #Carry
                    puls      d,x,pc

* p_bol: to the start of the line
p_bol               pshs      a
pb1                 bsr       p_prev
                    bcs       pb9
                    bsr       p_char
                    cmpa      #C$CR
                    bne       pb1
                    bsr       p_next
pb9                 andcc     #^Carry
                    puls      a,pc

* p_eol: to the carriage return ending the line; carry if the line
* runs to the end of the text instead
p_eol               pshs      a
pe1                 bsr       p_char
                    bcs       pe9
                    cmpa      #C$CR
                    beq       pe9
                    bsr       p_next
                    bra       pe1
pe9                 puls      a,pc

* p_nextln: to the start of the next line; carry if there is none (the
* position is then at the end of the text)
p_nextln            bsr       p_eol
                    bcs       pnl9
                    bsr       p_next
pnl9                rts

* p_prevln: to the start of the previous line; carry if there is none
* (the position is then at the start of its line)
p_prevln            bsr       p_bol
                    bsr       p_prev
                    bcs       ppl9
                    bra       p_bol
ppl9                rts

* col_adv: X = the column after character A at column X
col_adv             cmpa      #C$TAB
                    bne       ca1
                    pshs      d
                    tfr       x,d
                    andb      #^(TABW-1)
                    addd      #TABW
                    tfr       d,x
                    puls      d,pc
ca1                 leax      1,x
                    rts

* p_tocol: U at the start of a line; move to display column D or the
* end of the line, whichever comes first.  D = the column reached.
p_tocol             pshs      d,x,y
                    ldx       #0
ptc1                cmpx      ,s
                    bhs       ptc9
                    lbsr      p_char
                    bcs       ptc9
                    cmpa      #C$CR
                    beq       ptc9
                    tfr       x,y
                    bsr       col_adv
                    cmpx      ,s
                    bls       ptc2
                    tfr       y,x                 a tab passes the column: stop on it
                    bra       ptc9
ptc2                lbsr      p_next
                    bra       ptc1
ptc9                stx       ,s
                    puls      d,x,y,pc

* p_col: D = the display column of position U
p_col               pshs      x,y,u
                    tfr       u,y
                    lbsr      a_wpu
                    ldd       ,y
                    std       ,u
                    ldd       2,y
                    std       2,u
                    bsr       p_bol
                    ldx       #0
pcl1                ldd       ,u
                    cmpd      ,y
                    bne       pcl2
                    ldd       2,u
                    cmpd      2,y
                    beq       pcl9
pcl2                lbsr      p_char
                    bcs       pcl9
                    bsr       col_adv
                    lbsr      p_next
                    bra       pcl1
pcl9                tfr       x,d
                    puls      x,y,u,pc

********************************************************************
* Editing at the cursor

* ed_ins: insert A at the cursor and move past it; carry if
* there is no page left for a split
ed_ins              pshs      d,x,y,u
                    ldx       <cpos
                    ldd       DS.USED,x
                    cmpd      #PGSZ
                    blo       ei1
                    lbsr      pg_split
                    bcs       ei_err
                    ldx       <cpos
ei1                 lda       ,s                  (for undo)
                    lbsr      u_ins1
                    lbsr      pg_map              Y = page data
                    ldd       DS.USED,x
                    leau      d,y                 U = end of the text in the page
                    subd      <cpos+2             bytes to move up
                    beq       ei3
                    pshs      x
                    tfr       d,x
ei2                 lda       ,-u
                    sta       1,u
                    leax      -1,x
                    bne       ei2
                    puls      x
ei3                 ldd       <cpos+2
                    leau      d,y
                    lda       ,s
                    sta       ,u
                    ldd       DS.USED,x
                    addd      #1
                    std       DS.USED,x
                    lda       ,s
                    cmpa      #C$CR
                    bne       ei4
                    ldd       DS.LINES,x
                    addd      #1
                    std       DS.LINES,x
                    ldd       <nlines
                    addd      #1
                    std       <nlines
ei4                 lbsr      pg_dirty
                    ldd       <cpos+2
                    lbsr      trk_ins
                    addd      #1
                    std       <cpos+2
                    lbsr      trk_canon
                    andcc     #^Carry
                    puls      d,x,y,u,pc
ei_err              orcc      #Carry
                    puls      d,x,y,u,pc

* ed_del: delete the character at the cursor (A = it); carry at the end
ed_del              pshs      b,x,y,u
                    ldx       <cpos
                    ldd       <cpos+2
                    cmpd      DS.USED,x
                    bhs       edd_eof
                    pshs      d                   (for undo)
                    lbsr      a_cpos
                    lbsr      p_char
                    lbsr      u_del1
                    puls      d
                    lbsr      pg_map
                    leau      d,y                 U = the character
                    lda       ,u
                    sta       <delch
                    ldd       DS.USED,x
                    subd      <cpos+2
                    subd      #1                  bytes after it
                    beq       edd2
                    tfr       d,y
edd1                lda       1,u
                    sta       ,u+
                    leay      -1,y
                    bne       edd1
edd2                ldd       DS.USED,x
                    subd      #1
                    std       DS.USED,x
                    lda       <delch
                    cmpa      #C$CR
                    bne       edd3
                    ldd       DS.LINES,x
                    subd      #1
                    std       DS.LINES,x
                    ldd       <nlines
                    subd      #1
                    std       <nlines
edd3                lbsr      pg_dirty
                    ldd       <cpos+2
                    lbsr      trk_del
                    ldd       DS.USED,x
                    bne       edd5
                    lbsr      pg_remove           empty now
                    bra       edd9
edd5                lbsr      trk_canon
                    lbsr      pg_merge
edd9                lda       <delch
                    andcc     #^Carry
                    puls      b,x,y,u,pc
edd_eof             clra
                    orcc      #Carry
                    puls      b,x,y,u,pc

* pg_split: move the top half of full page X into a new page after it;
* carry if there is no page left
pg_split            pshs      d
                    ldd       #PGHALF
                    bsr       pg_splitat
                    puls      d,pc

* pg_splitat: move the text of page X from offset D on (D below the
* byte count) into a new page after it; tracked positions follow the
* text.  Carry if there is no page left.
pg_splitat          pshs      d,x,y,u
                    std       <soff
                    stx       <sd
                    lbsr      d_alloc
                    bcs       psp_err
                    stx       <sn
                    ldu       <sd
                    ldy       DS.NEXT,u           link the new page after X
                    sty       DS.NEXT,x
                    beq       psp1
                    stx       DS.PREV,y
psp1                stu       DS.PREV,x
                    stx       DS.NEXT,u
                    ldx       <sd
                    lbsr      pg_map              X is now the most recent
                    ldx       <sn
                    lbsr      pg_map
                    tfr       y,u                 U = new page data
                    ldx       <sd
                    lbsr      pg_map
                    ldd       <soff
                    leay      d,y                 Y = the text that moves
                    ldd       DS.USED,x
                    subd      <soff
                    ldx       <sn
                    std       DS.USED,x
                    ldx       #0
                    stx       <tmpc               carriage returns moved
                    tfr       d,x
psp2                lda       ,y+
                    sta       ,u+
                    cmpa      #C$CR
                    bne       psp3
                    lbsr      tmpc_inc
psp3                leax      -1,x
                    bne       psp2
                    ldx       <sn
                    ldd       <tmpc
                    std       DS.LINES,x
                    lbsr      pg_dirty
                    ldx       <sd
                    ldd       DS.LINES,x
                    subd      <tmpc
                    std       DS.LINES,x
                    ldd       <soff
                    std       DS.USED,x
                    lbsr      pg_dirty
                    ldd       <sd
                    std       <tf
                    ldd       <soff
                    std       <tm
                    ldd       <sn
                    std       <tt
                    clra
                    clrb
                    subd      <soff
                    std       <tk
                    lbsr      trk_move
                    andcc     #^Carry
                    puls      d,x,y,u,pc
psp_err             orcc      #Carry
                    puls      d,x,y,u,pc

* pg_cut: remove tk bytes from page X at offset D.  Line counts follow;
* tracked positions inside the cut go to its start, those after it
* move down.
pg_cut              pshs      d,x,y,u
                    lbsr      pg_map
                    leau      d,y                 U = start of the cut
                    ldd       <tk
                    leay      d,u                 Y = end of the cut
                    pshs      y
                    ldy       #0                  carriage returns cut
pct1                cmpu      ,s
                    bhs       pct2
                    lda       ,u+
                    cmpa      #C$CR
                    bne       pct1
                    leay      1,y
                    bra       pct1
pct2                leas      2,s
                    sty       <tmpc
                    ldd       DS.LINES,x
                    subd      <tmpc
                    std       DS.LINES,x
                    ldd       <nlines
                    subd      <tmpc
                    std       <nlines
                    lbsr      pg_map              the rest of the page moves down
                    ldd       ,s
                    leau      d,y                 U = start of the cut
                    addd      <tk
                    leay      d,y                 Y = end of the cut
                    ldd       DS.USED,x
                    subd      ,s
                    subd      <tk                 bytes after the cut
                    beq       pct4
                    pshs      x
                    tfr       d,x
pct3                lda       ,y+
                    sta       ,u+
                    leax      -1,x
                    bne       pct3
                    puls      x
pct4                ldd       DS.USED,x
                    subd      <tk
                    std       DS.USED,x
                    lbsr      pg_dirty
                    ldd       ,s
                    bsr       trk_cut
                    puls      d,x,y,u,pc

* trk_cut: positions in page X at offset D or above move down by tk,
* but not below D
trk_cut             pshs      d,y,u
                    lbsr      a_cpos
                    ldy       #NPOS
tct1                cmpx      ,u
                    bne       tct3
                    ldd       2,u
                    cmpd      ,s
                    blo       tct3
                    subd      <tk
                    bcs       tct2
                    cmpd      ,s
                    bhs       tct2a
tct2                ldd       ,s
tct2a               std       2,u
tct3                leau      4,u
                    leay      -1,y
                    bne       tct1
                    puls      d,y,u,pc

* ed_delto: delete the text from the cursor up to position xpos (which
* is not before it).  Whole pages in between are dropped without being
* read in.
ed_delto            pshs      d,x,y,u
                    lbsr      u_delto
edt1                ldx       <cpos
                    cmpx      <xpos
                    bne       edt3
                    ldd       <xpos+2             the last piece, in one page
                    subd      <cpos+2
                    beq       edt8
                    std       <tk
                    ldd       <cpos+2
                    lbsr      pg_cut
                    bra       edt7
edt3                ldd       <cpos+2             a whole page?
                    bne       edt5
                    ldd       <nlines
                    subd      DS.LINES,x
                    std       <nlines
                    ldd       #0
                    std       DS.USED,x
                    std       DS.LINES,x
                    lda       #1
                    sta       <modif
                    bsr       pg_remove           positions go to the next page
                    bra       edt1
edt5                ldd       DS.USED,x           the end of this page
                    subd      <cpos+2
                    std       <tk
                    ldd       <cpos+2
                    lbsr      pg_cut
                    lbsr      trk_canon           the cursor moves on to the next page
                    bra       edt1
edt7                ldd       DS.USED,x
                    bne       edt7a
                    bsr       pg_remove
                    bra       edt8
edt7a               lbsr      trk_canon
                    bsr       pg_merge
edt8                ldx       <cpos               the pages around the cut may be small
                    bsr       pg_merge
                    ldx       <cpos
                    ldx       DS.PREV,x
                    beq       edt9
                    bsr       pg_merge
edt9                puls      d,x,y,u,pc

* pg_remove: drop empty page X from the chain (unless it is the only one)
pg_remove           pshs      d,x,y,u
                    ldu       DS.NEXT,x
                    ldy       DS.PREV,x
                    cmpu      #0
                    bne       prm1
                    cmpy      #0
                    beq       prm9
prm1                stx       <tf
                    clra
                    clrb
                    std       <tm
                    cmpu      #0
                    beq       prm2
                    stu       <tt                 positions go to the start of the next page
                    ldd       #0
                    std       <tk
                    bra       prm3
prm2                sty       <tt                 or to the end of the previous one
                    ldd       DS.USED,y
                    std       <tk
prm3                lbsr      trk_move
                    lbsr      pg_unlink
                    lbsr      d_free
prm9                puls      d,x,y,u,pc

* pg_merge: if page X is small, join it with a neighbour
pg_merge            pshs      d,x,y,u
                    ldd       DS.USED,x
                    cmpd      #PGLOW
                    bhs       pmg9
                    ldu       DS.NEXT,x
                    beq       pmg2
                    ldd       DS.USED,x
                    addd      DS.USED,u
                    cmpd      #PGFILL
                    bhi       pmg2
                    bsr       pg_join
                    bra       pmg9
pmg2                ldu       DS.PREV,x
                    beq       pmg9
                    ldd       DS.USED,x
                    addd      DS.USED,u
                    cmpd      #PGFILL
                    bhi       pmg9
                    exg       x,u
                    bsr       pg_join
pmg9                puls      d,x,y,u,pc

* pg_join: append page U (the one after X) to page X and drop U
pg_join             pshs      d,x,y,u
                    stx       <sd
                    stu       <sn
                    lbsr      pg_map
                    tfr       u,x
                    lbsr      pg_map
                    tfr       y,u                 U = second page data
                    ldx       <sd
                    lbsr      pg_map
                    ldd       DS.USED,x
                    leay      d,y                 Y = end of the first page
                    ldx       <sn
                    ldd       DS.USED,x
                    beq       pj2
                    tfr       d,x
pj1                 lda       ,u+
                    sta       ,y+
                    leax      -1,x
                    bne       pj1
pj2                 ldd       <sn
                    std       <tf
                    ldd       #0
                    std       <tm
                    ldd       <sd
                    std       <tt
                    ldx       <sd
                    ldd       DS.USED,x
                    std       <tk
                    lbsr      trk_move
                    ldu       <sn
                    ldd       DS.USED,x
                    addd      DS.USED,u
                    std       DS.USED,x
                    ldd       DS.LINES,x
                    addd      DS.LINES,u
                    std       DS.LINES,x
                    lbsr      pg_dirty
                    tfr       u,x
                    lbsr      pg_unlink
                    lbsr      d_free
                    lbsr      trk_canon
                    puls      d,x,y,u,pc

* pg_count: count the carriage returns in page X into DS.LINES and nlines
pg_count            pshs      d,y,u
                    lbsr      pg_map
                    ldu       #0
                    ldd       DS.USED,x
                    beq       pcn9
                    leau      d,y
                    pshs      u                   end
                    ldu       #0
pcn1                lda       ,y+
                    cmpa      #C$CR
                    bne       pcn2
                    leau      1,u
pcn2                cmpy      ,s
                    blo       pcn1
                    leas      2,s
pcn9                stu       DS.LINES,x
                    tfr       u,d
                    addd      <nlines
                    std       <nlines
                    puls      d,y,u,pc

********************************************************************
* Files

* f_load: read fname into a fresh chain of pages.  A missing file (or
* no name) gives an empty text.  Carry (B = error) on a read error.
f_load              lbsr      d_alloc
                    stx       <first
                    ldx       <base
                    leax      fname,x
                    tst       ,x
                    beq       fl_new
                    lda       #READ.
                    os9       I$Open
                    bcc       fl0
                    cmpb      #E$PNNF
                    beq       fl_new
shno4               orcc      #Carry              (shared: carry set, return)
                    rts
fl0                 sta       <flpath
                    ldx       <first
fl1                 lbsr      pg_map
                    pshs      x
                    tfr       y,x
                    ldy       #PGFILL
                    lda       <flpath
                    os9       I$Read
                    puls      x
                    bcs       fl_eof
                    sty       DS.USED,x
                    bsr       pg_count
                    lbsr      pg_dirty
                    cmpy      #PGFILL
                    blo       fl_done
                    tfr       x,u
                    lbsr      d_alloc
                    bcs       fl_err
                    stu       DS.PREV,x
                    stx       DS.NEXT,u
                    bra       fl1
fl_eof              cmpb      #E$EOF
                    bne       fl_err
                    ldy       DS.PREV,x           an empty last page goes
                    beq       fl_done
                    lbsr      pg_unlink
                    lbsr      d_free
fl_done             lda       <flpath
                    os9       I$Close
fl_new              clr       <modif
shok5               andcc     #^Carry             (shared: carry clear, return)
                    rts
fl_err              pshs      b
                    lda       <flpath
                    os9       I$Close
                    clr       <modif
                    puls      b
                    bra       shno4

* f_save: write the text to fname; carry (B = error) on failure
f_save              ldx       <base
                    leax      fname,x
                    lda       #WRITE.
                    ldb       #PREAD.+UPDAT.
                    os9       I$Create
                    bcc       fs1
                    cmpb      #E$CEF
                    bne       fs_err
                    ldx       <base
                    leax      fname,x
                    lda       #WRITE.
                    os9       I$Open
                    bcs       fs_err
                    pshs      a
                    ldb       #SS.Size            cut it to nothing first
                    ldx       #0
                    ldu       #0
                    os9       I$SetStt
                    puls      a
                    bcs       fs_errc0
fs1                 sta       <flpath
                    ldx       <first
fs2                 beq       fs3
                    lbsr      pg_map
                    ldd       DS.USED,x
                    beq       fs2a
                    pshs      x
                    tfr       y,x
                    tfr       d,y
                    lda       <flpath
                    os9       I$Write
                    puls      x
                    bcs       fs_errc
fs2a                ldx       DS.NEXT,x
                    bra       fs2
fs3                 lda       <flpath
                    os9       I$Close
                    bcs       fs_err
                    clr       <modif
                    bra       shok5
fs_errc0            sta       <flpath
fs_errc             pshs      b
                    lda       <flpath
                    os9       I$Close
                    puls      b
fs_err              orcc      #Carry
                    rts
