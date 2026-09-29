********************************************************************
* l2b09ed - the l2basic09 editor
*
* A full-screen editor for Basic09 source (docs/EDITOR.md).  The text
* is paged: it lives in 2K pages in a swap file, and only a few pages
* are cached in memory, so a file can be much larger than the editor's
* 64K address space.
*
* usage: l2b09ed [-c=<pages>] [<file>]
*
*   -c=<pages>  number of 2K pages cached in memory (3-24, default 12)
*
* Keys are read from path 0 and the screen is written to path 1.  When
* path 0 is not a terminal (a test script), SS.KySns fails and the key
* sense bits come from a prefix: $FF <kysns> <char>.

                    nam       l2b09ed
                    ttl       l2basic09 editor

                    ifp1
                    use       defsfile
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       1

                    mod       eom,name,tylg,atrv,start,size

PGSZ                equ       2048                page size, also the swap slot size
PGHALF              equ       PGSZ/2              a full page splits here
PGFILL              equ       1536                bytes per page when a file is read
PGLOW               equ       PGSZ/4              pages below this try to merge
NDESC               equ       512                 page descriptors (the most pages)
NCMAX               equ       24                  most cache buffers
NCMIN               equ       3                   fewest cache buffers
NCDEF               equ       12                  cache buffers by default
TABW                equ       8                   tab stops
OUTSZ               equ       256                 screen output buffer
STKSZ               equ       768
C$TAB               equ       $09

* Page descriptor
                    org       0
DS.NEXT             rmb       2                   next page (0 = last)
DS.PREV             rmb       2                   previous page (0 = first)
DS.USED             rmb       2                   bytes of text in the page
DS.LINES            rmb       2                   carriage returns in the page
DS.SLOT             rmb       2                   swap file slot
DS.CE               rmb       2                   cache entry holding the page (0 = none)
DS.FLAG             rmb       1
DS.SIZE             equ       .

DF.SWAP             equ       $01                 the swap slot holds the page
DF.CHG              equ       $02                 changed since the last Make

* Cache entry
                    org       0
CE.DESC             rmb       2                   page held (0 = free)
CE.BUF              rmb       2                   2K buffer
CE.AGE              rmb       2                   last use (LRU clock)
CE.DIRT             rmb       1                   buffer differs from the swap slot
CE.SIZE             equ       .

* Redraw flags
RD.ALL              equ       $01                 the whole text window
RD.BELOW            equ       $02                 the cursor line and everything below it
RD.LINE             equ       $04                 the cursor line

* Data area.  The first 256 bytes are the direct page; everything else
* is reached through the pointers set up at start.
                    org       0
base                rmb       2                   data area address
kbpath              rmb       1                   key input path
scpath              rmb       1                   screen path
swpath              rmb       1                   swap file path
flpath              rmb       1                   file being read or written
kbterm              rmb       1                   key input is a terminal
scrw                rmb       1                   screen columns
scrh                rmb       1                   screen rows
wtop                rmb       1                   text window: first row
wrows               rmb       1                   rows
wleft               rmb       1                   first column
wcols               rmb       1                   columns
descp               rmb       2                   descriptor table
cachp               rmb       2                   cache table
cbufp               rmb       2                   first cache buffer
ncache              rmb       1                   cache buffers
clock               rmb       2                   LRU clock
freed               rmb       2                   free descriptors
first               rmb       2                   first page of the text
nlines              rmb       2                   carriage returns in the text
* Tracked positions: page edits keep these pointing at the same text.
* A position is a page descriptor and an offset in that page.
posarr              equ       .
cpos                rmb       4                   cursor
tpos                rmb       4                   start of the top line in the window
apos                rmb       4                   selection anchor
xpos                rmb       4                   scratch
NPOS                equ       (.-posarr)/4
wp                  rmb       4                   work position (not tracked)
curline             rmb       2                   cursor line (0 = first)
curcol              rmb       2                   cursor display column
wantcol             rmb       2                   column kept by vertical moves
setwant             rmb       1                   the command sets wantcol
topline             rmb       2                   line at the top of the window
leftcol             rmb       2                   first column shown
redraw              rmb       1                   RD.* flags
modif               rmb       1                   text changed since the last save
key                 rmb       1                   normalized key
kraw                rmb       1                   raw key byte
ksns                rmb       1                   key sense bits
outp                rmb       2                   next byte in the output buffer
outb                rmb       2                   output buffer
oute                rmb       2                   end of the output buffer
msgp                rmb       2                   status line message (0 = none)
msgerr              rmb       1                   error number for the status line
errno               rmb       1                   error from a page operation
vcnt                rmb       1                   columns written in a text row
delch               rmb       1                   character just deleted
sd                  rmb       2                   page operations: first page
sn                  rmb       2                   second page
tf                  rmb       2                   trk_move: from page
tm                  rmb       2                   lowest offset moved
tt                  rmb       2                   to page
tk                  rmb       2                   offset change
tmp                 rmb       2
tmpc                rmb       2
argp                rmb       2                   parameters
dpend               equ       .

                    org       256
