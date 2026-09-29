********************************************************************
* farmem - memory beyond 64K for Basic09 programs
*
* A far memory area is a set of whole 8K RAM blocks outside the
* program's address space.  The program owns a small descriptor
* (DIM fm(4):INTEGER) and moves variables in and out as records:
*
*   RUN farmem("alloc",fm,kb)       allocate kb kilobytes (whole 8K blocks)
*   RUN farmem("put",fm,index,var)  copy var to record index
*   RUN farmem("get",fm,index,var)  copy record index to var
*   RUN farmem("unmap",fm)          give back the 8K address window
*   RUN farmem("free",fm)           release the blocks (ALWAYS do this)
*
* A record is SIZE(var) bytes, so record <index> starts at byte
* index*SIZE(var).  index is an INTEGER, taken as unsigned (0-65535).
* Records may straddle block boundaries.  Any variable works: a REAL,
* a string, a whole array, or a record TYPE.
*
* One block at a time is mapped into an 8K window of the program's
* address space and stays mapped between calls, so consecutive
* accesses to the same block cost no system calls.  The program must
* leave one 8K slot of its 64K free for the window.
*
* Blocks from F$AllRAM do not belong to the process: if the program
* ends without "free" they stay allocated until the system restarts.
*
* Errors: 56 (E$ParmEr) bad parameters or unknown command,
*         55 subscript out of range (record past the end),
*         and OS-9 errors from F$AllRAM (237) or F$MapBlk (207).

                    nam       farmem
                    ttl       Far memory for Basic09

Level               set       2                   F$AllRAM, F$MapBlk and friends are Level 2 calls

                    ifp1
                    use       defsfile
                    endc

tylg                set       Sbrtn+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       1

                    mod       eom,name,tylg,atrv,start,0

name                fcs       /farmem/
                    fcb       edition

* Descriptor: DIM fm(4):INTEGER
FM.BLK              equ       0                   first physical block, 0 = none
FM.CNT              equ       2                   number of blocks
FM.MAP              equ       4                   mapped block index, -1 = none
FM.WIN              equ       6                   window address
FM.SIZ              equ       8

* Parameter block, addressed through U (U = entry S + 2)
PCOUNT              equ       0
P1A                 equ       2                   command string
P1L                 equ       4
P2A                 equ       6                   descriptor
P2L                 equ       8
P3A                 equ       10                  kb or index
P3L                 equ       12
P4A                 equ       14                  variable
P4L                 equ       16

* get/put stack frame
F.DIR               equ       0                   0 = get, 1 = put
F.OFF               equ       1                   32-bit byte offset of the record
F.N                 equ       5                   bytes still to copy
F.P                 equ       7                   local pointer
F.U                 equ       9                   saved parameter block pointer
F.T                 equ       11                  24-bit temporary
FRAME               equ       14

E.RANGE             equ       55                  Basic09 "subscript out of range"

kalloc              fcs       /alloc/
kfree               fcs       /free/
kget                fcs       /get/
kput                fcs       /put/
kunmap              fcs       /unmap/

start               leau      2,s                 U = parameter block
                    ldd       PCOUNT,u
                    cmpd      #2
                    blo       parmerr
                    ldd       P2L,u               descriptor must be 4 INTEGERs
                    cmpd      #FM.SIZ
                    bne       parmerr
                    leay      kalloc,pcr
                    bsr       iscmd
                    lbeq      doalloc
                    leay      kget,pcr
                    bsr       iscmd
                    lbeq      doget
                    leay      kput,pcr
                    bsr       iscmd
                    lbeq      doput
                    leay      kunmap,pcr
                    bsr       iscmd
                    lbeq      dounmap
                    leay      kfree,pcr
                    bsr       iscmd
                    lbeq      dofree
parmerr             ldb       #E$ParmEr
error               coma
                    rts

* Is the command string the keyword at (Y)?  Case is ignored; the
* string must end (length or $FF terminator) after the keyword.
* Returns Z set on a match.
iscmd               ldx       P1A,u
                    pshs      u
                    ldu       P1L,u               characters left in the string
