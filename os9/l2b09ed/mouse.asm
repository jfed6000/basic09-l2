********************************************************************
* mouse - the mouse
*
* The Wildbits mouse driver moves the pointer in hardware, and grfdrv's
* SS.Mouse GetStat returns it: X 0-640 and Y 0-480 in pixels, and the
* buttons in A (1 left, 2 right, 4 middle).  There are no mouse events,
* so while it waits for a key the editor polls: SS.Ready on the key
* path, then SS.Mouse, then a tick's sleep.  A change of the buttons, or
* a move to another cell with the left button held, becomes the key
* EK.MOUSE, with the event in muev and its cell in mucol/murow.
*
* The driver keeps the buttons in the statics of the first terminal
* (/term), and SS.Mouse reads those of the terminal it is called on, so
* the editor reads the mouse through a path of its own to /term.  The
* pointer is global, so SS.WSig tells the editor when its terminal goes
* to the background and comes back, and clicks meant for another
* terminal are ignored.
*
* A key script (keys not from a terminal) sends the mouse as
* $FE <buttons> <column> <row>, in cells.

MV.DOWN             equ       1                   left button pressed
MV.DRAG             equ       2                   moved to another cell with it held (or a repeat)
MV.UP               equ       3                   left button released
MV.RDOWN            equ       4                   right button pressed
MB.LEFT             equ       $01                 SS.Mouse buttons
MB.RIGHT            equ       $02
DBLTK               equ       30                  ticks for a double click
REPTK               equ       4                   ticks between repeated drags (scrolling)
S$WinBg             equ       $81                 SS.WSig: our terminal went to the background
S$WinFg             equ       $82                 and came forward

* mu_init: the mouse state; find the mouse if the keys come from a
* terminal
mu_init             ldx       <base
                    clr       muon,x
                    clr       mubtn,x
                    clr       mudrag,x
                    clr       murep,x
                    clr       muagn,x
                    lda       #$FF
                    sta       mulc,x
                    ldd       #0
                    std       mutick,x
                    std       mux,x
                    lda       #1
                    sta       mulive,x
                    ifeq      coco3
                    tst       <kbterm
                    beq       mui9
                    leax      termnm,pcr
                    lda       #READ.
                    os9       I$Open
                    bcc       mui1
                    lda       <kbpath             no /term: our own terminal
mui1                ldx       <base
                    sta       mupath,x
                    ldb       #SS.Mouse
                    os9       I$GetStt
                    bcs       mui8                no mouse
                    ldx       <base
                    sta       mubtn,x             held now: not a press
                    ldx       #640                pixels per cell, as shifts
                    ldb       <scrw
                    bsr       mu_shift
                    ldx       <base
                    sta       musx,x
                    lda       <scpath
                    ldb       #SS.DScrn           the MCR: CLK_70 is 640x400
                    os9       I$GetStt
                    ldx       #480
                    bcs       mui2
                    tfr       y,d
                    bitb      #$01
                    beq       mui2
                    ldx       #400
mui2                ldb       <scrh
                    bsr       mu_shift
                    ldx       <base
                    sta       musy,x
                    lda       <kbpath             tell us when another terminal shows
                    ldb       #SS.WSig
                    ldx       #S$WinBg*256+S$WinFg
                    os9       I$SetStt
                    ldx       <base
                    inc       muon,x
                    rts
mui8                ldx       <base
                    lda       mupath,x
                    cmpa      <kbpath
                    beq       mui9
                    os9       I$Close
                    endc
mui9                rts

termnm              fcc       "/term"
                    fcb       C$CR

* mu_shift: A = log2(X pixels / B cells), rounded down
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

* mu_done: stop the visibility signals, close the mouse path
mu_done             ldx       <base
                    tst       muon,x
                    beq       mud9
                    clr       muon,x
                    lda       <kbpath
                    ldb       #SS.WSig
                    ldx       #0
                    os9       I$SetStt
                    ldx       <base
                    lda       mupath,x
                    cmpa      <kbpath
                    beq       mud9
                    os9       I$Close
mud9                rts

