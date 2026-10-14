********************************************************************
* mouse - the mouse
*
* grfdrv's SS.Mouse GetStat returns the pointer in pixels (X 0-639,
* Y 0-479) and the buttons in A (1 left, 2 right, 4 middle).  Only the
* terminal on the screen gets the buttons, so a click meant for another
* terminal never reaches the editor.  There are no mouse events: while
* it waits for a key the editor polls, SS.Ready on the key path, then
* SS.Mouse, then a tick's sleep.  A change of the buttons, or a move to
* another cell with the left button held, is an event: getkey returns
* EK.MOUSE, with the event in muev and its cell in mux, muy.
*
* A key script (keys not from a terminal) sends the mouse as
* $FE <buttons> <column> <row>, in cells.  Its clock does not run, so
* a second press on the same cell is always a double click there.

MV.DOWN             equ       1                   left button pressed
MV.DRAG             equ       2                   moved to another cell with it held (or a repeat)
MV.UP               equ       3                   left button released
MV.RDOWN            equ       4                   right button pressed
MB.LEFT             equ       $01                 SS.Mouse buttons
MB.RIGHT            equ       $02
DBLTK               equ       30                  ticks for a double click
REPTK               equ       4                   ticks between repeated drags (scrolling)

* mu_init: poll the mouse if the keys come from a terminal that has one
mu_init             ldu       <base
                    lda       #$FF                no press yet
                    sta       mulc,u
                    ifeq      coco3               (the CoCo 3's SS.Mouse is another call)
                    tst       <kbterm
                    beq       mui9
                    lda       <kbpath
                    ldb       #SS.Mouse
                    os9       I$GetStt            A = buttons
                    bcs       mui9                no mouse
                    sta       mubtn,u             held now: not a press
                    ldx       #640                pixels per cell, as shifts
                    ldb       <scrw
                    bsr       mu_shift
                    sta       musx,u
                    inc       muon,u
                    endc

* mu_rows: the shift down for scrh rows (a double-spaced row is two)
mu_rows             ldx       #480
                    ldb       <scrh
                    bsr       mu_shift
                    ldu       <base
                    sta       musy,u
mui9                rts

* mu_shift: A = log2(X pixels / B cells), rounded down (8 or 16 pixels
* a cell; 400-line modes have 25 or 50 rows, which round down too)
mu_shift            clra
                    pshs      d
                    tfr       x,d
                    ldx       #0
msh1                subd      ,s
                    bcs       msh2
                    leax      1,x
                    bra       msh1
msh2                tfr       x,d
                    clra
msh3                lsrb
                    beq       msh4
                    inca
                    bra       msh3
msh4                leas      2,s
                    rts

* mu_wait: wait for a key or a mouse event; carry = a mouse event
mu_wait             ldx       <base
                    tst       muon,x
                    beq       muw9
muw1                lda       <kbpath
                    ldb       #SS.Ready
                    os9       I$GetStt
                    bcc       muw9                a key
                    cmpb      #E$NotRdy
                    bne       muw9                (the read reports it)
                    bsr       mu_poll
                    bcs       muw8
                    ldx       #1
                    os9       F$Sleep
                    ldx       <base
                    ldd       mutick,x
                    addd      #1
                    std       mutick,x
                    bra       muw1
muw8                rts
muw9                andcc     #^Carry
                    rts

* mu_poll: read the mouse; carry = an event
mu_poll             lda       <kbpath
                    ldb       #SS.Mouse
                    os9       I$GetStt            X, Y = pixels, A = buttons
                    bcs       muw9
                    pshs      a,y                 ,s = buttons, 1,s = Y
                    tfr       x,d
                    ldu       <base
                    leau      musx,u
                    bsr       mu_cell
                    cmpb      <scrw
                    blo       mup1
                    ldb       <scrw
                    decb
mup1                pshs      b                   ,s = column
                    ldd       2,s
                    leau      1,u                 musy
                    bsr       mu_cell
                    cmpb      <scrh
                    blo       mup2
                    ldb       <scrh
                    decb
mup2                puls      a                   A = column, B = row
                    tfr       d,x
                    puls      a                   buttons
                    leas      2,s
                    bra       mu_new

* mu_cell: B = pixels D shifted right by the count at U ($FF if that is
* still above 255)
mu_cell             pshs      d
                    lda       ,u
                    beq       mce2
mce1                lsr       ,s
                    ror       1,s
                    deca
                    bne       mce1
mce2                puls      d
                    tsta
                    beq       mce9
                    ldb       #$FF
mce9                rts

* mu_new: the mouse is now A = buttons, X = cell (column, row).  Carry
* if that is an event (muev, mux and muy, mudbl).
mu_new              ldu       <base
                    ldy       mux,u               Y = the cell before
                    stx       mux,u
                    ldb       mubtn,u             B = the buttons before
                    sta       mubtn,u
                    bita      #MB.LEFT
                    beq       mun3
                    bitb      #MB.LEFT
                    beq       mun_down            pressed
                    cmpy      mux,u               held: moved to another cell?
                    bne       mun_drag
                    tst       murep,u             held still: repeat?
                    beq       mun_no
                    dec       murept,u
                    bne       mun_no
                    bra       mun_drag
mun3                bitb      #MB.LEFT
                    bne       mun_up              released
                    bita      #MB.RIGHT
                    beq       mun_no
                    bitb      #MB.RIGHT
                    bne       mun_no
                    lda       #MV.RDOWN
                    bra       mun_ev
mun_down            clr       mudbl,u
                    ldd       mulc,u              the same cell as the last press,
                    cmpd      mux,u               soon enough?
                    bne       mund1
                    ldd       mutick,u
                    subd      mult,u
                    cmpd      #DBLTK
                    bhs       mund1
                    inc       mudbl,u
                    ldd       #$FFFF              a third press starts again
                    bra       mund2
mund1               ldd       mux,u
mund2               std       mulc,u
                    ldd       mutick,u
                    std       mult,u
                    lda       #MV.DOWN
                    bra       mun_ev
mun_drag            lda       #MV.DRAG
                    bra       mun_ev
mun_up              lda       #MV.UP
mun_ev              sta       muev,u
                    lda       #REPTK
                    sta       murept,u
                    orcc      #Carry
                    rts
mun_no              andcc     #^Carry
                    rts

* getkd: getkey, but of the mouse only a press (a click dismisses)
getkd               lbsr      getkey
                    cmpa      #EK.MOUSE
                    bne       gkd9
                    ldx       <base
                    ldb       muev,x
                    cmpb      #MV.DOWN
                    bne       getkd
gkd9                rts

********************************************************************
* Where a click lands

* mu_title: B = the menu whose title is at column A; carry if none
mu_title            leay      mtitle,pcr
                    deca                          the first one starts at column 1
                    bmi       mut_no
                    clr       ,-s                 ,s = the menu
mut1                tst       ,y
                    beq       mut_no1
                    lbsr      strlen              B = its length
                    addb      #2                  and a space each side
                    pshs      b
                    suba      ,s+
                    bcs       mut_hit
                    inc       ,s
                    bra       mut1
mut_hit             puls      b
                    andcc     #^Carry
                    rts
mut_no1             leas      1,s
mut_no              orcc      #Carry
                    rts

* mu_inbox: carry unless column A, row B is in the open menu's box
mu_inbox            pshs      d
                    tstb
                    beq       mub_no
                    ldb       <mcnt               rows 1 to mcnt+2
                    addb      #2
                    cmpb      1,s
                    blo       mub_no
                    suba      <mcol
                    bcs       mub_no
                    cmpa      <mwid
                    bhs       mub_no
                    puls      d
                    andcc     #^Carry
                    rts
mub_no              puls      d
                    orcc      #Carry
                    rts

* mu_item: B = the open menu's item at column A, row B; carry if that is
* not an item (or is a separator)
mu_item             bsr       mu_inbox
                    bcs       mui_no
                    subb      #2
                    bcs       mui_no
                    cmpb      <mcnt
                    bhs       mui_no
                    lbsr      m_item
                    ldx       ,x
                    beq       mui_no
                    andcc     #^Carry
                    rts
mui_no              orcc      #Carry
                    rts

* mu_msg: B = the message on screen row B; carry if none
mu_msg              tst       <msgon
                    beq       mum_no
                    lda       <wtop               its first row
                    adda      <wrows
                    adda      <wwh
                    adda      #2
                    pshs      a
                    subb      ,s+
                    bcs       mum_no
                    cmpb      #MH-2
                    bhs       mum_no
                    addb      <msgtop
                    cmpb      <nmsg
                    bhs       mum_no
                    andcc     #^Carry
                    rts
mum_no              orcc      #Carry
                    rts

* mu_out: A = EK.ESC and no carry if the event is a press outside the
* box at bx.col, bx.row (bx.w by bx.h); carry otherwise
mu_out              ldx       <base
                    lda       muev,x
                    cmpa      #MV.DOWN
                    bne       muo_no
                    ldd       mux,x
                    suba      <bx.col
                    cmpa      <bx.w
                    bhs       muo_yes
                    subb      <bx.row
                    cmpb      <bx.h
                    bhs       muo_yes
muo_no              orcc      #Carry
                    rts
muo_yes             lda       #EK.ESC
                    andcc     #^Carry
                    rts

* mu_ch: A = the character of string X (a dialog's line, at column
* bx.col+2 of row bx.row+1) that a press is on; carry if none
mu_ch               ldy       <base
                    lda       muev,y
                    cmpa      #MV.DOWN
                    bne       much_no
                    ldd       mux,y
                    suba      <bx.col
                    suba      #2
                    bcs       much_no
                    decb
                    cmpb      <bx.row
                    bne       much_no
much1               tst       ,x
                    beq       much_no
                    tsta
                    beq       much2
                    leax      1,x
                    deca
                    bra       much1
much2               lda       ,x
                    andcc     #^Carry
                    rts
much_no             orcc      #Carry
                    rts

********************************************************************
* The mouse in the main loop, the menus and the message window

* c_mouse: a mouse event in the main loop.  A press in the text moves
* the cursor there and a drag selects (past the top or bottom it
* scrolls); a right press extends the selection.  A press on the left
* border sets or clears a breakpoint, one on the right border is the
* scroll bar's (sbar.asm), one on a menu title opens the
* menu, and one on a message selects it in the message window.
c_mouse             ldx       <base
                    lda       muev,x
                    cmpa      #MV.DRAG
                    lbeq      cmu_drag
                    clr       murep,x
                    cmpa      #MV.UP
                    bne       cmu1
                    clr       mudrag,x
                    clr       musb,x
                    rts
cmu1                clr       mudrag,x            a press
                    clr       musb,x
                    ldd       mux,x
                    tstb
                    bne       cmu2
                    lda       muev,x              the menu bar
                    cmpa      #MV.DOWN
                    bne       cmu9
                    lda       mux,x
                    lbsr      mu_title
                    bcs       cmu9
                    tfr       b,a
                    lbra      m_open
cmu2                subb      <wtop
                    bcs       cmu9                the top border
                    cmpb      <wrows
                    bhs       cmu5                B = the row in the window
                    lda       <wleft
                    adda      <wcols
                    cmpa      mux,x
                    lbls      cmu_sb              the right border: the scroll bar
                    lda       mux,x
                    pshs      d
                    lda       muev,x
                    ldb       ,s
                    cmpb      <wleft
                    bhs       cmu3
                    cmpa      #MV.DOWN            the left border: a breakpoint
                    bne       cmu8
                    lbsr      sel_off
                    puls      d
                    lda       <wleft
                    bsr       mu_goto
                    lbra      c_bptog
cmu3                cmpa      #MV.RDOWN
                    bne       cmu4
                    lbsr      sel_on              right: extend the selection
                    puls      d
                    bra       mu_goto
cmu4                lbsr      sel_off
                    puls      d
                    bsr       mu_goto
                    ldx       <base
                    inc       mudrag,x            a drag selects
                    rts
cmu8                puls      d
cmu9                rts
cmu5                ldb       muy,x               the message window
                    lbsr      mu_msg
                    bcs       cmu9
                    lda       muev,x
                    cmpa      #MV.DOWN
                    bne       cmu9
                    stb       <msgsel
                    lbra      c_msgwin

* cmu_drag: the pointer moved with the button held after a press in the
* text: select to it.  Above or below the window, scroll a line at a
* time, and again while the button is held there.
cmu_drag            tst       musb,x
                    lbne      cmu_sbdrag
                    tst       mudrag,x
                    beq       cmu9
                    clr       murep,x
                    ldd       mux,x
                    subb      <wtop
                    bcc       cmud1
                    ldb       #$FF                above: the line before the window
                    inc       murep,x
                    bra       cmud2
cmud1               cmpb      <wrows
                    blo       cmud2
                    ldb       <wrows              below: the line after it
                    inc       murep,x
cmud2               pshs      d
                    lbsr      sel_on              (from the press)
                    puls      d

* mu_goto: the cursor to screen column A, window row B ($FF = the line
* above the window, wrows = the one below it)
mu_goto             pshs      a
                    clra
                    cmpb      #$FF
                    bne       mg0
                    ldd       <topline
                    beq       mg1
                    subd      #1
                    bra       mg1
mg0                 addd      <topline
mg1                 lbsr      goto_line
                    puls      b
                    subb      <wleft
                    bcc       mg2
                    ldd       <leftcol            left of the window: a column before
                    beq       mg3
                    subd      #1
                    bra       mg3
mg2                 cmpb      <wcols              the right border: the last column
                    blo       mg2a
                    ldb       <wcols
                    decb
mg2a                clra
                    addd      <leftcol
mg3                 ldu       <base
                    leau      cpos,u
                    lbra      p_tocol

* mo_mouse: a mouse event in an open menu.  Pressing or dragging over a
* title opens that menu (a press on its own title closes it), and over
* an item selects it; releasing on an item runs it.  A press anywhere
* else closes the menu.
mo_mouse            ldx       <base
                    lda       muev,x
                    cmpa      #MV.RDOWN
                    beq       mom_ign
                    ldd       mux,x
                    tstb
                    bne       mom2
                    lbsr      mu_title            the menu bar
                    bcs       mom_out
                    cmpb      <mcur
                    bne       mom1
                    lda       muev,x
                    cmpa      #MV.DOWN
                    lbeq      mo_close
                    bra       mom_ign
mom1                stb       <mcur
                    lbra      mo_new
mom2                lbsr      mu_item
                    bcs       mom3
                    ldx       <base
                    stb       <msel
                    lda       muev,x
                    cmpa      #MV.UP
                    lbeq      mo_run
                    bra       mom_ign
mom3                lbsr      mu_inbox            the frame or a separator
                    bcc       mom_ign
mom_out             ldx       <base
                    lda       muev,x
                    cmpa      #MV.DOWN
                    lbeq      mo_close
mom_ign             lbra      mo_draw

* cmw_mouse: a mouse event in the message window (it has the focus).  A
* press on a message selects it, a double click goes to its line.  A
* press anywhere else goes back to the text.
cmw_mouse           ldx       <base
                    lda       muev,x
                    cmpa      #MV.DOWN
                    lbne      cmw1
                    ldb       muy,x
                    lbsr      mu_msg
                    bcs       cwm2
                    tst       mudbl,x
                    lbeq      cmw_sel
                    lda       #C$CR               as Enter
                    lbra      cmw3
cwm2                lda       #EK.F1+5            as F6
                    lbra      cmw3