isc1                cmpu      #0
                    beq       iscno               string too short
                    lda       ,y
                    anda      #$7F
                    ldb       ,x+
                    orb       #$20                lower case (keywords are lower case)
                    pshs      a
                    cmpb      ,s+
                    bne       iscno
                    leau      -1,u
                    tst       ,y+                 last keyword char?
                    bpl       isc1
                    cmpu      #0                  string ended?
                    beq       iscyes
                    lda       ,x
                    cmpa      #$FF
                    beq       iscyes
iscno               andcc     #%11111011          Z clear
                    puls      u,pc
iscyes              orcc      #%00000100          Z set
                    puls      u,pc

* alloc: fm, kb
doalloc             ldd       PCOUNT,u
                    cmpd      #3
                    bne       parmerr
                    ldd       P3L,u
                    cmpd      #2                  kb must be an INTEGER
                    bne       parmerr
                    ldd       [P3A,u]
                    ble       rangerr
                    addd      #7                  round up to 8K blocks
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    tsta
                    bne       rangerr             more than 255 blocks
                    pshs      b
                    os9       F$AllRAM            D = first block
                    puls      a
                    bcs       error
                    ldx       P2A,u
                    std       FM.BLK,x            (A was the count; fixed below)
                    clr       FM.BLK,x
                    sta       FM.CNT+1,x
                    clr       FM.CNT,x
                    ldd       #-1
                    std       FM.MAP,x
                    clr       FM.WIN,x
                    clr       FM.WIN+1,x
                    clrb
                    rts

rangerr             ldb       #E.RANGE
                    coma
                    rts

* unmap: fm
dounmap             ldx       P2A,u
                    bsr       unmap
                    clrb
                    rts

* free: fm
dofree              ldx       P2A,u
                    bsr       unmap
                    ldd       FM.BLK,x
                    beq       free9               nothing allocated
                    pshs      x
                    ldb       FM.CNT+1,x
                    ldx       FM.BLK,x
                    os9       F$DelRAM
                    puls      x
                    lbcs      error
                    ldd       #0
                    std       FM.BLK,x
                    std       FM.CNT,x
free9               clrb
                    rts

* Release the window of descriptor (X), if one is mapped
unmap               ldd       FM.MAP,x
                    cmpd      #-1
                    beq       unmap9
                    pshs      x,u
                    ldu       FM.WIN,x
                    ldb       #1
                    os9       F$ClrBlk
                    puls      x,u
                    ldd       #-1
                    std       FM.MAP,x
unmap9              rts

* get/put: fm, index, var
doget               clra
                    bra       getput
doput               lda       #1
getput              pshs      a
                    ldd       PCOUNT,u
                    cmpd      #4
                    lbne      gperr
                    ldd       P3L,u
                    cmpd      #2                  index must be an INTEGER
                    lbne      gperr
                    ldx       P2A,u
                    ldd       FM.BLK,x
                    lbeq      gperr               not allocated
                    puls      a
                    leas      -FRAME,s
                    sta       F.DIR,s
                    stu       F.U,s
                    ldd       P4L,u
                    std       F.N,s
                    ldd       P4A,u
                    std       F.P,s
* offset = index * size (unsigned 16 x 16 -> 32)
                    ldy       P3A,u               Y -> index
                    ldd       #0
                    std       F.OFF,s
                    std       F.OFF+2,s
                    lda       1,y                 index lo * size lo
                    ldb       P4L+1,u
                    mul
                    std       F.OFF+2,s
                    lda       ,y                  index hi * size lo
                    ldb       P4L+1,u
                    mul
                    addd      F.OFF+1,s
                    std       F.OFF+1,s
                    bcc       mul1
                    inc       F.OFF,s
mul1                lda       1,y                 index lo * size hi
                    ldb       P4L,u
                    mul
                    addd      F.OFF+1,s
                    std       F.OFF+1,s
                    bcc       mul2
                    inc       F.OFF,s
