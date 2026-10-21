********************************************************************
* sbar - the scroll bar
*
* The text window's right border is its scroll bar, as in Turbo C, so
* no column of text is given up: an arrow at each end, a track between
* them and a thumb in it for where the window is in the text.  When the
* thumb moves only its old and new cells are drawn (a scroll redraws the
* text, not the frame: RD.TEXT); the whole bar after the frame was.  It
* needs a window of 4 rows or more.  The mouse: an arrow scrolls a line, the
* track a window's worth towards the pointer, both again while the
* button is held; dragging the thumb moves through the text.

SB.UP               equ       0                   sb_gl glyphs
SB.DN               equ       1
SB.TRK              equ       2
SB.THM              equ       3
MS.UP               equ       1                   musb: what a press on the bar does
MS.DN               equ       2
MS.PGUP             equ       3
MS.PGDN             equ       4
MS.THM              equ       5

* sb_geo: B = thumb positions - 1 (wrows-3), X = the highest top line;
* carry if the window is too small for a bar
sb_geo              ldb       <wrows
                    cmpb      #4
                    blo       sbg_no
                    clra
                    pshs      d
                    ldd       <nlines             lines - rows, at least 0
                    addd      #1
                    subd      ,s++
                    bcc       sbg1
                    clra
                    clrb
sbg1                tfr       d,x
                    ldb       <wrows
                    subb      #3
shok4               andcc     #^Carry             (shared: carry clear, return)
                    rts
sbg_no              orcc      #Carry
                    rts

* sb_pos: B = the thumb's position (0 to wrows-3) for top line D; carry
* if there is no bar
sb_pos              pshs      d
                    bsr       sb_geo
                    bcs       sbp_no
                    leax      ,x
                    beq       sbp_top             it all fits
                    cmpx      ,s
                    bls       sbp_end             at or past the highest top line
                    tfr       x,y
                    puls      x
                    lbsr      muldiv              top * (wrows-3) / highest
                    bra       shok4
sbp_top             clrb
sbp_end             leas      2,s
                    bra       shok4
sbp_no              leas      2,s
                    rts