optsav              rmb       32                  terminal options on entry
optraw              rmb       32                  terminal options while editing
fname               rmb       64                  file name
inbuf               rmb       82                  prompt input
sbuf                rmb       130                 status line text
outbuf              rmb       OUTSZ
desctab             rmb       NDESC*DS.SIZE
cachtab             rmb       NCMAX*CE.SIZE
                    rmb       STKSZ
stktop              equ       .
size                equ       .                   cache buffers follow

name                fcs       /l2b09ed/
                    fcb       edition

swpnm               fcc       "l2b09ed.swp"
                    fcb       C$CR

start               tfr       u,d
                    tfr       a,dp
                    pshs      x                   parameters (they stay above our stack)
                    leay      dpend,u             clear the direct page variables
                    leax      ,u
st1                 clr       ,x+
                    pshs      y
                    cmpx      ,s++
                    blo       st1
                    puls      x
                    stx       <argp
                    stu       <base
                    lbsr      getargs             file name and options
                    ldu       <base
                    leas      stktop,u            our own stack, below the cache buffers
                    leax      desctab,u
                    stx       <descp
                    leax      cachtab,u
                    stx       <cachp
                    leax      size,u
                    stx       <cbufp
                    leax      outbuf,u
                    stx       <outb
                    stx       <outp
                    leax      OUTSZ,x
                    stx       <oute
                    lbsr      getmem              room for the cache buffers
                    lbsr      pg_init
                    lbsr      t_init              raw keys, screen size
                    lbsr      sw_open
                    lbsr      f_load
                    bcc       st2
                    stb       <msgerr
st2                 ldd       <first
                    std       <cpos
                    std       <tpos
                    std       <apos
                    std       <xpos
                    lda       #RD.ALL
                    sta       <redraw
                    lbsr      t_cls
                    lbra      m_loop

* getargs: [-c=<n>] [<file>] -> ncache, fname
getargs             ldb       #NCDEF
                    stb       <ncache
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
                    cmpa      #'C
                    bne       ga4
                    lda       ,x+
                    cmpa      #'=
                    bne       ga4
                    lbsr      getnum
                    cmpb      #NCMIN
                    bhs       ga2
                    ldb       #NCMIN
ga2                 cmpb      #NCMAX
                    bls       ga3
                    ldb       #NCMAX
ga3                 stb       <ncache
                    bra       ga1
ga4                 lda       ,x+                 skip an unknown option
                    cmpa      #C$SPAC
                    beq       ga1
                    cmpa      #C$CR
                    bne       ga4
                    bra       ga9
ga5                 leax      -1,x                the file name
                    ldy       <base
                    leay      fname,y
                    ldb       #63
ga6                 lda       ,x+
                    cmpa      #C$SPAC
                    beq       ga7
                    cmpa      #C$CR
                    beq       ga7
                    sta       ,y+
                    decb
                    bne       ga6
ga7                 clr       ,y
                    leax      -1,x
                    bra       ga1
ga9                 rts

* getnum: decimal number at X -> D; X past it
getnum              ldd       #0
gn1                 pshs      d
                    lda       ,x
                    suba      #'0
                    cmpa      #9
                    bhi       gn9
                    leax      1,x
                    ldd       ,s
                    aslb
                    rola
                    std       ,s
                    aslb
                    rola
                    aslb
                    rola
                    addd      ,s++
                    pshs      d
                    ldb       -1,x
                    subb      #'0
                    clra
                    addd      ,s++
                    bra       gn1
gn9                 puls      d,pc

* getmem: grow the data area for ncache buffers, with fewer if memory is short
getmem              ldb       <ncache
gm1                 lda       #PGSZ/256
                    mul                           D = buffers * PGSZ / 256
                    tfr       b,a
                    clrb
                    addd      #size
                    os9       F$Mem
                    bcc       gm9
                    dec       <ncache
                    ldb       <ncache
                    cmpb      #NCMIN
                    bhs       gm1
                    ldb       #E$MemFul
                    lbra      fatal
gm9                 rts

* fatal: B = error.  Put the terminal back and exit.
fatal               pshs      b
                    lbsr      t_done
                    lbsr      sw_close
                    puls      b
                    os9       F$Exit

* quit: leave the editor
quit                lbsr      t_done
                    lbsr      sw_close
                    clrb
                    os9       F$Exit

                    use       term.asm
                    use       keys.asm
                    use       page.asm
                    use       view.asm
                    use       edit.asm

                    emod
eom                 equ       *
                    end
