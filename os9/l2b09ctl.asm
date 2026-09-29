********************************************************************
* l2b09ctl - drive l2b09run's command channel from a script
*
* Plays the part of an editor: forks l2b09run with anonymous pipes on
* its standard input (commands) and standard error (events), then
* follows a script read from its own standard input:
*
*   * <text>         comment
*   start <params>   fork l2b09run <params> with the pipes attached
*   send <text>      write <text> to the runtime's command input
*   expect <text>    read runtime lines until one contains <text>
*   signal <n>       send signal <n> to the runtime (3 = break, 2 = abort)
*   sleep <ticks>    sleep
*   wait             wait for the runtime to exit; print its status
*
* Script lines are echoed as "> <line>", runtime lines as "< <line>".
* 'expect' blocks until the text arrives (pipes cannot be polled).

                    nam       l2b09ctl
                    ttl       Script driver for the l2b09run command channel

                    ifp1
                    use       defsfile
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       1

                    mod       eom,name,tylg,atrv,start,size

                    org       0
save0               rmb       1                   our standard input, set aside
save2               rmb       1                   our standard error, set aside
pa                  rmb       1                   runtime command input (we write)
pb                  rmb       1                   runtime command output (we read)
child               rmb       1                   runtime process id
argp                rmb       2                   argument in the script line
line                rmb       130                 script line
rline               rmb       258                 runtime line
                    rmb       250                 stack
size                equ       .

name                fcs       /l2b09ctl/
                    fcb       edition

pipenm              fcc       "/pipe"
                    fcb       C$CR
prognm              fcc       "l2b09run"
                    fcb       C$CR
gtmsg               fcc       "> "
ltmsg               fcc       "< "
exitms              fcc       "exit "
badmsg              fcc       "?? unknown command"
                    fcb       C$CR
kstart              fcc       "start"
                    fcb       0
ksend               fcc       "send"
                    fcb       0
kexpct              fcc       "expect"
                    fcb       0
ksignl              fcc       "signal"
                    fcb       0
ksleep              fcc       "sleep"
                    fcb       0
kwait               fcc       "wait"
                    fcb       0

start               equ       *
loop                leax      line,u              read the next script line
                    ldy       #128
                    clra
                    os9       I$ReadLn
                    bcs       eof
                    leax      gtmsg,pcr           echo it
                    ldy       #2
                    lda       #1
                    os9       I$Write
                    leax      line,u
                    ldy       #128
                    lda       #1
                    os9       I$WritLn
                    leax      line,u
                    lda       ,x
                    cmpa      #'*                 comment?
                    beq       loop
                    cmpa      #C$CR               blank?
                    beq       loop
                    leay      kstart,pcr
                    lbsr      match
                    lbeq      dostart
                    leay      ksend,pcr
                    lbsr      match
                    lbeq      dosend
                    leay      kexpct,pcr
                    lbsr      match
                    lbeq      doexp
                    leay      ksignl,pcr
                    lbsr      match
                    lbeq      dosig
                    leay      ksleep,pcr
                    lbsr      match
                    lbeq      dosleep
                    leay      kwait,pcr
                    lbsr      match
                    lbeq      dowait
                    leax      badmsg,pcr
                    ldy       #80
                    lda       #1
                    os9       I$WritLn
                    bra       loop

eof                 cmpb      #E$EOF
                    bne       err
                    clrb
                    os9       F$Exit

err                 pshs      b
                    lda       #2
                    os9       F$PErr
                    puls      b
                    os9       F$Exit

* start <params>: fork l2b09run with pipe A on its path 0, pipe B on its path 2
dostart             clra
                    os9       I$Dup
                    bcs       err
                    sta       save0,u
                    clra
                    os9       I$Close
                    leax      pipenm,pcr          pipe A becomes our path 0
                    lda       #UPDAT.
                    os9       I$Open
                    bcs       err
                    clra
                    os9       I$Dup
                    bcs       err
                    sta       pa,u
                    lda       #2
                    os9       I$Dup
                    bcs       err
                    sta       save2,u
                    lda       #2
                    os9       I$Close
                    leax      pipenm,pcr          pipe B becomes our path 2
                    lda       #UPDAT.
                    os9       I$Open
                    bcs       err
                    lda       #2
                    os9       I$Dup
                    bcs       err
                    sta       pb,u
                    ldx       argp,u              parameter length, CR included
                    ldy       #0
