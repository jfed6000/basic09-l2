********************************************************************
* msg - the message window
*
* Make and Run put their errors here.  Each message has the text line
* it points at, so Enter on it (or ^N) moves the cursor there.  While
* the window is shown it takes MH rows from the bottom of the text
* window, under the watch window (dbg.asm) if there are watches.

MAXMSG              equ       32
MSGW                equ       76                  text, with its 0
MH                  equ       7                   rows, with the frame
MS.LINE             equ       0                   line it points at ($FFFF = none)
MS.TEXT             equ       2
MS.SIZE             equ       MSGW+2

* ms_clear: no messages
ms_clear            clr       <nmsg
                    clr       <msgtop
                    clr       <msgsel
                    rts

* ms_at: X = message B
ms_at               pshs      d
                    lda       #MS.SIZE
                    mul
                    addd      #mtab
                    addd      <base
                    tfr       d,x
                    puls      d,pc

* ms_new: X = a new message (no line, empty text); carry if there is no
* room
ms_new              pshs      d
                    ldb       <nmsg
                    cmpb      #MAXMSG
                    bhs       mn_full
                    bsr       ms_at
                    inc       <nmsg
                    ldd       #$FFFF
                    std       MS.LINE,x
                    clr       MS.TEXT,x
                    andcc     #^Carry
                    puls      d,pc
mn_full             orcc      #Carry
                    puls      d,pc

* w_show: show the message window (if the screen has room for it)
w_show              tst       <msgon
                    bne       wsh9
                    ldb       <wwh
                    addb      #MH
                    bsr       w_fits
                    bcs       wsh9
                    inc       <msgon
                    bra       w_layout
wsh9                rts

* w_hide: give its rows back to the text window
w_hide              tst       <msgon
                    beq       whd9
                    clr       <msgon
                    clr       <msgfoc
                    bra       w_layout
whd9                rts

