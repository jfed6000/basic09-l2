********************************************************************
* menu - the menu bar, drop-down menus, dialog boxes, help and the
* File commands

NMENU               equ       8

* Menu titles (ending in an empty string), their Alt letters, and the
* items of each menu.  An item is the handler (an offset from cmdtab),
* its text and the shortcut shown; a handler of 0 is a separator line,
* and $FFFF ends the menu.
mtitle              fcc       "File"
                    fcb       0
                    fcc       "Edit"
                    fcb       0
                    fcc       "Search"
                    fcb       0
                    fcc       "Run"
                    fcb       0
                    fcc       "Compile"
                    fcb       0
                    fcc       "Debug"
                    fcb       0
                    fcc       "Options"
                    fcb       0
                    fcc       "Help"
                    fcb       0
                    fcb       0
mkeys               fcc       "FESRCDOH"

mitems              fdb       mfile-mitems,medit-mitems,msrch-mitems,mrun-mitems
                    fdb       mcomp-mitems,mdbg-mitems,mopt-mitems,mhelp-mitems

mfile               fdb       c_new-cmdtab
                    fcn       "New"
                    fcn       ""
                    fdb       c_open-cmdtab
                    fcn       "Open..."
                    fcn       "^O"
                    fdb       c_save-cmdtab
                    fcn       "Save"
                    fcn       "^S"
                    fdb       c_saveas-cmdtab
                    fcn       "Save as..."
                    fcn       ""
                    fdb       0
                    fdb       c_quit-cmdtab
                    fcn       "Quit"
                    fcn       "^Q"
                    fdb       $FFFF
medit               fdb       c_undo-cmdtab
                    fcn       "Undo"
                    fcn       "^Z"
                    fdb       c_redo-cmdtab
                    fcn       "Redo"
                    fcn       "^Y"
                    fdb       0
                    fdb       c_cut-cmdtab
                    fcn       "Cut"
                    fcn       "^X"
                    fdb       c_copy-cmdtab
                    fcn       "Copy"
                    fcn       "^C"
                    fdb       c_paste-cmdtab
                    fcn       "Paste"
                    fcn       "^V"
                    fdb       c_selall-cmdtab
                    fcn       "Select all"
                    fcn       "^A"
                    fdb       0
                    fdb       c_delln-cmdtab
                    fcn       "Delete line"
                    fcn       "^D"
                    fdb       $FFFF
msrch               fdb       c_find-cmdtab
                    fcn       "Find..."
                    fcn       "^F"
                    fdb       c_fnext-cmdtab
                    fcn       "Find next"
                    fcn       "^L"
                    fdb       c_fprev-cmdtab
                    fcn       "Find previous"
                    fcn       "Shift+^L"
                    fdb       c_repl-cmdtab
                    fcn       "Replace..."
                    fcn       ""
                    fdb       0
                    fdb       c_goto-cmdtab
                    fcn       "Go to line..."
                    fcn       "^G"
                    fdb       $FFFF
mrun                fdb       c_run-cmdtab
                    fcn       "Run"
                    fcn       "^R"
                    fdb       c_tocur-cmdtab
                    fcn       "Go to cursor"
                    fcn       "F4"
                    fdb       c_reset-cmdtab
rstms               fcn       "Program reset"     also dbg.asm's message
                    fcn       "^P"
                    fdb       c_user-cmdtab
                    fcn       "User screen"
                    fcn       "F5"
                    fdb       c_runa-cmdtab
                    fcn       "With arguments..."
                    fcn       ""
                    fdb       $FFFF
mcomp               fdb       c_make-cmdtab
                    fcn       "Make"
                    fcn       "^B"
                    fdb       c_nexterr-cmdtab
                    fcn       "Next error"
                    fcn       "^N"
                    fdb       c_msgwin-cmdtab
                    fcn       "Messages"
                    fcn       "F6"
                    fdb       0
                    fdb       c_pp-cmdtab
                    fcn       "Pretty print"
                    fcn       ""
                    fdb       c_ppall-cmdtab
                    fcn       "All: pretty print"
                    fcn       "^Space"
                    fdb       c_pack-cmdtab
                    fcn       "Pack module..."
                    fcn       ""
                    fdb       $FFFF