* mu_wait: wait for a key or a mouse event (when the mouse is polled);
* carry = a mouse event, no carry = a key to read
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
mu_poll             ldu       <base
                    tst       mulive,u
                    beq       mup8
                    lda       mupath,u
                    ldb       #SS.Mouse
                    os9       I$GetStt            X, Y = pixels, A = buttons
                    bcs       mup8
                    pshs      a,y                 ,s = buttons, 1,s = Y
                    tfr       x,d
                    ldu       <base
                    leau      musx,u
                    bsr       mu_cell
                    tsta
                    bne       mup1
                    cmpb      <scrw
                    blo       mup2
mup1                ldb       <scrw
                    decb
mup2                pshs      b                   ,s = column
                    ldd       2,s
                    leau      1,u                 musy
                    bsr       mu_cell
                    tsta
                    bne       mup3
                    cmpb      <scrh
                    blo       mup4
mup3                ldb       <scrh
                    decb
mup4                puls      a                   A = column, B = row
                    tfr       d,x
                    puls      a                   buttons
                    leas      2,s
                    bra       mu_new
mup8                ldu       <base               not on the screen: nothing held
                    ldx       mux,u
                    clra
                    bra       mu_new

* mu_cell: D = pixels D shifted right by the count at U
mu_cell             tst       ,u
                    beq       mce9
                    pshs      d
                    ldb       ,u
                    pshs      b
mce1                lsr       1,s
                    ror       2,s
                    dec       ,s
                    bne       mce1
                    leas      1,s
                    puls      d
mce9                rts

* mu_new: the mouse is now A = buttons, X = cell (column, row).  Carry if
* that is an event (muev, mucol, murow, mudbl).
mu_new              ldu       <base
                    pshs      a,x                 ,s = buttons, 1,s = cell
                    ldb       mubtn,u             B = the buttons before
                    sta       mubtn,u
                    ldx       mux,u               the cell before
                    pshs      x                   ,s = it, 2,s = buttons, 3,s = cell
                    ldx       3,s
                    stx       mux,u
                    stx       mucol,u
                    lda       2,s
                    bita      #MB.LEFT
                    beq       mun3
                    bitb      #MB.LEFT
                    beq       mun_down            pressed
                    ldx       ,s                  held: moved?
                    cmpx      3,s
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
                    ldx       mulc,u              the same cell as the last press,
                    cmpx      3,s                 soon enough?
                    bne       mund1
                    ldd       mutick,u
                    subd      mult,u
                    cmpd      #DBLTK
                    bhs       mund1
                    inc       mudbl,u
                    ldx       #$FFFF              a third press starts again
                    bra       mund2
mund1               ldx       3,s
mund2               stx       mulc,u
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
                    leas      5,s
                    orcc      #Carry
                    rts
mun_no              leas      5,s
                    andcc     #^Carry
                    rts

* getkd: getkey, but of the mouse only a press (a click dismisses)
getkd               pshs      b,x
gkd1                lbsr      getkey
                    cmpa      #EK.MOUSE
                    bne       gkd9
                    ldx       <base
                    ldb       muev,x
                    cmpb      #MV.DOWN
                    bne       gkd1
gkd9                puls      b,x,pc

********************************************************************
* Where a click lands

* mu_title: B = the menu whose title is at column A; carry if none
mu_title            pshs      a                   ,s = the column
                    leay      mtitle,pcr
                    lda       #1                  this title's first column
                    clrb                          its menu
mut1                tst       ,y
                    beq       mut_no
                    pshs      d                   ,s = first column, 1,s = menu
                    lbsr      strlen              B = its length
                    addb      #2
                    addb      ,s                  B = the next one's first column
                    lda       2,s
                    cmpa      ,s
                    blo       mut_no2
                    pshs      b
                    cmpa      ,s+
                    blo       mut_hit
                    tfr       b,a
                    ldb       1,s
                    incb
                    leas      2,s
                    bra       mut1
mut_hit             ldb       1,s
                    leas      3,s
                    andcc     #^Carry
                    rts
mut_no2             leas      2,s
mut_no              leas      1,s
                    orcc      #Carry
                    rts

