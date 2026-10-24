********************************************************************
* l2b09help - the help browser for basic09-l2
*
* Shows the pages of the help file (docs/HELP.md, built by
* tools/mkhelp.py): a page fills the screen in a frame, its links can
* be followed and gone back from, F2 shows the index, and typing a
* name searches for it.  The editor runs it on F1 with the word at the
* cursor; it also runs on its own.  The mouse wheel scrolls.
*
* usage: l2b09help [-e] [-n] [-h] [-f=<file>] [<topic>]
*
*   -e          run from the editor: leave the palette and the screen
*               type as they are on exit
*   -n          no colours (the editor's colours are off)
*   -h          at the end of the key input, sleep instead of quitting
*               (tests use it to take a screen snapshot)
*   -f=<file>   the help file (default /dd/SYS/basic09-l2.hlp)
*   <topic>     the page to open: a name (any case); if there is no
*               such page, the names that start with it
*
* The screen and the keys are the editor's own code (term.asm,
* keys.asm), so it reads both keyboards and draws the same frames.

                    nam       l2b09help
                    ttl       l2basic09 help browser

                    ifp1
                    use       defsfile
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       1

                    mod       eom,name,tylg,atrv,start,size

OUTSZ               equ       256                 screen output buffer
STKSZ               equ       512
HPMAX               equ       12*1024             the largest page
NTMAX               equ       6*1024              the name table
LMAX                equ       700                 lines in a page
KMAX                equ       600                 links in a page
HMAX                equ       16                  pages Back remembers
HE.SIZE             equ       9                   history entry: offset (3), length,
*                                                 top line, selected link
SMAX                equ       24                  search text
SS.FntChar          equ       $C2                 (term.asm) Wildbits: font characters
SS.MsWheel          equ       $E8                 Wildbits: wheel steps since the last call
GLYPH0              equ       $ED
NGL1                equ       15
NGLYPH              equ       19
GL.TL2              equ       0
GL.TR2              equ       1
GL.BL2              equ       2
GL.BR2              equ       3
GL.H2               equ       4
GL.V2               equ       5
LK.BEG              equ       $01                 a link: $01, offset (3), length (2),
LK.END              equ       $02                 the text, $02