mdbg                fdb       c_step-cmdtab
                    fcn       "Trace into"
                    fcn       "F7"
                    fdb       c_over-cmdtab
                    fcn       "Step over"
                    fcn       "F8"
                    fdb       c_retbrk-cmdtab
                    fcn       "Until return..."
                    fcn       ""
                    fdb       c_eval-cmdtab
                    fcn       "Evaluate..."
                    fcn       "^E"
                    fdb       c_watch-cmdtab
                    fcn       "Add watch..."
                    fcn       "^W"
                    fdb       c_wdel-cmdtab
                    fcn       "Delete watch..."
                    fcn       ""
                    fdb       0
                    fdb       c_bptog-cmdtab
                    fcn       "Breakpoint"
                    fcn       "^T"
                    fdb       c_bpclr-cmdtab
                    fcn       "Clear breakpoints"
                    fcn       ""
                    fdb       c_stack-cmdtab
                    fcn       "Procedure calls"
                    fcn       ""
                    fdb       $FFFF
mopt                fdb       c_indent-cmdtab
                    fcn       "Auto indent"
                    fcn       ""
                    fdb       c_mcase-cmdtab
                    fcn       "Match case"
                    fcn       ""
                    fdb       c_colour-cmdtab
                    fcn       "Syntax colours"
                    fcn       ""
                    fdb       c_kwcase-cmdtab
                    fcn       "Keyword case"
                    fcn       ""
                    fdb       c_sptog-cmdtab
spon2               fcn       "Double spacing"    also lspace.asm's message
                    fcn       "^1/^2"
                    fdb       c_scrtog-cmdtab
scrm60              fcn       "80x60 screen"      also lspace.asm's message
                    fcn       ""
                    fdb       c_memory-cmdtab
                    fcn       "Memory..."
                    fcn       ""
                    fdb       c_pause-cmdtab
                    fcn       "Pause after run"
                    fcn       ""
                    fdb       $FFFF
mhelp               fdb       c_help-cmdtab
                    fcn       "Topic at cursor"
                    fcn       "F1"
                    fdb       c_hcont-cmdtab
                    fcn       "Contents"
                    fcn       ""
                    fdb       c_hkeys-cmdtab
                    fcn       "Keys"
                    fcn       ""
                    fdb       c_about-cmdtab
                    fcn       "About"
                    fcn       ""
                    fdb       $FFFF

* c_menu: key A is Alt+letter; open that menu if there is one
c_altkey            suba      #EK.ALT-'A
                    leax      mkeys,pcr
                    clrb
cak1                cmpa      b,x
                    beq       m_open1
                    incb
                    cmpb      #NMENU
                    blo       cak1
                    rts
m_open1             tfr       b,a

* m_open: run menu A until an item is chosen or it is closed
m_open              sta       <mcur
                    ldx       <base               the screen is up to date: no
                    clr       mbox,x              drop-down to clear yet
mo_new              clr       <msel
                    lbsr      m_unbox             clear away the last drop-down
                    lbsr      m_layout
                    lda       <mcur
                    lbsr      v_menubar
mo_draw             lbsr      m_drawbox
                    lbsr      t_curoff
                    lbsr      t_flush
                    lbsr      getkey
                    cmpa      #EK.MOUSE
                    lbeq      mo_mouse
                    cmpa      #EK.ESC
                    beq       mo_close
                    cmpa      #EK.EOF
                    beq       mo_close
                    cmpa      #EK.UP
                    bne       mo1
                    lbsr      m_prev
                    bra       mo_draw
mo1                 cmpa      #EK.DOWN
                    bne       mo2
                    lbsr      m_next
                    bra       mo_draw
mo2                 cmpa      #EK.LEFT
                    bne       mo3
                    lda       <mcur
                    deca
                    bpl       mo2a
                    lda       #NMENU-1
mo2a                sta       <mcur
                    bra       mo_new
mo3                 cmpa      #EK.RIGHT
                    bne       mo4
                    lda       <mcur
                    inca
                    cmpa      #NMENU
                    blo       mo2a
                    clra
                    bra       mo2a
