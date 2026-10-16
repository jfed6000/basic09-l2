********************************************************************
* clip - the selection and the clipboard
*
* A selection runs between the anchor (apos, at line aline, display
* column acol) and the cursor.  Any edit ends it first, so the anchor's
* line and column stay right while it is active.
*
* The clipboard is a chain of pages of its own (cfirst), kept in the
* swap file like the text, so it can hold any amount.

* sel_on: start a selection at the cursor (if none is active)
sel_on              tst       <selon
                    bne       son9
                    ldd       <cpos
                    std       <apos
                    ldd       <cpos+2
                    std       <apos+2
                    ldd       <curline
                    std       <aline
                    ldd       <curcol
                    std       <acol
                    inc       <selon
son9                lbra      rd_all

* sel_off: end the selection
sel_off             tst       <selon
                    beq       sof9
                    clr       <selon
                    lbra      rd_all
sof9                rts

* sel_order: carry if the anchor comes before the cursor
sel_order           pshs      d
                    ldd       <aline
                    cmpd      <curline
                    blo       sor1
                    bne       sor0
                    ldd       <acol
                    cmpd      <curcol
                    blo       sor1
sor0                andcc     #^Carry
                    puls      d,pc
sor1                orcc      #Carry
                    puls      d,pc

* sel_bounds: sl/sc and el/ec from the anchor and the cursor
sel_bounds          bsr       sel_order
                    bcc       sbd1
                    ldd       <aline
                    std       <sl
                    ldd       <acol
                    std       <sc
                    ldd       <curline
                    std       <el
                    ldd       <curcol
                    std       <ec
                    rts
sbd1                ldd       <curline
                    std       <sl
                    ldd       <curcol
                    std       <sc
                    ldd       <aline
                    std       <el
                    ldd       <acol
                    std       <ec
                    rts

* sel_del: delete the selected text; carry if there was a selection
sel_del             tst       <selon
                    beq       sdl9
                    clr       <selon
                    lbsr      rd_all
                    bsr       sel_order
                    bcc       sdl1
                    ldd       <cpos               the anchor comes first
                    std       <xpos
                    ldd       <cpos+2
                    std       <xpos+2
                    ldd       <apos
                    std       <cpos
                    ldd       <apos+2
                    std       <cpos+2
                    ldd       <aline
                    std       <curline
                    bra       sdl2
sdl1                ldd       <apos
                    std       <xpos
                    ldd       <apos+2
                    std       <xpos+2
sdl2                lbsr      ed_delto
                    orcc      #Carry
                    rts
sdl9                andcc     #^Carry
                    rts

* Moving with Shift extends the selection; moving without it ends it
c_sup               lbsr      sel_on
                    lbra      c_up
c_sdown             lbsr      sel_on
                    lbra      c_down
c_sleft             lbsr      sel_on
                    lbra      c_left
c_sright            lbsr      sel_on
                    lbra      c_right
c_swleft            lbsr      sel_on
                    lbra      c_wleft
c_swright           lbsr      sel_on
                    lbra      c_wright
k_up                lbsr      sel_off
                    lbra      c_up
k_down              lbsr      sel_off
                    lbra      c_down
k_left              lbsr      sel_off
                    lbra      c_left
k_right             lbsr      sel_off
                    lbra      c_right
k_wleft             lbsr      sel_off
                    lbra      c_wleft
k_wright            lbsr      sel_off
                    lbra      c_wright
k_pgup              lbsr      sel_off
                    lbra      c_pgup
k_pgdn              lbsr      sel_off
                    lbra      c_pgdn
k_top               lbsr      sel_off
                    lbra      c_top
k_bottom            lbsr      sel_off
                    lbra      c_bottom
k_home              lbsr      sel_off
                    lbra      c_home
k_end               lbsr      sel_off
                    lbra      c_end
c_esc               lbra      sel_off

* c_selall: select the whole text
c_selall            ldd       <first
                    std       <apos
                    ldd       #0
                    std       <apos+2
                    std       <aline
                    std       <acol
                    lda       #1
                    sta       <selon
                    lbsr      c_bottom
                    lbra      rd_all