* mu_inbox: carry unless column A, row B is in the open menu's box
mu_inbox            pshs      d
                    cmpb      #1
                    blo       mub_no
                    ldb       <mcnt
                    addb      #2
                    cmpb      1,s
                    blo       mub_no
                    cmpa      <mcol
                    blo       mub_no
                    lda       <mcol
                    adda      <mwid
                    cmpa      ,s
                    bls       mub_no
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
                    pshs      b
                    ldb       <wtop               the first message row
                    addb      <wrows
                    addb      <wwh
                    addb      #2
                    pshs      b
                    ldb       1,s
                    subb      ,s+
                    leas      1,s
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

* mu_seg: X = a string shown at column A of row B.  If the event is a
* press on it, A = the key of the part pressed, and no carry.  Parts are
* separated by two spaces, and a part's key is its first letter, or Esc
* for one starting with "Esc" (as in "Y = yes  N = no  Esc = stop").
mu_seg              pshs      d,x,y,u
                    ldu       <base
                    ldb       muev,u
                    cmpb      #MV.DOWN
                    bne       mus_no
                    ldb       murow,u
                    cmpb      1,s
                    bne       mus_no
                    ldb       mucol,u
                    subb      ,s                  B = the position in the string
                    bcs       mus_no
                    tfr       x,y                 Y = the part it is in
mus1                lda       ,x
                    beq       mus_no
                    cmpa      #C$SPAC
                    bne       mus3
                    lda       1,x
                    cmpa      #C$SPAC
                    bne       mus3
mus2                tstb                          between parts: none
                    beq       mus_no
                    leax      1,x
                    decb
                    lda       ,x
                    cmpa      #C$SPAC
                    beq       mus2
                    tfr       x,y                 the next part
                    bra       mus1
mus3                tstb
                    beq       mus_hit
                    leax      1,x
                    decb
                    bra       mus1
mus_hit             lda       ,y
                    cmpa      #'E
                    bne       mus4
                    ldd       1,y
                    cmpd      #$7363              "sc"
                    bne       mus3a
                    lda       #EK.ESC
                    bra       mus4
mus3a               lda       ,y
mus4                sta       ,s
                    puls      d,x,y,u
                    andcc     #^Carry
                    rts
mus_no              puls      d,x,y,u
                    orcc      #Carry
                    rts

* mu_out: A = EK.ESC and no carry if the event is a press outside the
* box at bx.col, bx.row (bx.w by bx.h); carry otherwise
mu_out              pshs      b,x
                    ldx       <base
                    lda       muev,x
                    cmpa      #MV.DOWN
                    bne       muo_no
                    ldd       mucol,x
                    cmpa      <bx.col
                    blo       muo_yes
                    suba      <bx.col
                    cmpa      <bx.w
                    bhs       muo_yes
                    cmpb      <bx.row
                    blo       muo_yes
                    subb      <bx.row
                    cmpb      <bx.h
                    bhs       muo_yes
muo_no              puls      b,x
                    orcc      #Carry
                    rts
muo_yes             lda       #EK.ESC
                    puls      b,x
                    andcc     #^Carry
                    rts

********************************************************************
* The mouse in the main loop, the menus and the message window

* c_mouse: a mouse event in the main loop.  A press in the text moves
* the cursor there and a drag selects (past the top or bottom it
* scrolls); a right press extends the selection.  A press on the left
* border sets or clears a breakpoint, one on a menu title opens the
* menu, and one on a message selects it (a double click goes to its
* line).
c_mouse             ldx       <base
                    lda       muev,x
                    cmpa      #MV.DRAG
                    lbeq      cm_drag
                    cmpa      #MV.UP
                    bne       cm1
                    clr       mudrag,x
                    clr       murep,x
                    rts
cm1                 clr       mudrag,x            a press
                    clr       murep,x
                    ldy       #0
                    sty       <msgp
                    clr       <msgerr
                    lda       #1
                    sta       <setwant
                    ldd       mucol,x
                    tstb
                    bne       cm2
                    ldb       muev,x              the menu bar
                    cmpb      #MV.DOWN
                    bne       cm9
                    bsr       mu_title
                    bcs       cm9
                    tfr       b,a
                    lbra      m_open
cm2                 cmpb      <wtop
                    blo       cm5
                    subb      <wtop
                    cmpb      <wrows
                    bhs       cm5                 B = the row in the window
                    pshs      d
                    lda       muev,x
                    tst       ,s
                    bne       cm3
                    cmpa      #MV.DOWN            the left border: a breakpoint
                    bne       cm8
                    lbsr      sel_off
                    puls      d
                    lda       <wleft
                    bsr       mu_goto
                    lbra      c_bptog