mo4                 cmpa      #EK.ALT             another menu's Alt key
                    blo       mo5
                    cmpa      #EK.ALT+25
                    bhi       mo5
                    suba      #EK.ALT-'A
                    leax      mkeys,pcr
                    clrb
mo4a                cmpa      b,x
                    beq       mo4b
                    incb
                    cmpb      #NMENU
                    blo       mo4a
                    bra       mo_draw
mo4b                stb       <mcur
                    bra       mo_new
mo5                 cmpa      #C$CR
                    beq       mo_run
                    bsr       m_letter            an item's first letter
                    bcs       mo_draw
mo_run              ldb       <msel
                    lbsr      m_item
                    ldd       ,x                  the handler
                    pshs      d
                    bsr       mo_close
                    puls      d
                    leax      cmdtab,pcr
                    jmp       d,x
mo_close            bsr       m_unbox
                    lda       #$FF                the titles back to normal
                    lbra      v_menubar

* m_unbox: redraw what the drop-down covered (if one is shown): only
* the window rows under it, unless it reaches below the text window
m_unbox             ldx       <base
                    tst       mbox,x
                    beq       mub9
                    clr       mbox,x
                    clr       rdlim,x             (0: everything)
                    lda       <mcnt               its bottom row is mcnt+2
                    adda      #2
                    ldb       <wtop
                    addb      <wrows
                    pshs      b
                    cmpa      ,s+
                    bhs       mub1
                    suba      <wtop
                    inca
                    sta       rdlim,x
mub1                lbsr      rd_all
                    lbsr      v_draw
                    ldx       <base
                    clr       rdlim,x
mub9                rts

* m_next, m_prev: move the selection, skipping separators
m_next              lda       <msel
mn1                 inca
                    cmpa      <mcnt
                    blo       mn2
                    clra
mn2                 tfr       a,b
                    bsr       m_item
                    ldx       ,x
                    beq       mn1
                    sta       <msel
                    rts
m_prev              lda       <msel
mp1                 deca
                    bpl       mp2
                    lda       <mcnt
                    deca
mp2                 tfr       a,b
                    bsr       m_item
                    ldx       ,x
                    beq       mp1
                    sta       <msel
                    rts

* m_letter: select the item whose text starts with key A; carry if none
m_letter            cmpa      #'a
                    blo       ml1
                    cmpa      #'z
                    bhi       ml1
                    suba      #$20
ml1                 clrb
mlt2                cmpb      <mcnt
                    bhs       mlt9
                    bsr       m_item
                    ldy       ,x
                    beq       mlt3
                    cmpa      2,x
                    beq       mlt4
mlt3                incb
                    bra       mlt2
mlt4                stb       <msel
                    andcc     #^Carry
                    rts
mlt9                orcc      #Carry
                    rts

* m_first: X = the first item of menu mcur
m_first             leax      mitems,pcr
                    ldb       <mcur
                    aslb
                    ldd       b,x
                    leax      mitems,pcr
                    leax      d,x
                    rts

* m_item: X = item B of menu mcur
m_item              pshs      d
                    bsr       m_first
                    ldb       1,s
mi1                 tstb
                    beq       mi9
                    bsr       m_skip
                    decb
                    bra       mi1
mi9                 puls      d,pc

* m_skip: X past the item at X
m_skip              pshs      a
                    lda       ,x++
                    ora       -1,x
                    beq       ms9                 a separator is just the 0
msk1                lda       ,x+                 text
                    bne       msk1
msk2                lda       ,x+                 shortcut
                    bne       msk2
ms9                 puls      a,pc

* m_layout: mcnt, mwid and mcol for menu mcur
m_layout            bsr       m_first
                    clr       <mcnt
                    lda       #14
                    sta       <mwid
mla1                ldd       ,x
                    cmpd      #$FFFF
                    beq       mla5
                    inc       <mcnt
                    cmpd      #0
                    beq       mla4
                    leay      2,x                 text + shortcut + 3 spaces + 2 borders
                    bsr       strlen
                    pshs      b
                    bsr       strlen
                    addb      ,s+
                    addb      #5
                    cmpb      <mwid
                    bls       mla4
                    stb       <mwid