* w_fits: carry if the text window would have fewer than 3 rows with B
* more rows taken from it (and the message window's, if it is shown)
w_fits              pshs      b
                    lda       <scrh
                    suba      #4                  menu bar, borders, hint line
                    suba      ,s+
                    tst       <msgon
                    beq       wf1
                    suba      #MH
wf1                 cmpa      #3
                    blt       wf_no
                    andcc     #^Carry
                    rts
wf_no               orcc      #Carry
                    rts

* w_layout: the text window's rows, after the watch and message windows
w_layout            clr       <wwh
                    ldb       <nwatch
                    beq       wl1
                    addb      #2
                    stb       <wwh
wl1                 lda       <scrh
                    suba      #4
                    suba      <wwh
                    tst       <msgon
                    beq       wl2
                    suba      #MH
wl2                 sta       <wrows
                    lbra      rd_all

* w_draw: the watch window if there are watches, and the message window
* if it is shown.  The selected message is in reverse video; the frame
* is double while the window has the focus.
w_draw              tst       <nwatch
                    beq       wdr0
                    lbsr      ww_draw
wdr0                tst       <msgon
                    beq       wdr9
                    pshs      d,x,y
                    clr       <bx.col
                    lda       <wtop
                    adda      <wrows
                    adda      <wwh
                    inca
                    sta       <bx.row
                    lda       <scrw
                    sta       <bx.w
                    lda       #MH
                    sta       <bx.h
                    lda       #GL.TL1
                    tst       <msgfoc
                    beq       wdr1
                    lda       #GL.TL2
wdr1                sta       <bx.st
                    lbsr      bx_draw
                    leax      msgttl,pcr
                    lbsr      bx_title
                    clr       ,-s                 row in the window
wdr2                ldb       ,s
                    addb      <msgtop
                    cmpb      <nmsg
                    bhs       wdr8
                    pshs      b
                    lda       #2
                    ldb       <bx.row
                    addb      1,s
                    incb
                    lbsr      t_xy
                    ldb       ,s
                    cmpb      <msgsel
                    bne       wdr3
                    lbsr      t_rev
wdr3                puls      b
                    lbsr      ms_at
                    leax      MS.TEXT,x
                    ldb       <scrw               text and padding: scrw-4 columns
                    subb      #4
wdr4                lda       ,x
                    beq       wdr5
                    leax      1,x
                    bra       wdr6
wdr5                lda       #C$SPAC
wdr6                lbsr      t_ch
                    decb
                    bne       wdr4
                    lbsr      t_norm
                    inc       ,s
                    lda       ,s
                    cmpa      #MH-2
                    blo       wdr2
wdr8                leas      1,s
                    puls      d,x,y
wdr9                rts

msgttl              fcn       "Message"

* ms_jump: select message B, and move the cursor to its line
ms_jump             stb       <msgsel
                    cmpb      <msgtop             keep it in the window
                    bhs       mj1
                    stb       <msgtop
mj1                 subb      #MH-3
                    bls       mj2
                    cmpb      <msgtop
                    bls       mj2
                    stb       <msgtop
mj2                 ldb       <msgsel
                    lbsr      ms_at
                    ldd       MS.LINE,x
                    cmpd      #$FFFF
                    beq       mj9
                    pshs      d
                    lbsr      sel_off
                    puls      d
                    lbsr      goto_line
                    lbsr      v_center
mj9                 lbra      rd_all

* c_nexterr: the next message (^N)
c_nexterr           ldb       <nmsg
                    beq       cne_none
                    tst       <msgon              a hidden window starts again at the first
                    bne       cne1
                    lbsr      w_show
                    ldb       <msgsel
                    bra       ms_jump
cne1                ldb       <msgsel
                    incb
                    cmpb      <nmsg
                    bhs       cne_end
                    bra       ms_jump
cne_end             leax      nomore,pcr
                    stx       <msgp
                    rts
cne_none            leax      nomsgs,pcr
                    stx       <msgp
                    rts
nomore              fcn       "No more messages"
nomsgs              fcn       "No messages"

* c_msgwin: move into the message window (F6).  Up/Down choose a
* message, Enter goes to its line, Esc closes the window, F6 goes back.
c_msgwin            tst       <nmsg
                    beq       cne_none
                    lbsr      w_show
                    tst       <msgon
                    beq       cmw9                no room for it
                    inc       <msgfoc
                    leax      mwhint,pcr
                    stx       <msgp
                    lbsr      v_fix
                    lbsr      v_draw
cmw1                lbsr      w_draw
                    lbsr      t_curoff
                    lbsr      t_flush
                    lbsr      getkey
                    cmpa      #EK.UP
                    bne       cmw2
                    ldb       <msgsel
                    beq       cmw1
                    decb
                    bra       cmw_sel
cmw2                cmpa      #EK.DOWN
                    bne       cmw3
                    ldb       <msgsel
                    incb
                    cmpb      <nmsg
                    bhs       cmw1
cmw_sel             stb       <msgsel
                    cmpb      <msgtop
                    bhs       cmw2a
                    stb       <msgtop
cmw2a               subb      #MH-3
                    bls       cmw1
                    cmpb      <msgtop
                    bls       cmw1
                    stb       <msgtop
                    bra       cmw1
cmw3                ldx       #0                  leaving: the hint goes
                    stx       <msgp
                    cmpa      #C$CR
                    bne       cmw4
                    clr       <msgfoc
                    ldb       <msgsel
                    lbra      ms_jump
cmw4                cmpa      #EK.ESC
                    bne       cmw5
                    lbra      w_hide
cmw5                cmpa      #EK.F1+5            F6
                    beq       cmw8
                    cmpa      #EK.EOF
                    beq       cmw8
                    leax      mwhint,pcr          not a key here: stay
                    stx       <msgp
                    lbra      cmw1
cmw8                clr       <msgfoc
                    lbra      rd_all
cmw9                rts
mwhint              fcn       "Up/Down choose  Enter go to the line  F6 back  Esc close"