cm3                 cmpa      #MV.RDOWN
                    bne       cm4
                    lbsr      sel_on              right: extend the selection
                    puls      d
                    bra       mu_goto
cm4                 lbsr      sel_off
                    puls      d
                    bsr       mu_goto
                    ldx       <base
                    inc       mudrag,x            a drag selects
                    rts
cm8                 puls      d
cm9                 rts
cm5                 ldb       murow,x             the message window
                    bsr       mu_msg
                    bcs       cm9
                    lda       muev,x
                    cmpa      #MV.DOWN
                    bne       cm9
                    tst       mudbl,x
                    lbne      ms_jump
                    stb       <msgsel
                    lbra      c_msgwin

* cm_drag: the pointer moved with the button held after a press in the
* text: select to it.  Above or below the window, scroll a line at a
* time, and again while the button is held there.
cm_drag             tst       mudrag,x
                    beq       cm9
                    clr       murep,x
                    lda       #1
                    sta       <setwant
                    ldd       mucol,x
                    subb      <wtop
                    bcc       cmd1
                    ldb       #$FF                above: the line before the window
                    inc       murep,x
                    bra       cmd2
cmd1                cmpb      <wrows
                    blo       cmd2
                    ldb       <wrows              below: the line after it
                    inc       murep,x
cmd2                pshs      d
                    lbsr      sel_on              (from the press)
                    puls      d
                    ldx       <curline
                    pshs      x
                    bsr       mu_goto
                    puls      x
                    cmpx      <curline
                    lbeq      rd_line
                    lbra      rd_all

* mu_goto: the cursor to screen column A, window row B ($FF = the line
* above the window, wrows = the one below it)
mu_goto             pshs      a
                    sex                           D = topline + B
                    addd      <topline
                    cmpd      #$FFFF              above line 0
                    bne       mg1
                    ldd       #0
mg1                 lbsr      goto_line
                    puls      b
                    subb      <wleft
                    bcc       mg2
                    ldd       <leftcol            left of the window: a column before
                    beq       mg3
                    subd      #1
                    bra       mg3
mg2                 clra
                    addd      <leftcol
mg3                 ldu       <base
                    leau      cpos,u
                    lbra      p_tocol

* mo_mouse: a mouse event in an open menu.  Pressing or dragging over a
* title opens that menu, and over an item selects it; releasing on an
* item runs it.  A press anywhere else closes the menu.
mo_mouse            ldx       <base
                    lda       muev,x
                    cmpa      #MV.RDOWN
                    beq       mom_key
                    ldd       mucol,x
                    tstb
                    bne       mom2
                    lbsr      mu_title            the menu bar
                    bcs       mom_out
                    cmpb      <mcur
                    beq       mom_key
                    stb       <mcur
                    lbra      mo_new
mom2                lbsr      mu_item
                    bcs       mom3
                    ldx       <base
                    lda       muev,x
                    cmpa      #MV.UP
                    bne       mom2a
                    stb       <msel
                    lbra      mo_run
mom2a               cmpb      <msel
                    beq       mom_key
                    stb       <msel
                    lbra      mo_draw
mom3                lbsr      mu_inbox            the frame or a separator
                    bcc       mom_key
mom_out             ldx       <base
                    lda       muev,x
                    cmpa      #MV.DOWN
                    lbeq      mo_close
mom_key             lbra      mo_key

* cmw_mouse: a mouse event in the message window (it has the focus).  A
* press on a message selects it, a double click goes to its line.  A
* press anywhere else leaves the window, and the main loop gets it.
cmw_mouse           ldx       <base
                    lda       muev,x
                    cmpa      #MV.DOWN
                    lbne      cmw1
                    ldb       murow,x
                    lbsr      mu_msg
                    bcs       cwm2
                    tst       mudbl,x
                    lbeq      cmw_sel
                    lda       #C$CR               as Enter
                    lbra      cmw3
cwm2                inc       muagn,x             again, for the main loop
                    lda       #EK.F1+5            as F6
                    lbra      cmw3