mla4                bsr       m_skip
                    bra       mla1
mla5                leax      mtitle,pcr          column of the title
                    ldb       #1
                    lda       <mcur
                    pshs      a
mla6                tst       ,s
                    beq       mla8
                    tfr       x,y
                    pshs      b
                    bsr       strlen
                    addb      #2
                    addb      ,s+
                    tfr       y,x
                    dec       ,s
                    bra       mla6
mla8                leas      1,s
                    pshs      b                   keep the box on the screen
                    addb      <mwid
                    cmpb      <scrw
                    puls      b
                    bls       mla9
                    ldb       <scrw
                    subb      <mwid
mla9                stb       <mcol
                    rts

* strlen: B = length of the string at Y; Y past its 0
strlen              clrb
sl1                 tst       ,y+
                    beq       sl9
                    incb
                    bra       sl1
sl9                 rts

* m_drawbox: the drop-down of menu mcur, item msel selected
m_drawbox           ldx       <base
                    inc       mbox,x
                    lda       <mcol
                    sta       <bx.col
                    lda       #1
                    sta       <bx.row
                    lda       <mwid
                    sta       <bx.w
                    lda       <mcnt
                    adda      #2
                    sta       <bx.h
                    lda       #GL.TL1
                    sta       <bx.st
                    lbsr      mi_on               grey, as in Turbo C
                    bsr       bx_draw
                    lbsr      m_first
                    clrb                          item number
mdb1                cmpb      <mcnt
                    bhs       mdb9
                    pshs      b
                    lda       <mcol
                    addb      #2
                    ldy       ,x
                    bne       mdb2
                    lbsr      t_xy                separator: a line across the box
                    lda       <glyphs+GL.LT1
                    lbsr      t_ch
                    ldb       <mwid
                    subb      #2
                    lda       <glyphs+GL.H1
                    lbsr      t_rep
                    lda       <glyphs+GL.RT1
                    lbsr      t_ch
                    bra       mdb8
mdb2                inca
                    lbsr      t_xy
                    lda       ,s
                    cmpa      <msel
                    bne       mdb3
                    lbsr      mi_sel
mdb3                lda       #C$SPAC
                    lbsr      t_ch
                    pshs      x
                    leay      2,x                 text
                    tfr       y,x
                    lbsr      t_str
                    bsr       strlen              Y = the shortcut
                    pshs      b
                    tfr       y,x
                    bsr       strlen
                    pshs      b
                    lda       <mwid               spaces between them
                    suba      #4
                    suba      ,s+
                    suba      ,s+
                    tfr       a,b
                    lda       #C$SPAC
                    lbsr      t_rep
                    lbsr      t_str               the shortcut
                    lda       #C$SPAC
                    lbsr      t_ch
                    lbsr      mi_end
                    puls      x
mdb8                lbsr      m_skip
                    puls      b
                    incb
                    bra       mdb1
mdb9                lbra      mb_off

********************************************************************
* Boxes and dialogs

* bx_draw: a frame at bx.col, bx.row, bx.w by bx.h, style bx.st, with
* the inside cleared
bx_draw             pshs      d,x,y
                    ldx       <base
                    leax      glyphs,x
                    ldb       <bx.st
                    abx                           X = TL TR BL BR H V
                    lda       <bx.col
                    ldb       <bx.row
                    lbsr      t_xy
                    lda       ,x
                    lbsr      t_ch
                    ldb       <bx.w
                    subb      #2
                    lda       4,x
                    lbsr      t_rep
                    lda       1,x
                    lbsr      t_ch
                    ldy       #0                  rows inside (and with double
bxd1                tst       <dblsp              spacing the gap under each row
                    beq       bxd1a               but the last)
                    ldu       <base
                    inc       gapdty,u            (v_gaps clears them again)
                    tfr       y,d
                    addb      <bx.row
                    lda       <bx.col
                    lbsr      t_xyg
                    bsr       bx_mid