mul2                lda       ,y                  index hi * size hi
                    ldb       P4L,u
                    mul
                    addd      F.OFF,s
                    std       F.OFF,s
* range: the block holding the last byte (offset+size-1) must exist
                    ldd       F.OFF+2,s
                    addd      F.N,s
                    std       F.T+1,s
                    lda       F.OFF+1,s
                    adca      #0
                    sta       F.T,s
                    ldb       F.OFF,s
                    adcb      #0
                    bne       gprange             past 16M
                    ldd       F.T+1,s             minus 1 (size is at least 1)
                    subd      #1
                    std       F.T+1,s
                    lda       F.T,s
                    sbca      #0
                    ldb       F.T+1,s
                    bsr       lastblk             D = block of the last byte
                    ldx       P2A,u
                    cmpd      FM.CNT,x
                    bhs       gprange
* copy, one block at a time
gploop              ldd       F.N,s
                    beq       gpdone
                    lda       F.OFF+1,s           block of the current offset
                    ldb       F.OFF+2,s
                    bsr       lastblk
                    ldx       P2A,u
                    lbsr      mapblk              Y = window
                    bcs       gperr2
                    ldd       F.OFF+2,s           offset in block
                    anda      #$1F
                    leay      d,y                 far address
                    pshs      d
                    ldd       #$2000
                    subd      ,s++                room left in this block
                    cmpd      F.N,s
                    bls       gp1
                    ldd       F.N,s
gp1                 tfr       d,x                 X = chunk
                    pshs      d
                    ldu       F.P+2,s             local pointer
                    tst       F.DIR+2,s
                    bne       gpput
gpget               lda       ,y+
                    sta       ,u+
                    leax      -1,x
                    bne       gpget
                    bra       gp2
gpput               lda       ,u+
                    sta       ,y+
                    leax      -1,x
                    bne       gpput
gp2                 stu       F.P+2,s
                    ldu       F.U+2,s
                    ldd       F.N+2,s             N -= chunk
                    subd      ,s
                    std       F.N+2,s
                    ldd       F.OFF+2+2,s         offset += chunk
                    addd      ,s++
                    std       F.OFF+2,s
                    bcc       gploop
                    inc       F.OFF+1,s
                    bra       gploop
gpdone              leas      FRAME,s
                    clrb
                    rts
gprange             leas      FRAME,s
                    lbra      rangerr
gperr2              leas      FRAME,s
                    coma
                    rts
gperr               leas      1,s
                    lbra      parmerr

* D = (A << 3) | (B >> 5): block number from bits 23-13 of an offset
lastblk             pshs      b
                    tfr       a,b
                    clra
                    aslb
                    rola
                    aslb
                    rola
                    aslb
                    rola
                    pshs      d
                    lda       2,s
                    lsra
                    lsra
                    lsra
                    lsra
                    lsra
                    ora       1,s
                    sta       1,s
                    puls      d
                    leas      1,s
                    rts

* Map block index (D) of descriptor (X); returns Y = window address.
* Keeps the current mapping when it is already that block.
mapblk              cmpd      FM.MAP,x
                    beq       mapok
                    pshs      d,x,u
                    ldd       FM.MAP,x
                    cmpd      #-1
                    beq       map1
                    ldu       FM.WIN,x            release the old block
                    ldb       #1
                    os9       F$ClrBlk
map1                ldx       2,s
                    ldd       FM.BLK,x
                    addd      ,s                  physical block
                    tfr       d,x
                    ldb       #1
                    os9       F$MapBlk            U = window address
                    bcs       maperr
                    ldx       2,s
                    stu       FM.WIN,x
                    ldd       ,s
                    std       FM.MAP,x
                    puls      d,x,u
mapok               ldy       FM.WIN,x
                    andcc     #%11111110          carry clear
                    rts
maperr              pshs      b
                    ldx       3,s
                    ldd       #-1
                    std       FM.MAP,x
                    puls      b
                    leas      2,s
                    puls      x,u
                    coma
                    rts

                    emod
eom                 equ       *
                    end