sbu_x               rts                           (sb_upd's early exit, in reach)

* sb_upd: if the thumb moved, move it: its old cell becomes track and
* the new one thumb.  After v_frame (which forgets where it was) the
* whole bar is drawn.
sb_upd              ldd       <topline
                    bsr       sb_pos
                    bcs       sbu_x
                    ldx       <base
                    cmpb      sbpos,x
                    beq       sbu_x
                    lda       sbpos,x
                    stb       sbpos,x
                    lbsr      fr_on
                    cmpa      #$FF
                    beq       sbu0
                    pshs      b                   the bar is there: two cells
                    tfr       a,b
                    lda       #SB.TRK
                    bsr       sb_cell
                    puls      b
                    lda       #SB.THM
                    bsr       sb_cell
                    lbra      hl_norm
sbu0                clr       ,-s                 ,s = the row in the window
sbu1                lda       <scrw
                    deca
                    ldb       ,s
                    addb      <wtop
                    lbsr      t_xy
                    lda       #SB.UP
                    ldb       ,s
                    beq       sbu2
                    lda       #SB.DN
                    incb
                    cmpb      <wrows
                    beq       sbu2
                    lda       #SB.TRK
                    decb
                    decb
                    ldx       <base
                    cmpb      sbpos,x
                    bne       sbu2
                    lda       #SB.THM
sbu2                bsr       sb_gl
                    lbsr      t_ch
                    tst       <dblsp              the gap under it: the track,
                    beq       sbu3                the thumb under the thumb, the
                    lda       <scrw               border under the down arrow
                    deca
                    ldb       ,s
                    addb      <wtop
                    lbsr      t_xyg
                    ldb       ,s
                    incb
                    lda       <glyphs+GL.V2
                    cmpb      <wrows
                    beq       sbu2b
                    lda       #SB.TRK
                    decb
                    decb
                    ldx       <base
                    cmpb      sbpos,x
                    bne       sbu2a
                    lda       #SB.THM
sbu2a               bsr       sb_gl
sbu2b               lbsr      t_ch
sbu3                inc       ,s
                    lda       ,s
                    cmpa      <wrows
                    blo       sbu1
                    leas      1,s
                    lbra      hl_norm

* sb_cell: glyph A at track place B (and in the gap under it with
* double spacing, as the full bar has it)
sb_cell             pshs      d
                    lda       <scrw
                    deca
                    ldb       1,s
                    addb      <wtop
                    incb
                    lbsr      t_xy
                    lda       ,s
                    bsr       sb_gl
                    lbsr      t_ch
                    tst       <dblsp
                    beq       sbc9
                    lda       <scrw
                    deca
                    ldb       1,s
                    addb      <wtop
                    incb
                    lbsr      t_xyg
                    lda       ,s
                    bsr       sb_gl
                    lbsr      t_ch
sbc9                puls      d,pc

* sb_gl: A = the character for scroll bar glyph A
sb_gl               tst       <glyok
                    beq       sgl1
                    adda      #GLYPH0+NGL1
                    rts
sgl1                leax      sb_asc,pcr
                    lda       a,x
                    rts
sb_asc              fcc       "^v:#"

* muldiv: D = X * B / Y (Y not 0; the quotient must fit 16 bits)
muldiv              pshs      b,x,y               3,s = B, 4,s = X, 6,s = Y
                    leas      -3,s                0-2,s = the product
                    lda       5,s
                    ldb       3,s
                    mul
                    std       1,s
                    clr       ,s
                    lda       4,s
                    ldb       3,s
                    mul
                    addd      ,s
                    std       ,s
                    ldd       #0                  divide: D = the remainder
                    ldx       #24
mdv1                lsl       2,s                 the quotient's bits shift in
                    rol       1,s                 as the product's shift out
                    rol       ,s
                    rolb
                    rola
                    bcs       mdv2                past 16 bits: more than Y
                    cmpd      6,s
                    blo       mdv3
mdv2                subd      6,s
                    inc       2,s
mdv3                leax      -1,x
                    bne       mdv1
                    ldd       1,s
                    leas      8,s
                    rts

* cmu_sb: a press on the bar at window row B
cmu_sb              ldx       <base
                    lbsr      mu_isdn
                    bne       csb9
                    pshs      b
                    ldd       <topline
                    lbsr      sb_pos
                    puls      a                   A = the row, B = the thumb
                    bcs       csb9
                    ldx       <base
                    tsta
                    beq       csb_up
                    inca
                    cmpa      <wrows
                    beq       csb_dn
                    suba      #2                  A = the place in the track
                    pshs      b
                    cmpa      ,s+
                    blo       csb_pu
                    bhi       csb_pd
                    lda       #MS.THM             the thumb: drag it
                    sta       musb,x
                    lbra      sel_off
csb_up              lda       #MS.UP
                    bra       csb1
csb_dn              lda       #MS.DN
                    bra       csb1
csb_pu              lda       #MS.PGUP
                    bra       csb1
csb_pd              lda       #MS.PGDN
csb1                sta       musb,x
                    inc       murep,x             again while it is held

* sb_act: what musb asks for, once
sb_act              lbsr      sel_off
                    ldx       <base
                    lda       musb,x
                    cmpa      #MS.UP
                    bne       sba1
                    ldb       #1
                    lbra      cpu1
sba1                cmpa      #MS.DN
                    bne       sba2
                    ldb       #1
                    lbra      cpd1
sba2                pshs      a                   a page, while the thumb is not
                    ldd       <topline            yet at the pointer
                    lbsr      sb_pos
                    ldx       <base
                    lda       muy,x
                    suba      <wtop
                    deca
                    pshs      b
                    cmpa      ,s+
                    puls      b                   B = MS.PGUP or MS.PGDN
                    beq       csb9
                    bhi       sba3
                    cmpb      #MS.PGUP
                    lbeq      c_pgup
csb9                rts
sba3                cmpb      #MS.PGDN
                    lbeq      c_pgdn
                    rts

* cmu_sbdrag: the button is still held after a press on the bar (X =
* base)
cmu_sbdrag          lda       musb,x
                    cmpa      #MS.THM
                    bne       sb_act
                    clr       murep,x             the thumb: the top line for
                    lbsr      sb_geo              the pointer's place in the track
                    bcs       csd9
                    pshs      b,x                 ,s = positions - 1, 1,s = highest
                    ldx       <base
                    lda       muy,x
                    suba      <wtop
                    suba      #1
                    bcc       csd1
                    clra
csd1                cmpa      ,s
                    bls       csd2
                    lda       ,s
csd2                ldb       ,s
                    pshs      a                   ,s = the place
                    clra
                    tfr       d,y
                    ldb       ,s
                    ldx       2,s
                    leas      4,s
                    lbsr      muldiv              highest * place / (positions - 1)
                    lbsr      goto_line
                    lbsr      cp_tp
                    ldd       <curline
                    std       <topline
                    lbra      rd_text
csd9                rts
