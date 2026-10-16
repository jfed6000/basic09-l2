********************************************************************
* lspace - double spacing (Ctrl+2), as in te
*
* The 8x8 font has no space between its rows, so text can be drawn on
* every other row: the editor lays itself out for half the screen's
* rows (scrh) and t_xy doubles the row.  The screen's size never
* changes.  Only the gap rows that something solid crosses are drawn:
* the side borders and the scroll bar (v_gaps, sb_upd), the menu bar,
* and the inside of a box (bx_draw; v_gaps clears them after).

* c_sp1, c_sp2, c_sptog: single, double, the other one
c_sptog             lda       <dblsp
                    eora      #1
                    bra       c_sp
c_sp1               clra
                    bra       c_sp
c_sp2               lda       #1
c_sp                cmpa      <dblsp
                    beq       csp9
                    bsr       sp_set
                    lbsr      w_fits0             room for the text window?
                    bcc       csp1
                    lbsr      w_hide              no: without the messages
                    lbsr      w_fits0
                    bcc       csp1
                    lda       <dblsp              still not: back
                    eora      #1
                    bsr       sp_set
                    leax      spsmall,pcr
                    bra       csp2
csp1                lbsr      t_cls
                    lbsr      w_layout
                    leax      spon1,pcr
                    tst       <dblsp
                    beq       csp2
                    leax      spon2,pcr
csp2                stx       <msgp
csp9                rts

* sp_set: double spacing A (0 or 1): scrh and the mouse's rows
sp_set              sta       <dblsp
                    ldx       <base
                    ldb       phrows,x
                    tsta
                    beq       sps1
                    lsrb
sps1                stb       <scrh
                    ifeq      coco3
                    ldx       <base
                    tst       muon,x
                    beq       sps9
                    lbra      mu_rows
                    endc
sps9                rts

spon1               fcn       "Single spacing"
spsmall             fcn       "The screen is too small for double spacing"

********************************************************************
* The screen size: Options > 80x60 screen switches between 80x30 and
* 80x60 (VTIO DWSet, so the terminal's own size changes with it);
* t_done puts back the type the editor started with.  Only on a
* terminal whose colours are known (hlok), since DWSet sets them.

c_scrtog            ldx       <base
                    tst       hlok,x
                    beq       cst_no
                    lda       #4                  80x30 -> 80x60, else 80x30
                    ldb       <scrw
                    cmpb      #80
                    bne       cst1
                    ldb       phrows,x
                    cmpb      #30
                    beq       cst2
cst1                lda       #2
cst2                lbsr      t_dwset
                    lbsr      t_size              the new size, from the terminal
                    ifeq      coco3
                    ldu       <base               the mouse's columns (80 now)
                    tst       muon,u
                    beq       cst1a
                    ldx       #640
                    ldb       <scrw
                    lbsr      mu_shift
                    ldu       <base
                    sta       musx,u
cst1a               equ       *
                    endc
                    lda       <dblsp
                    lbsr      sp_set              (halved with double spacing)
                    lbsr      w_fits0
                    bcc       cst3
                    lbsr      w_hide
                    lbsr      w_fits0
                    bcc       cst3
                    clra                          too small even so: single spacing
                    lbsr      sp_set
cst3                lbsr      hl_set              DWSet changed the colours and
                    lbsr      t_cls               cleared in the terminal's
                    lbsr      w_layout
                    ldx       <base
                    leax      scrm30,pcr
                    lda       <scrh
                    tst       <dblsp
                    beq       cst4
                    lsla
cst4                cmpa      #60
                    bne       cst5
                    leax      scrm60,pcr
cst5                stx       <msgp
                    rts
cst_no              leax      scrmno,pcr
                    stx       <msgp
                    rts

scrm30              fcn       "80x30 screen"
scrmno              fcn       "The screen size cannot be changed here"