bxd1a               leay      1,y
                    tfr       y,d
                    incb
                    cmpb      <bx.h
                    bhs       bxd2
                    tfr       y,d
                    addb      <bx.row
                    lda       <bx.col
                    lbsr      t_xy
                    bsr       bx_mid
                    bra       bxd1
bxd2                ldb       <bx.row
                    addb      <bx.h
                    decb
                    lda       <bx.col
                    lbsr      t_xy
                    lda       2,x
                    lbsr      t_ch
                    ldb       <bx.w
                    subb      #2
                    lda       4,x
                    lbsr      t_rep
                    lda       3,x
                    lbsr      t_ch
                    puls      d,x,y,pc

* bx_mid: a row inside the box: the sides and spaces
bx_mid              lda       5,x
                    lbsr      t_ch
                    ldb       <bx.w
                    subb      #2
                    lda       #C$SPAC
                    lbsr      t_rep
                    lda       5,x
                    lbra      t_ch

* bx_title: string X, centered in the top border of the box
bx_title            pshs      d,x,y
                    tfr       x,y
                    lbsr      strlen
                    addb      #2
                    pshs      b
                    lda       <bx.w
                    suba      ,s+
                    lsra
                    adda      <bx.col
                    ldb       <bx.row
                    lbsr      t_xy
                    lda       #C$SPAC
                    lbsr      t_ch
                    lbsr      t_str
                    lbsr      t_ch
                    puls      d,x,y,pc

* dlg_box: a dialog box of bx.h rows, centered, titled X
dlg_box             pshs      d
                    lda       <scrw
                    suba      #4
                    cmpa      #60
                    bls       dbx1
                    lda       #60
dbx1                sta       <bx.w
                    nega
                    adda      <scrw
                    lsra
                    sta       <bx.col
                    lda       <scrh
                    suba      <bx.h
                    lsra
                    sta       <bx.row
                    lda       #GL.TL2
                    sta       <bx.st
                    lbsr      bx_draw
                    bsr       bx_title
                    puls      d,pc

* dlg_in: ask for a line of text in a dialog titled X.  The answer is in
* inbuf (ending in 0); carry if Esc was pressed.  dlg_inp starts from the
* text already in inbuf; typing a character first replaces it.
dlg_in              pshs      x
                    ldx       <base
                    clr       inbuf,x
                    puls      x
dlg_inp             pshs      x
                    lda       #1
                    sta       <dfirst
din1                lda       #3
                    sta       <bx.h
                    ldx       ,s
                    bsr       dlg_box
                    lda       <bx.col             the answer
                    adda      #2
                    ldb       <bx.row
                    incb
                    lbsr      t_xy
                    lbsr      a_inbx
                    lbsr      t_str
                    lbsr      t_curon
                    lbsr      t_flush
                    lbsr      getkey
                    cmpa      #EK.MOUSE           a press outside the box: Esc
                    bne       din1a
                    lbsr      mu_out
                    bcs       din1
din1a               lbsr      a_inbx
                    tst       <dfirst             the first key typed replaces the text
                    beq       din2
                    clr       <dfirst
                    cmpa      #C$SPAC
                    blo       din2
                    cmpa      #$7E
                    bhi       din2
                    clr       ,x
din2                tst       ,x+                 X = end of the answer
                    bne       din2
                    leax      -1,x
                    cmpa      #C$CR
                    beq       din_ok
                    cmpa      #EK.ESC
                    beq       din_esc
                    cmpa      #EK.EOF
                    beq       din_esc
                    cmpa      #EK.BS
                    bne       din3
                    tfr       x,d
                    subd      <base
                    cmpd      #inbuf
                    beq       din1                nothing to delete
                    clr       ,-x
                    bra       din1
din3                cmpa      #C$SPAC
                    blo       din1
                    cmpa      #$7E
                    bhi       din1
                    pshs      a
                    lda       <bx.w               room left in the box?
                    suba      #5
                    tfr       a,b
                    clra
                    addd      #inbuf
                    pshs      d
                    tfr       x,d
                    subd      <base
                    cmpd      ,s++
                    puls      a
                    lbhs      din1
                    sta       ,x+
                    clr       ,x
                    lbra      din1