cnt                 leay      1,y
                    lda       ,x+
                    cmpa      #C$CR
                    bne       cnt
                    pshs      u
                    ldu       argp,u
                    leax      prognm,pcr
                    clra                          any type/language
                    clrb                          default data size
                    os9       F$Fork
                    puls      u
                    lbcs      err
                    sta       child,u
                    clra                          put our own paths back
                    os9       I$Close
                    lda       save0,u
                    os9       I$Dup
                    lda       save0,u
                    os9       I$Close
                    lda       #2
                    os9       I$Close
                    lda       save2,u
                    os9       I$Dup
                    lda       save2,u
                    os9       I$Close
                    lbra      loop

* send <text>
dosend              ldx       argp,u
                    ldy       #128
                    lda       pa,u
                    os9       I$WritLn
                    lbcs      err
                    lbra      loop

* expect <text>
doexp               leax      rline,u
                    ldy       #256
                    lda       pb,u
                    os9       I$ReadLn
                    lbcs      err
                    leax      ltmsg,pcr
                    ldy       #2
                    lda       #1
                    os9       I$Write
                    leax      rline,u
                    ldy       #256
                    lda       #1
                    os9       I$WritLn
                    leax      rline,u             look for the text anywhere in the line
ex1                 ldy       argp,u
                    pshs      x
ex2                 lda       ,y+
                    cmpa      #C$CR
                    beq       exfnd
                    cmpa      ,x+
                    beq       ex2
                    puls      x
                    lda       ,x+
                    cmpa      #C$CR
                    bne       ex1
                    bra       doexp               not in this line; read another
exfnd               puls      x
                    lbra      loop

* signal <n>
dosig               lbsr      getnum
                    lda       child,u
                    os9       F$Send
                    lbcs      err
                    lbra      loop

* sleep <ticks>
dosleep             lbsr      getnum
                    tfr       d,x
                    os9       F$Sleep
                    lbra      loop

* wait
dowait              os9       F$Wait
                    lbcs      err
                    pshs      b
                    leax      exitms,pcr
                    ldy       #5
                    lda       #1
                    os9       I$Write
                    puls      b
                    leax      rline,u             exit status in decimal
                    lda       #'0-1
pd1                 inca
                    subb      #100
                    bcc       pd1
                    addb      #100
                    sta       ,x+
                    lda       #'0-1
pd2                 inca
                    subb      #10
                    bcc       pd2
                    addb      #10
                    sta       ,x+
                    addb      #'0
                    stb       ,x+
                    lda       #C$CR
                    sta       ,x+
                    leax      rline,u
                    ldy       #4
                    lda       #1
                    os9       I$WritLn
                    lbra      loop

* Match keyword (Y, zero terminated) at the start of (X); the keyword
* must be followed by a space or CR.  Sets argp past the space.
* Returns Z set on a match; preserves X.
match               pshs      x
mat1                lda       ,y+
                    beq       mat2
                    cmpa      ,x+
                    beq       mat1
                    puls      x,pc                Z clear from the compare
mat2                lda       ,x
                    cmpa      #C$SPAC
                    bne       mat3
                    leax      1,x
                    bra       mat4
mat3                cmpa      #C$CR
                    bne       matno
mat4                stx       argp,u
                    puls      x
                    orcc      #%00000100          Z set
                    rts
matno               puls      x
                    andcc     #%11111011          Z clear
                    rts

* Decimal number at argp -> (D)
getnum              pshs      x
                    ldx       argp,u
                    ldd       #0
gn1                 pshs      d                   accumulator
                    lda       ,x+
                    suba      #'0
                    cmpa      #9
                    bhi       gn9
                    pshs      a                   digit
                    ldd       1,s
                    aslb
                    rola
                    std       1,s                 *2
                    aslb
                    rola
                    aslb
                    rola                          *8
                    addd      1,s                 *10
                    addb      ,s+                 +digit
                    adca      #0
                    leas      2,s
                    bra       gn1
gn9                 puls      d
                    puls      x,pc

                    emod
eom                 equ       *
                    end
