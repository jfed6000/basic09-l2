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
spon2               fcn       "Double spacing"
spsmall             fcn       "The screen is too small for double spacing"