din_ok              bsr       dlg_done
                    andcc     #^Carry
                    puls      x,pc
din_esc             bsr       dlg_done
                    orcc      #Carry
                    puls      x,pc
dlg_done            pshs      a                   (dlg_ask returns the answer in A)
                    lbsr      rd_all
                    puls      a,pc

* dlg_ask: ask question X; A = 'Y' or 'N', carry if Esc was pressed
dlg_ask             pshs      x
dak1                lda       #3
                    sta       <bx.h
                    leax      asktl,pcr
                    lbsr      dlg_box
                    lda       <bx.col
                    adda      #2
                    ldb       <bx.row
                    incb
                    lbsr      t_xy
                    ldx       ,s
                    lbsr      t_str
                    lbsr      t_flush
                    lbsr      getkey
                    cmpa      #EK.MOUSE
                    bne       dak2
                    lbsr      mu_out              a press outside the box: Esc
                    bcc       dak2
                    ldx       ,s                  on the Y or N of the question
                    lbsr      mu_ch
                    bcs       dak1
                    cmpa      #'Y
                    beq       dak_ok
                    cmpa      #'N
                    beq       dak_ok
                    bra       dak1
dak2                cmpa      #EK.ESC
                    beq       dak_esc
                    cmpa      #EK.EOF
                    beq       dak_esc
                    anda      #$DF
                    cmpa      #'Y
                    beq       dak_ok
                    cmpa      #'N
                    bne       dak1
dak_ok              bsr       dlg_done
                    andcc     #^Carry
                    puls      x,pc
dak_esc             bsr       dlg_done
                    orcc      #Carry
                    puls      x,pc

* dlg_msg: show message X until a key is pressed
dlg_msg             leay      msgtl,pcr
* dlg_msgt: the same, in a dialog titled Y
dlg_msgt            pshs      x
                    lda       #3
                    sta       <bx.h
                    tfr       y,x
                    lbsr      dlg_box
                    lda       <bx.col
                    adda      #2
                    ldb       <bx.row
                    incb
                    lbsr      t_xy
                    ldx       ,s
                    lbsr      t_str
                    lbsr      t_curoff
                    lbsr      t_flush
                    lbsr      getkd
                    lbsr      dlg_done
                    puls      x,pc

asktl               fcn       "Confirm"
msgtl               fcn       "basic09-l2"

********************************************************************
* Help: the help browser l2b09help (docs/HELP.md) runs on this terminal
* and reads the same keys; the editor waits for it, then redraws

* c_help: the page for the word at the cursor (F1; LEFT$ with its $),
* or the contents if there is none
c_help              lbsr      word_at             to inbuf; Z if none
                    beq       c_hcont
                    lbsr      p_char              (U is past the word)
                    cmpa      #'$
                    bne       chp1
                    sta       ,x+
                    clr       ,x
chp1                lbsr      a_inbx
                    bra       hlp_go
c_hkeys             leax      keystp,pcr          Help > Keys
                    bra       hlp_go
c_hcont             leax      keystp+4,pcr        Help > Contents: no topic
* hlp_go: run "l2b09help -e [-n] <topic X>" and wait for it
hlp_go              pshs      x
                    ldy       <base
                    leay      rline,y
                    leax      hlpe,pcr
                    lbsr      s_cpy
                    tst       <nocolr
                    beq       hg0
                    leax      hlpn,pcr
                    lbsr      s_cpy