* Colours (as the editor's, hl.asm)
CL.BG               equ       6
CL.NORM             equ       7
CL.FRAME            equ       1
CL.LINK             equ       3
CL.SELFG            equ       0
CL.SELBG            equ       3
CL.MBFG             equ       0
CL.MBBG             equ       15

* Data area: the direct page first
                    org       0
base                rmb       2                   data area address
kbpath              rmb       1                   key input path (term.asm, keys.asm)
scpath              rmb       1                   screen path
kbterm              rmb       1                   key input is a terminal
scrw                rmb       1                   screen columns
scrh                rmb       1                   screen rows
wtop                rmb       1                   text: first row
wrows               rmb       1                   rows
wleft               rmb       1                   first column
wcols               rmb       1                   columns
outp                rmb       2                   output buffer: next byte
outb                rmb       2                   start
oute                rmb       2                   end
key                 rmb       1                   key code (keys.asm)
kraw                rmb       1
ksns                rmb       1
hold                rmb       1                   -h
glyphs              rmb       NGL1                frame characters (term.asm)
glyok               rmb       1
dblsp               rmb       1                   -d: double spacing, as the editor's (term.asm)
nocolr              rmb       1                   -n
hlout               rmb       1                   the colour in force
edmode              rmb       1                   -e
argp                rmb       2                   the parameters
hfpath              rmb       1                   the help file
nnames              rmb       2                   names in the table
pend                rmb       2                   end of the page in pbuf
nlines              rmb       2                   body lines of the page
nlinks              rmb       2                   links in it
top                 rmb       2                   first line shown
sel                 rmb       2                   the selected link ($FFFF = none)
poff                rmb       3                   the page: offset in the file
plen                rmb       2                   and length
toff                rmb       3                   a page to go to
tlen                rmb       2
hcnt                rmb       1                   pages in the history
srch                rmb       1                   searching
slen                rmb       1                   search text length
tmp                 rmb       2
cnt                 rmb       2
nmatch              rmb       1                   names the search found
muwh                rmb       1                   SS.MsWheel answers
muwst               rmb       2                   EK.WHEEL: its steps (keys.asm)
dpend               equ       .

                    org       256
optsav              rmb       32                  terminal options on entry (term.asm)
optraw              rmb       32
rline               rmb       258                 scratch (term.asm: SS.Opt, SS.ScSiz)
fntsav              rmb       NGLYPH*8            font characters under the glyphs
hlnorm              rmb       1                   the normal text colour
hlok                rmb       1                   the terminal's colours are known
hlsfg               rmb       1                   and they are
hlsbg               rmb       1
phrows              rmb       1                   (term.asm)
otype               rmb       1                   screen type at start (term.asm)
stype               rmb       1
fname               rmb       64                  the help file
topic               rmb       32                  the topic asked for
sstr                rmb       SMAX+1              the search text
outbuf              rmb       OUTSZ
hist                rmb       HMAX*HE.SIZE
ntab                rmb       NTMAX               the name table
ltab                rmb       LMAX*2              where each body line starts
ktab                rmb       KMAX*4              each link: where ($01), its line
pbuf                rmb       HPMAX+1             the page
                    rmb       STKSZ
stktop              equ       .
size                equ       .

name                fcs       /l2b09help/
                    fcb       edition

defhf               fcn       "/dd/SYS/basic09-l2.hlp"
helptp              fcn       "HELP"
indxtp              fcn       "INDEX"

start               tfr       u,d
                    tfr       a,dp
                    leay      ,u                  clear the direct page
                    clrb
st1                 clr       ,y+
                    decb
                    bne       st1
                    stx       <argp
                    stu       <base
                    leax      outbuf,u
                    stx       <outb
                    stx       <outp
                    leax      OUTSZ,x
                    stx       <oute
                    lbsr      getargs
                    lbsr      hf_open             the help file first: no screen
                    bcs       st9                 if it is not there
                    lbsr      t_init              raw keys, screen size, glyphs
                    tst       <dblsp              double spacing: half the rows, and
                    beq       st1d                the gap rows cleared (v_gap draws
                    lsr       <scrh               the frame's sides on them)
                    lbsr      t_cls
st1d                lda       #1                  the text window: no menu bar
                    sta       <wtop
                    ldb       <scrh
                    subb      #3
                    stb       <wrows
                    ifeq      coco3
                    tst       <kbterm             a wheel?
                    beq       st4
                    lda       <kbpath
                    ldb       #SS.MsWheel
                    os9       I$GetStt
                    bcs       st4
                    inc       <muwh
st4                 equ       *
                    endc
                    lbsr      go_topic
ml1                 lbsr      v_draw
                    lbsr      getkey
                    lbsr      k_do
                    bcc       ml1
                    lbsr      t_done
                    clrb
st9                 os9       F$Exit

* getargs: [-e] [-n] [-h] [-f=<file>] [<topic>] -> edmode, nocolr,
* hold, fname, topic
getargs             ldx       <base
                    leay      fname,x
                    clr       topic,x
                    leax      defhf,pcr
ga0                 lda       ,x+
                    sta       ,y+
                    bne       ga0
                    ldx       <argp
ga1                 lda       ,x+
                    cmpa      #C$SPAC
                    beq       ga1
                    cmpa      #C$CR
                    beq       ga9
                    cmpa      #'-
                    bne       ga5
                    lda       ,x+
                    anda      #$DF
                    cmpa      #'E
                    bne       ga2
                    inc       <edmode
                    bra       ga1
ga2                 cmpa      #'N
                    bne       ga3
                    inc       <nocolr
                    bra       ga1
ga3                 cmpa      #'H
                    bne       ga3a
                    inc       <hold
                    bra       ga1
ga3a                cmpa      #'D
                    bne       ga4
                    inc       <dblsp
                    bra       ga1
ga4                 cmpa      #'F
                    bne       ga7
                    lda       ,x+
                    cmpa      #'=
                    bne       ga7
                    ldy       <base
                    leay      fname,y
                    ldb       #63
ga4a                lda       ,x+
                    cmpa      #C$SPAC
                    beq       ga4b
                    cmpa      #C$CR
                    beq       ga4b
                    sta       ,y+
                    decb
                    bne       ga4a
ga4b                clr       ,y
                    leax      -1,x
                    bra       ga1
ga7                 lda       ,x+                 skip an unknown option
                    cmpa      #C$SPAC
                    beq       ga1
                    cmpa      #C$CR
                    bne       ga7
                    bra       ga9
ga5                 leax      -1,x                the topic: the rest of the line
                    ldy       <base
                    leay      topic,y
                    ldb       #31
ga6                 lda       ,x+
                    cmpa      #C$CR
                    beq       ga8
                    sta       ,y+
                    decb
                    bne       ga6
ga8                 clr       ,y
                    ldx       <base               without trailing spaces
                    leax      topic,x
ga8a                pshs      x
                    cmpy      ,s++
                    bls       ga9
                    lda       ,-y
                    cmpa      #C$SPAC
                    bne       ga9
                    clr       ,y
                    bra       ga8a
ga9                 rts

* hf_open: open the help file and read its name table; carry (B =
* error) if that fails
hf_open             ldx       <base
                    leax      fname,x
                    lda       #READ.
                    os9       I$Open
                    bcs       hfo9
                    sta       <hfpath
                    lbsr      a_rline             the header
                    ldy       #9
                    os9       I$Read
                    bcs       hfo9
                    ldd       ,x
                    cmpd      #'B*256+'9
                    bne       hfo_bad
                    ldd       2,x
                    cmpd      #'H*256+'L
                    bne       hfo_bad
                    ldd       5,x
                    std       <nnames
                    ldy       7,x                 the table's size
                    cmpy      #NTMAX
                    bhi       hfo_bad
                    ldx       <base
                    leax      ntab,x
                    lda       <hfpath
                    os9       I$Read
hfo9                rts
hfo_bad             ldb       #E$BMID
                    orcc      #Carry
                    rts

* a_rline: X = rline (term.asm uses it)
a_rline             ldx       <base
                    leax      rline,x
                    rts

* go_topic: open the page asked for: Help with no topic, the page of
* that name, or else the names that start with it
go_topic            ldx       <base
                    leax      topic,x
                    tst       ,x
                    bne       gt1
                    leax      helptp,pcr
gt1                 lbsr      nt_find
                    bcs       gt2
                    lbra      pg_load
gt2                 ldx       <base               a search for it
                    leax      topic,x
                    ldy       <base
                    leay      sstr,y
                    clrb
gt3                 lda       ,x+
                    beq       gt4
                    lbsr      up_a
                    sta       ,y+
                    incb
                    cmpb      #SMAX
                    blo       gt3
gt4                 stb       <slen
                    inc       <srch
                    lbsr      sr_gen
                    tst       <nmatch             nothing starts with it either:
                    bne       gt9                 the contents
                    leax      helptp,pcr
                    lbsr      nt_find
                    bcs       gt9
                    lbra      pg_load
gt9                 rts

* up_a: A in capitals
up_a                cmpa      #'a
                    blo       upa9
                    cmpa      #'z
                    bhi       upa9
                    suba      #$20
upa9                rts

* nt_find: the page named by the string at X (ending in 0, any case)
* -> toff, tlen; carry if there is none
nt_find             ldy       <base
                    leay      ntab,y
                    ldd       <nnames
                    std       <cnt
nf1                 ldd       <cnt
                    beq       nf_no
                    pshs      x
nf2                 lda       ,x+                 the name asked for
                    bsr       up_a
                    ldb       ,y+                 the table's
                    pshs      b
                    andb      #$7F
                    pshs      b
                    cmpa      ,s+
                    puls      b                   (keeps the flags)
                    bne       nf_mis
                    tstb
                    bpl       nf2                 not its last character
                    tst       ,x
                    bne       nf_skip             the one asked for goes on
                    puls      x
                    lda       ,y
                    sta       <toff
                    ldd       1,y
                    std       <toff+1
                    ldd       3,y
                    std       <tlen
                    andcc     #^Carry
                    rts
nf_mis              tstb
                    bmi       nf_skip
nf_m1               ldb       ,y+
                    bpl       nf_m1
nf_skip             leay      5,y
                    puls      x
                    ldd       <cnt
                    subd      #1
                    std       <cnt
                    bra       nf1
nf_no               orcc      #Carry
                    rts

********************************************************************
* Pages

* pg_load: read the page at toff (tlen bytes) into pbuf; the top of it
* is shown, and the first link selected
pg_load             lda       <toff
                    sta       <poff
                    ldd       <toff+1
                    std       <poff+1
                    ldd       <tlen
                    cmpd      #HPMAX
                    bls       pgl1
                    ldd       #HPMAX
pgl1                std       <plen
                    clr       <srch
                    ldx       #0
                    ldb       <poff
                    abx
                    ldu       <poff+1
                    lda       <hfpath
                    os9       I$Seek
                    ldx       <base
                    leax      pbuf,x
                    ldy       <plen
                    lda       <hfpath
                    os9       I$Read
                    bcc       pgl2
                    ldy       #0
pgl2                tfr       y,d
                    leax      d,x
                    stx       <pend
* pg_scan: the line and link tables of the page in pbuf; the top shown
pg_scan             clra
                    clrb
                    std       <nlines
                    std       <nlinks
                    std       <top
                    ldx       <base
                    leax      pbuf,x
ps1                 cmpx      <pend               past the title
                    bhs       ps9
                    lda       ,x+
                    cmpa      #C$CR
                    bne       ps1
ps2                 cmpx      <pend               a line starts
                    bhs       ps9
                    ldd       <nlines
                    cmpd      #LMAX
                    bhs       ps9
                    ldu       <base
                    leau      ltab,u
                    lslb
                    rola
                    stx       d,u
                    ldd       <nlines
                    addd      #1
                    std       <nlines
ps3                 cmpx      <pend
                    bhs       ps9
                    lda       ,x+
                    cmpa      #C$CR
                    beq       ps2
                    cmpa      #LK.BEG
                    bne       ps3
                    ldd       <nlinks             a link: where, and its line
                    cmpd      #KMAX
                    bhs       ps4
                    ldu       <base
                    leau      ktab,u
                    lslb
                    rola
                    lslb
                    rola
                    leau      d,u
                    leay      -1,x
                    sty       ,u
                    ldd       <nlines
                    subd      #1
                    std       2,u
                    ldd       <nlinks
                    addd      #1
                    std       <nlinks
ps4                 leax      5,x
                    bra       ps3
ps9                 ldd       #$FFFF
                    std       <sel
                    ldd       <nlinks
                    beq       ps9a
                    ldd       #0
                    std       <sel
                    bsr       sel_vis
ps9a                rts

* lk_at: X = the entry of link D in ktab
lk_at               ldx       <base
                    leax      ktab,x
                    lslb
                    rola
                    lslb
                    rola
                    leax      d,x
                    rts

* sel_vis: if the selected link is not on the screen, the first link
* that is, or none
sel_vis             ldd       <sel
                    cmpd      #$FFFF
                    beq       sv1
                    bsr       lk_at
                    bsr       sv_in
                    bcc       sv9
sv1                 ldd       #0
                    std       <tmp
sv2                 ldd       <tmp
                    cmpd      <nlinks
                    bhs       sv_none
                    bsr       lk_at
                    bsr       sv_in
                    bcc       sv3
                    ldd       <tmp
                    addd      #1
                    std       <tmp
                    bra       sv2
sv3                 ldd       <tmp
                    std       <sel
sv9                 rts
sv_none             ldd       #$FFFF
                    std       <sel
                    rts
* sv_in: carry clear if the link at X is on the screen
sv_in               ldd       2,x
                    subd      <top
                    bcs       svi_no
                    pshs      b
                    tsta
                    puls      b
                    bne       svi_no
                    cmpb      <wrows
                    bhs       svi_no
                    andcc     #^Carry
                    rts
svi_no              orcc      #Carry
                    rts

* sel_show: scroll so that the selected link is on the screen
sel_show            ldd       <sel
                    cmpd      #$FFFF
                    beq       ssh9
                    bsr       lk_at
                    ldd       2,x                 its line
                    cmpd      <top
                    bhs       ssh1
                    std       <top                above: it goes at the top
                    rts
ssh1                subd      <top
                    tsta
                    bne       ssh2
                    cmpb      <wrows
                    blo       ssh9
ssh2                ldd       2,x                 below: it goes at the bottom
                    subb      <wrows
                    sbca      #0
                    addd      #1
                    std       <top
ssh9                rts

* maxtop: D = the last top line that still fills the window
maxtop              ldd       <nlines
                    subb      <wrows
                    sbca      #0
                    bpl       mt9
                    clra
                    clrb
mt9                 rts

********************************************************************
* Keys

* k_do: act on key A; carry to leave
k_do                tst       <srch
                    beq       kd1
                    lbsr      sr_key              searching: text keys first
                    bcc       kd_ok
                    lda       <key
kd1                 cmpa      #EK.WHEEL           the wheel: 3 lines a step
                    bne       kd1a
                    ldd       <muwst
                    pshs      d
                    lslb
                    rola
                    addd      ,s++
                    addd      <top
                    lbpl      kd_lim
                    clra
                    clrb
                    lbra      kd_top
kd1a                cmpa      #EK.ESC
                    beq       kd_quit
                    cmpa      #EK.EOF
                    beq       kd_quit
                    cmpa      #$11                Ctrl+Q
                    beq       kd_quit
                    cmpa      #EK.UP
                    bne       kd2
                    ldd       <top
                    beq       kd_ok
                    subd      #1
                    bra       kd_top
kd2                 cmpa      #EK.DOWN
                    bne       kd3
                    ldd       <top
                    addd      #1
                    bra       kd_lim
kd3                 cmpa      #EK.PGUP
                    bne       kd4
                    ldd       <top
                    subb      <wrows
                    sbca      #0
                    bpl       kd_top
                    clra
                    clrb
                    bra       kd_top
kd4                 cmpa      #EK.PGDN
                    bne       kd5
                    ldd       <top
                    addb      <wrows
                    adca      #0
                    bra       kd_lim
kd5                 cmpa      #EK.TOP
                    bne       kd6
                    clra
                    clrb
                    bra       kd_top
kd6                 cmpa      #EK.BOTTOM
                    bne       kd7
                    bsr       maxtop
                    bra       kd_top
kd7                 cmpa      #EK.LEFT
                    bne       kd8
                    ldd       <sel
                    cmpd      #$FFFF
                    beq       kd_ok
                    subd      #1
                    bcs       kd_ok
                    bra       kd_sel
kd8                 cmpa      #EK.RIGHT
                    bne       kd9
                    ldd       <sel
                    addd      #1
                    cmpd      <nlinks
                    bhs       kd_ok
kd_sel              std       <sel
                    bsr       sel_show
                    bra       kd_ok
kd9                 cmpa      #C$CR
                    bne       kd10
                    lbsr      lk_follow
                    bra       kd_ok
kd10                cmpa      #EK.BS
                    bne       kd11
                    lbsr      h_pop
                    bra       kd_ok
kd11                cmpa      #EK.F1
                    bne       kd12
                    leax      helptp,pcr
                    bra       kd_go
kd12                cmpa      #EK.F2
                    bne       kd13
                    leax      indxtp,pcr
kd_go               lbsr      nt_find
                    bcs       kd_ok
                    lbsr      h_push
                    lbsr      pg_load
                    bra       kd_ok
kd13                cmpa      #C$SPAC             a name: a search starts
                    blo       kd_ok
                    cmpa      #$7E
                    bhi       kd_ok
                    lbsr      h_push
                    clr       <slen
                    inc       <srch
                    lda       <key
                    lbsr      sr_key
                    bra       kd_ok
kd_lim              pshs      d                   at most maxtop
                    bsr       maxtop
                    cmpd      ,s
                    bhs       kd_lim1
                    std       ,s
kd_lim1             puls      d
kd_top              std       <top
                    lbsr      sel_vis
kd_ok               andcc     #^Carry
                    rts
kd_quit             orcc      #Carry
                    rts

* lk_follow: go to the selected link's page
lk_follow           ldd       <sel
                    cmpd      #$FFFF
                    beq       lkf9
                    bsr       lk_at
                    ldx       ,x                  the $01
                    lda       1,x
                    sta       <toff
                    ldd       2,x
                    std       <toff+1
                    ldd       4,x
                    std       <tlen
                    tst       <srch               (a search page is not remembered)
                    bne       lkf1
                    bsr       h_push
lkf1                lbra      pg_load
lkf9                rts

* h_push: remember the page shown (Back goes to it)
h_push              lda       <hcnt
                    cmpa      #HMAX
                    blo       hp1
                    ldx       <base               full: the oldest goes
                    leax      hist,x
                    ldb       #(HMAX-1)*HE.SIZE
hp0                 lda       HE.SIZE,x
                    sta       ,x+
                    decb
                    bne       hp0
                    dec       <hcnt
hp1                 ldb       <hcnt
                    lda       #HE.SIZE
                    mul
                    ldx       <base
                    leax      hist,x
                    leax      d,x
                    lda       <poff
                    sta       ,x
                    ldd       <poff+1
                    std       1,x
                    ldd       <plen
                    std       3,x
                    ldd       <top
                    std       5,x
                    ldd       <sel
                    std       7,x
                    inc       <hcnt
                    rts

* h_pop: back to the page remembered last; carry if there is none
h_pop               ldb       <hcnt
                    beq       hpo_no
                    decb
                    stb       <hcnt
                    lda       #HE.SIZE
                    mul
                    ldx       <base
                    leax      hist,x
                    leax      d,x
                    pshs      x
                    lda       ,x
                    sta       <toff
                    ldd       1,x
                    std       <toff+1
                    ldd       3,x
                    std       <tlen
                    lbsr      pg_load
                    puls      x
                    ldd       5,x
                    std       <top
                    ldd       7,x
                    std       <sel
                    andcc     #^Carry
                    rts
hpo_no              orcc      #Carry
                    rts

********************************************************************
* Search: the names that start with what was typed, as a page of links

* sr_key: a key while searching (A); carry if it is not one of the
* search's (the page keys still work)
sr_key              cmpa      #EK.ESC             Esc: back to where it started
                    beq       srk_out
                    cmpa      #EK.BS
                    bne       srk1
                    ldb       <slen
                    beq       srk_out
                    decb
                    stb       <slen
                    bne       sr_gen
srk_out             clr       <srch
                    lbsr      h_pop
                    bcc       srk_ok
                    lda       #EK.ESC             (nothing to go back to: leave)
                    sta       <key
                    orcc      #Carry
                    rts
srk1                cmpa      #C$CR
                    beq       srk_no              (Enter follows the selected name)
                    cmpa      #C$SPAC
                    blo       srk_no
                    cmpa      #$7E
                    bhi       srk_no
                    ldb       <slen
                    cmpb      #SMAX
                    bhs       srk_ok
                    lbsr      up_a
                    ldx       <base
                    leax      sstr,x
                    sta       b,x
                    inc       <slen
                    bra       sr_gen
srk_ok              andcc     #^Carry
                    rts
srk_no              orcc      #Carry
                    rts

* sr_gen: make the search page in pbuf
sr_gen              ldy       <base
                    leay      pbuf,y
                    leax      srtl,pcr            its title
                    bsr       sr_str
                    ldx       <base
                    leax      sstr,x
                    ldb       <slen
                    beq       sg1
sg0                 lda       ,x+
                    sta       ,y+
                    decb
                    bne       sg0
sg1                 lda       #C$CR
                    sta       ,y+
                    ldx       <base
                    leax      ntab,x
                    ldd       <nnames
                    std       <cnt
                    clr       <nmatch
sg2                 ldd       <cnt
                    beq       sg8
                    subd      #1
                    std       <cnt
                    pshs      x                   does it start with sstr?
                    ldu       <base
                    leau      sstr,u
                    ldb       <slen
                    beq       sg4
sg3                 lda       ,x+
                    pshs      a
                    anda      #$7F
                    cmpa      ,u+
                    puls      a
                    bne       sg_skip
                    tsta
                    bmi       sg3a
                    decb
                    bne       sg3
                    bra       sg4
sg3a                decb                          the name ended: a match only if
                    bne       sg_skip             the search did too
sg4                 puls      x                   a match: a link to it
                    leau      ,x
sg4a                lda       ,u+                 (U = after the name)
                    bpl       sg4a
                    lda       #LK.BEG
                    sta       ,y+
                    lda       ,u
                    sta       ,y+
                    ldd       1,u
                    std       ,y++
                    ldd       3,u
                    std       ,y++
sg5                 lda       ,x+
                    pshs      a
                    anda      #$7F
                    sta       ,y+
                    puls      a
                    tsta
                    bpl       sg5
                    lda       #LK.END
                    sta       ,y+
                    lda       #C$CR
                    sta       ,y+
                    leax      5,x
                    inc       <nmatch
                    pshs      y
                    ldd       ,s++
                    subd      <base
                    cmpd      #pbuf+HPMAX-64
                    bhs       sg8
                    bra       sg2
sg_skip             puls      x                   to the next name
sg6                 lda       ,x+
                    bpl       sg6
                    leax      5,x
                    bra       sg2
sg8                 tst       <nmatch
                    bne       sg9
                    leax      srnone,pcr
                    bsr       sr_str
                    lda       #C$CR
                    sta       ,y+
sg9                 sty       <pend
                    lbra      pg_scan
* sr_str: the string at X (ending in 0) to Y
sr_str              lda       ,x+
                    beq       sst9
                    sta       ,y+
                    bra       sr_str
sst9                rts
srtl                fcn       "Search: "
srnone              fcn       "  No name starts with that."

********************************************************************
* Drawing

* v_draw: the frame with the title, the page, the hint line
v_draw              lbsr      t_curoff
                    lbsr      c_norm
                    clra                          the top border and the title
                    clrb
                    lbsr      t_xy
                    ldb       #CL.FRAME
                    lbsr      c_fg
                    ldx       <base
                    lda       glyphs+GL.TL2,x
                    lbsr      t_ch
                    ldx       <base               the title's length (at most
                    leax      pbuf,x              the width less 6)
                    clrb
vd1                 cmpx      <pend
                    bhs       vd2
                    lda       ,x+
                    cmpa      #C$CR
                    beq       vd2
                    incb
                    bra       vd1
vd2                 lda       <scrw
                    suba      #6
                    pshs      a
                    cmpb      ,s+
                    bls       vd3
                    ldb       <scrw
                    subb      #6
vd3                 stb       <tmp                its length
                    lda       <scrw               H2 before it: (width-4-len)/2
                    suba      #4
                    suba      <tmp
                    lsra
                    sta       <tmp+1
                    tfr       a,b
                    ldx       <base
                    lda       glyphs+GL.H2,x
                    lbsr      t_rep
                    lda       #C$SPAC
                    lbsr      t_ch
                    ldx       <base
                    leax      pbuf,x
                    ldb       <tmp
                    beq       vd4a
vd4                 lda       ,x+
                    lbsr      t_ch
                    decb
                    bne       vd4
vd4a                lda       #C$SPAC
                    lbsr      t_ch
                    ldb       <scrw               H2 after it
                    subb      #4
                    subb      <tmp
                    subb      <tmp+1
                    ldx       <base
                    lda       glyphs+GL.H2,x
                    lbsr      t_rep
                    lda       glyphs+GL.TR2,x
                    lbsr      t_ch
                    clr       <tmp                the rows
                    clrb
                    lbsr      v_gap
vd5                 ldb       <tmp
                    cmpb      <wrows
                    bhs       vd6
                    lbsr      v_row
                    inc       <tmp
                    ldb       <tmp
                    lbsr      v_gap
                    bra       vd5
vd6                 clra                          the bottom border
                    ldb       <scrh
                    subb      #2
                    lbsr      t_xy
                    ldb       #CL.FRAME
                    lbsr      c_fg
                    ldx       <base
                    lda       glyphs+GL.BL2,x
                    lbsr      t_ch
                    ldb       <scrw
                    subb      #2
                    lda       glyphs+GL.H2,x
                    lbsr      t_rep
                    lda       glyphs+GL.BR2,x
                    lbsr      t_ch
                    clra                          the hint line
                    ldb       <scrh
                    decb
                    lbsr      t_xy
                    lbsr      c_bar
                    leax      hintms,pcr
                    tst       <srch
                    beq       vd7
                    leax      srchms,pcr
vd7                 lbsr      t_str
                    lbsr      strlen
                    tst       <srch
                    beq       vd8
                    pshs      b                   the search text and a cursor
                    ldx       <base
                    leax      sstr,x
                    ldb       <slen
                    beq       vd7b
vd7a                lda       ,x+
                    lbsr      t_ch
                    decb
                    bne       vd7a
vd7b                lda       #'_
                    lbsr      t_ch
                    puls      b
                    addb      <slen
                    incb
vd8                 negb                          pad to the width less 1 (the
                    addb      <scrw               last cell would scroll)
                    decb
                    bmi       vd9
                    lda       #C$SPAC
                    lbsr      t_rep
vd9                 lbsr      c_norm
                    lbra      t_flush
hintms              fcn       " Enter follow  Bksp back  F1 help  F2 index  type to search  Esc close"
srchms              fcn       " Esc cancel  Enter open  Search: "

* strlen: B = the length of the string at X
strlen              clrb
sl1                 tst       b,x
                    beq       sl9
                    incb
                    bra       sl1
sl9                 rts

* v_gap: with double spacing, the frame's sides on the gap row under
* screen row B
v_gap               tst       <dblsp
                    beq       vg9
                    pshs      b
                    clra
                    lbsr      t_xyg
                    ldb       #CL.FRAME
                    lbsr      c_fg
                    ldx       <base
                    lda       glyphs+GL.V2,x
                    lbsr      t_ch
                    lda       <scrw
                    deca
                    ldb       ,s
                    lbsr      t_xyg
                    ldx       <base
                    lda       glyphs+GL.V2,x
                    lbsr      t_ch
                    lbsr      c_norm
                    puls      b
vg9                 rts

* v_row: text row B (0 = the first) of the window
v_row               lda       #0
                    addb      <wtop
                    lbsr      t_xy
                    ldb       #CL.FRAME
                    lbsr      c_fg
                    ldx       <base
                    lda       glyphs+GL.V2,x
                    lbsr      t_ch
                    lbsr      c_norm
                    lda       <wcols
                    sta       <tmp+1              columns left
                    clra
                    ldb       <tmp
                    addd      <top
                    cmpd      <nlines
                    bhs       vr8                 past the end: blank
                    ldx       <base
                    leax      ltab,x
                    lslb
                    rola
                    ldx       d,x                 the line
                    ldy       #$FFFF              the selected link's $01
                    ldd       <sel
                    cmpd      #$FFFF
                    beq       vr1
                    pshs      x
                    lbsr      lk_at
                    ldy       ,x
                    puls      x
vr1                 cmpx      <pend
                    bhs       vr8
                    lda       ,x+
                    cmpa      #C$CR
                    beq       vr8
                    cmpa      #LK.BEG
                    bne       vr3
                    leau      -1,x                a link
                    leax      5,x
                    pshs      u
                    cmpy      ,s++
                    bne       vr2
                    lbsr      c_sel
                    bra       vr1
vr2                 lbsr      c_link
                    bra       vr1
vr3                 cmpa      #LK.END
                    bne       vr4
                    lbsr      c_norm
                    bra       vr1
vr4                 tst       <tmp+1
                    beq       vr1
                    lbsr      t_ch
                    dec       <tmp+1
                    bra       vr1
vr8                 lbsr      c_norm
                    ldb       <tmp+1
                    lda       #C$SPAC
                    lbsr      t_rep
                    ldb       #CL.FRAME
                    lbsr      c_fg
                    ldx       <base
                    lda       glyphs+GL.V2,x
                    lbsr      t_ch
                    rts

********************************************************************
* Colours: as the editor's (hl.asm), but run from the editor (-e) the
* palette is left as it is

* hl_init (from t_init): note the terminal's colours, set ours
hl_init             ldx       <base
                    clr       hlok,x
                    tst       <edmode
                    bne       hli8
                    leax      rline,x
                    lda       <scpath
                    clrb                          SS.Opt
                    os9       I$GetStt
                    bcs       hli8
                    lda       ,x                  PD.DTP
                    cmpa      #DT.SCF
                    bne       hli8
                    lda       <scpath
                    ldb       #SS.FBRgs
                    os9       I$GetStt
                    bcs       hli8
                    ifeq      coco3
                    tfr       a,b                 Wildbits: A = fg<<4 | bg
                    lsra
                    lsra
                    lsra
                    lsra
                    andb      #$0F
                    endc
                    ldx       <base
                    sta       hlsfg,x
                    stb       hlsbg,x
                    inc       hlok,x
                    tst       <nocolr
                    bne       hli8
                    ifeq      coco3
                    leax      pal_ed,pcr
                    lbsr      hl_pal
                    endc
hli8                lda       #$FF                nothing in force yet
                    sta       <hlout
                    rts

* hl_done (from t_done): the terminal's colours back
hl_done             tst       <nocolr
                    bne       hld9
                    ldx       <base
                    tst       hlok,x
                    beq       hld8
                    ifeq      coco3
                    leax      pal_def,pcr
                    lbsr      hl_pal
                    ldx       <base
                    endc
                    lda       hlsfg,x
                    ldb       hlsbg,x
                    lbra      c_pair
hld8                lda       #CL.NORM            (from the editor: its own)
                    ldb       #CL.BG
                    lbra      c_pair
hld9                rts

                    ifeq      coco3
hl_pal              ldb       #14
hpl1                lda       ,x+
                    lbsr      t_ch
                    decb
                    bne       hpl1
                    rts
pal_ed              fcb       $1B,$61,CL.BG,$00,$00,$50,$00
                    fcb       $1B,$60,CL.NORM,$E6,$D6,$7A,$00
pal_def             fcb       $1B,$61,CL.BG,$00,$00,$AA,$00
                    fcb       $1B,$60,CL.NORM,$DD,$DD,$77,$00
                    endc

* c_pair: foreground A on background B (nothing with colours off)
c_pair              tst       <nocolr
                    bne       cp9
                    pshs      d
                    sta       <hlout
                    lda       #$1B
                    lbsr      t_ch
                    lda       #$33
                    lbsr      t_ch
                    lda       1,s
                    lbsr      t_ch
                    lda       #$1B
                    lbsr      t_ch
                    lda       #$32
                    lbsr      t_ch
                    lda       ,s
                    lbsr      t_ch
                    puls      d
cp9                 rts

* c_fg: foreground B
c_fg                tst       <nocolr
                    bne       cf9
                    cmpb      <hlout
                    beq       cf9
                    stb       <hlout
                    pshs      a
                    lda       #$1B
                    lbsr      t_ch
                    lda       #$32
                    lbsr      t_ch
                    tfr       b,a
                    lbsr      t_ch
                    puls      a
cf9                 rts

* c_norm: the page's colours (reverse video off); keeps all registers
c_norm              pshs      d
                    tst       <nocolr
                    beq       cn1
                    lbsr      t_norm
                    puls      d,pc
cn1                 lda       #CL.NORM
                    ldb       #CL.BG
                    bsr       c_pair
                    puls      d,pc

* c_link, c_sel, c_bar: a link, the selected link, the hint line
c_link              pshs      b
                    ldb       #CL.LINK
                    bsr       c_fg
                    puls      b,pc
c_sel               pshs      d
                    tst       <nocolr
                    beq       cs1
                    lbsr      t_rev
                    puls      d,pc
cs1                 ldd       #CL.SELFG*256+CL.SELBG
                    bsr       c_pair
                    puls      d,pc
c_bar               pshs      d
                    tst       <nocolr
                    beq       cb1
                    lbsr      t_rev
                    puls      d,pc
cb1                 ldd       #CL.MBFG*256+CL.MBBG
                    bsr       c_pair
                    puls      d,pc

* mu_wait (keys.asm): wait for a key; if there is a wheel, poll it
* meanwhile.  Carry and A = EK.WHEEL if it turned.  Clicks are not used.
mu_wait             tst       <muwh
                    beq       muw9
muw1                lda       <kbpath
                    ldb       #SS.Ready
                    os9       I$GetStt
                    bcc       muw9                a key
                    cmpb      #E$NotRdy
                    bne       muw9
                    lda       <kbpath
                    ldb       #SS.MsWheel
                    os9       I$GetStt            X = steps
                    bcs       muw9
                    leax      ,x
                    bne       muw2
                    ldx       #1
                    os9       F$Sleep
                    bra       muw1
muw2                stx       <muwst
                    lda       #EK.WHEEL
                    orcc      #Carry
                    rts
muw9                andcc     #^Carry
                    rts
mu_new              andcc     #^Carry
                    rts

                    use       term.asm
                    use       keys.asm

                    emod
eom                 equ       *
                    end