c_copy              tst       <selon
                    beq       ccp9
                    bsr       clip_copy
                    bcc       ccp9
                    lbra      c_full
ccp9                rts

c_cut               tst       <selon
                    beq       cct9
                    bsr       clip_copy
                    bcc       cct1
                    lbra      c_full
cct1                lbra      sel_del
cct9                rts

* clip_free: empty the clipboard
clip_free           ldx       <cfirst
                    bsr       chain_free
                    stx       <cfirst
                    rts

* chain_free: give back the page chain at X; X = 0
chain_free          pshs      y
                    leax      ,x
cf1                 beq       cf9
                    ldy       DS.NEXT,x
                    lbsr      d_free
                    leax      ,y
                    bra       cf1
cf9                 puls      y,pc

* clip_copy: copy the selection to the clipboard; carry if the pages ran
* out (the clipboard then holds the start of it)
clip_copy           bsr       clip_free
                    lbsr      sel_order
                    bcc       cpy1
                    ldd       <apos               from the anchor to the cursor
                    std       <wp
                    ldd       <apos+2
                    std       <wp+2
                    ldd       <cpos
                    std       <cend
                    ldd       <cpos+2
                    std       <cend+2
                    bra       cpy2
cpy1                lbsr      cp_wp               from the cursor to the anchor
                    ldd       <apos
                    std       <cend
                    ldd       <apos+2
                    std       <cend+2
cpy2                bsr       chain_copy
                    stx       <cfirst
                    rts

* chain_copy: copy the text from wp to cend into a new page chain, X;
* carry if the pages ran out (X then holds the start of it, or is 0)
chain_copy          ldd       #0
                    std       <chead
                    lbsr      d_alloc
                    lbcs      cpy_full
                    stx       <chead
                    stx       <ctail
cpy3                ldx       <wp                 bytes to copy from this page
                    ldd       DS.USED,x
                    cmpx      <cend
                    bne       cpy4
                    ldd       <cend+2
cpy4                subd      <wp+2
                    std       <ccnt
cpy5                ldd       <ccnt
                    beq       cpy9
                    ldx       <ctail              room in the clipboard page
                    ldd       #PGFILL
                    subd      DS.USED,x
                    bne       cpy6
                    tfr       x,u                 full: a new one
                    lbsr      d_alloc
                    lbcs      cpy_full
                    stu       DS.PREV,x
                    stx       DS.NEXT,u
                    stx       <ctail
                    ldd       #PGFILL
cpy6                cmpd      <ccnt
                    bls       cpy7
                    ldd       <ccnt
cpy7                std       <ck                 bytes this time
                    ldx       <wp
                    lbsr      pg_map
                    ldx       <ctail
                    lbsr      pg_map
                    ldd       DS.USED,x
                    leau      d,y                 U = end of the clipboard page
                    ldx       <wp
                    lbsr      pg_map
                    ldd       <wp+2
                    leay      d,y                 Y = the text
                    ldx       <ck
                    pshs      x
                    ldx       #0                  carriage returns
cpy8                lda       ,y+
                    sta       ,u+
                    cmpa      #C$CR
                    bne       cpy8a
                    leax      1,x
cpy8a               ldd       ,s
                    subd      #1
                    std       ,s
                    bne       cpy8
                    leas      2,s
                    tfr       x,d
                    ldx       <ctail
                    addd      DS.LINES,x
                    std       DS.LINES,x
                    ldd       DS.USED,x
                    addd      <ck
                    std       DS.USED,x
                    ldy       DS.CE,x             dirty, but the text is not modified
                    lda       #1
                    sta       CE.DIRT,y
                    ldd       <wp+2
                    addd      <ck
                    std       <wp+2
                    ldd       <ccnt
                    subd      <ck
                    std       <ccnt
                    bra       cpy5
cpy9                ldx       <wp                 on to the next page, or done
                    cmpx      <cend
                    beq       cpy_ok
                    ldx       DS.NEXT,x
                    beq       cpy_ok
                    stx       <wp
                    ldd       #0
                    std       <wp+2
                    lbra      cpy3