hg0                 tst       <hold               (-h for the tests' snapshots)
                    beq       hg1
                    leax      hlph,pcr
                    lbsr      s_cpy
hg1                 puls      x
                    lbsr      s_cpy
                    lda       #C$CR
                    sta       ,y+
                    lbsr      a_rline             U = the parameters, Y = their
                    tfr       y,d                 length
                    pshs      x
                    subd      ,s
                    tfr       d,y
                    puls      u
                    leax      hlpnm,pcr
                    clra
                    clrb
                    lbsr      t_flush
                    os9       F$Fork
                    bcs       hg9
                    pshs      a
hg2                 os9       F$Wait              (l2b09run may end meanwhile)
                    bcc       hg3
                    cmpb      #E$NoChld
                    bne       hg2
                    clrb
                    bra       hg4
hg3                 cmpa      ,s
                    bne       hg2
hg4                 leas      1,s
hg9                 stb       <msgerr             its exit status (or why it did not run)
                    lbsr      hl_set              everything again, in our colours
                    ldx       <base
                    inc       gapdty,x
                    lbra      rd_all
hlpnm               fcc       "l2b09help"
                    fcb       C$CR
hlpe                fcn       "-e "
hlpn                fcn       "-n "
hlph                fcn       "-h "
keystp              fcn       "Keys"

c_about             leax      aboutm,pcr
                    lbra      dlg_msg
aboutm              fcn       "basic09-l2: the l2basic09 editor, edition 1"

********************************************************************
* The File commands and the others the menus need

c_indent            com       <noindt
                    leax      indon,pcr
                    tst       <noindt
                    beq       cin1
                    leax      indoff,pcr
cin1                stx       <msgp
                    rts
* c_pause: wait for a key on the program's screen when a run ends, or
* not (Options)
c_pause             ldx       <base
                    com       nopaus,x
                    leax      pauson,pcr
                    ldy       <base
                    tst       nopaus,y
                    beq       cpa1
                    leax      pausof,pcr
cpa1                stx       <msgp
                    rts
pauson              fcn       "Pause after a run on"
pausof              fcn       "Pause after a run off"
indon               fcn       "Auto indent on"
indoff              fcn       "Auto indent off"

* ask_save: if the text has changed, offer to save it; carry to cancel
ask_save            tst       <modif
                    beq       as9
                    leax      askms,pcr
                    lbsr      dlg_ask
                    bcs       as8
                    cmpa      #'N
                    beq       as9
                    bra       c_save
as8                 rts
as9                 andcc     #^Carry
                    rts
askms               fcn       "Save the changes (Y/N)?"

c_quit              bsr       ask_save
                    bcs       cq9
                    lbra      quit
cq9                 rts

c_new               bsr       ask_save
                    bcs       cn9
                    ldx       <base
                    clr       fname,x
                    bsr       buf_new
cn9                 rts

c_open              bsr       ask_save
                    bcs       co9
                    leax      opentl,pcr
                    lbsr      dlg_in
                    bcs       co9
                    ldx       <base
                    tst       inbuf,x
                    beq       co9
                    bsr       in2name
                    bsr       buf_new
co9                 rts
opentl              fcn       "Open file"

* buf_new: drop the text and load fname (nothing if it has no name)
buf_new             ldx       <first
bn1                 beq       bn2
                    ldy       DS.NEXT,x
                    lbsr      d_free
                    leax      ,y                  (sets Z; tfr would not)
                    bra       bn1
bn2                 lbsr      u_clear
                    lbsr      ms_clear            messages were about the old text
                    lbsr      w_hide
                    ldd       #0
                    std       <nlines
                    lbsr      f_load
                    bcc       bn3
                    stb       <msgerr
bn3                 lbra      buf_top

* c_save: save to fname, asking for a name if there is none; carry if
* it was not saved
c_save              ldx       <base
                    tst       fname,x
                    beq       c_saveas
                    lbsr      f_save
                    bcs       csv_err
                    leax      savedm,pcr
                    stx       <msgp
                    andcc     #^Carry
                    rts
csv_err             stb       <msgerr
                    orcc      #Carry
                    rts
savedm              fcn       "Saved"

c_saveas            leax      savetl,pcr
                    lbsr      dlg_in
                    bcs       csa9
                    ldx       <base
                    tst       inbuf,x
                    beq       csa9
                    bsr       in2name
                    bra       c_save
csa9                orcc      #Carry
                    rts
savetl              fcn       "Save as"

* in2name: the answer in inbuf becomes the file name
in2name             lbsr      a_inbx
                    ldy       <base
                    leay      fname,y
                    ldb       #63
i2n1                lda       ,x+
                    sta       ,y+
                    beq       i2n9
                    decb
                    bne       i2n1
                    clr       ,y
i2n9                rts