cpy_ok              ldx       <chead
                    andcc     #^Carry
                    rts
cpy_full            ldx       <chead
                    orcc      #Carry
                    rts

* c_paste: insert the clipboard at the cursor (replacing a selection)
c_paste             ldx       <cfirst
                    lbeq      cps9
                    lbsr      sel_del
                    ldx       <cfirst

* chain_paste: insert a copy of page chain X at the cursor, leaving the
* cursor after it (recorded for undo)
chain_paste         stx       <pchain
                    lbsr      a_cpos
                    lbsr      pos2abs
                    lda       <ua
                    sta       <uoff
                    ldd       <ua+1
                    std       <uoff+1
                    clr       <ulen
                    ldd       #0
                    std       <ulen+1
                    clr       <ptpat              is the window's top line here?
                    ldd       <tpos
                    cmpd      <cpos
                    bne       cps1
                    ldd       <tpos+2
                    cmpd      <cpos+2
                    bne       cps1
                    inc       <ptpat
cps1                clr       <peof
                    ldx       <cpos
                    ldd       <cpos+2
                    beq       cps3                at the start of a page: insert before it
                    cmpd      DS.USED,x
                    bhs       cps2
                    lbsr      pg_splitat          inside one: split it there
                    lbcs      c_full
                    ldx       <cpos
                    bra       cps3
cps2                stx       <pprev              at the end of the text
                    ldd       #0
                    std       <pnext
                    inc       <peof
                    bra       cps4
cps3                ldd       DS.PREV,x
                    std       <pprev
                    stx       <pnext
cps4                ldd       #0
                    std       <pfirst
                    ldd       <pchain
                    std       <ctail              (walks the chain)
cps5                ldx       <ctail
                    lbeq      cps8
                    ldd       DS.USED,x
                    beq       cps7
                    lbsr      d_alloc             a copy of this clipboard page
                    lbcs      cps_full
                    stx       <sn
                    ldx       <ctail
                    lbsr      pg_map
                    ldx       <sn
                    lbsr      pg_map
                    tfr       y,u
                    ldx       <ctail
                    lbsr      pg_map
                    ldd       DS.USED,x
                    pshs      d
                    tfr       d,x
cps6                lda       ,y+
                    sta       ,u+
                    leax      -1,x
                    bne       cps6
                    puls      d
                    ldx       <sn
                    std       DS.USED,x
                    addd      <ulen+1             (for undo)
                    std       <ulen+1
                    bcc       cps6d
                    inc       <ulen
cps6d               ldd       DS.USED,x
                    ldu       <ctail
                    ldd       DS.LINES,u
                    std       DS.LINES,x
                    addd      <nlines
                    std       <nlines
                    ldd       DS.LINES,x
                    addd      <curline
                    std       <curline
                    lbsr      pg_dirty
                    ldu       <pprev              link it in
                    stu       DS.PREV,x
                    ldy       <pnext
                    sty       DS.NEXT,x
                    cmpu      #0
                    bne       cps6a
                    stx       <first
                    bra       cps6b
cps6a               stx       DS.NEXT,u
cps6b               cmpy      #0
                    beq       cps6c
                    stx       DS.PREV,y
cps6c               stx       <pprev
                    ldd       <pfirst
                    bne       cps7
                    stx       <pfirst
cps7                ldx       <ctail
                    ldx       DS.NEXT,x
                    stx       <ctail
                    lbra      cps5
cps8                tst       <peof
                    beq       cps8a
                    ldx       <pprev              the cursor goes to the new end
                    stx       <cpos
                    ldd       DS.USED,x
                    std       <cpos+2
                    bra       cps8b
cps8a               ldx       <pnext              an empty page left behind goes
                    ldd       DS.USED,x
                    bne       cps8b
                    lbsr      pg_remove
cps8b               tst       <ptpat
                    beq       cps8c
                    ldx       <pfirst
                    beq       cps8c
                    stx       <tpos
                    ldd       #0
                    std       <tpos+2
cps8c               lbsr      u_paste
                    lbra      rd_all
cps9                rts
cps_full            bsr       cps8
                    lbra      c_full
