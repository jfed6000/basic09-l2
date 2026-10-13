********************************************************************
* l2b09ovl - cold commands for l2b09run
*
* l2b09run's code is at its 24,576-byte limit (docs/ARCHITECTURE.md,
* "l2b09run size"), so commands that are seldom typed live here.
* L2OVLY in comand.asm links this module (or loads it from the
* execution directory), calls entry B with the command line in (Y)
* and Basic09's direct page in DP, and unlinks it again.  The code
* reaches the runtime through the jump tables, as the other parts of
* Basic09 do; an error exits through the trap L2OVLY sets.
*
* Entries: 0 PACK (src/pack, the stock DUMP routine), 1 DIR
* (src/dir), 2 RENAME (src/rename), 3 MEM (src/mem), 4 DIR05 (an
* empty command line: DIR without a path)

 nam l2b09ovl
 ttl l2basic09 cold-command overlay
 use defs

OVLBEG mod OVLEND,OVLNAM,SBRTN+OBJCT,REENT+1,OVLENT,0
OVLNAM fcs /l2b09ovl/
 fcb 1 edition

OVLENT lbra DUMP entry 0: PACK
 lbra DIR 1
 lbra RENAME 2
 lbra CHGMEM 3
 lbra DIR05 4

***************
* Into the runtime.  Each stub jumps to the routine, which returns
* to the stub's caller, so call them with LBSR.

L2BPZ jsr M.COMAND
 fcb X$BPZ Clear all breakpoints
DEFILE jsr M.COMAND
 fcb X$DEFL Procedure list and pathname
OPNCH0 jsr M.COMAND
 fcb X$OPN0 Open the command output path
CLSCHL jsr M.COMAND
 fcb X$CLSC Close it again
UNBIND jsr M.COMAND
 fcb X$UNBD Unbind a procedure
NXTVAR jsr M.COMAND
 fcb X$NXVR Next variable reference in I-code
J$EREX jsr M.COMAND
 fcb X$EREX Print error message and return
NEWLIN jsr M.COMAND
 fcb X$NWLN Reset the I/O buffer
PUTCHR jsr M.COMAND
 fcb X$PUTC Put a character in it
STRSPC jsr M.COMAND
 fcb X$STSP Put a string and a space in it
STREOL jsr M.COMAND
 fcb X$STEL Put a string in it and print it
PRTEOL jsr M.COMAND
 fcb X$PEOL Print it
DIRSCH jsr M.COMAND
 fcb X$DSCH Search the procedure directory
REPLAC jsr M.COMAND
 fcb X$RPLC Replace I-code
J$NAME jsr M.COMPIL
 fcb X$NAME Look for a name
J$CVIO jsr M.CNVIO
 fcb X$CVIO Call cnvio
J$ASNM jsr M.CNVIO
 fcb X$ASNM ASCII to numeric
J$BIND jsr M.BINDER
 fcb X$BIND Bind procedure

***************
* Error exits, as in comand.asm

ERRST lbsr CLSCHL Close the path
 bra ERREXT
ERABRT ldb #M$ERST
 bra ERREXT
ERMFUL ldb #M$MFUL
ERPRCX ldb #M$MDPC
 bra ERREXT
ERUPRC ldb #M$UPRC
ERREXT lbsr J$EREX Print error number
 jsr M.COMAND
 fcb X$EXIT Exit via the trap

***************
* Small helpers, copied from comand.asm and editor

PRTLIN lbsr NEWLIN Print the line at (X)
 bra STREOL

OPNCHL bsr CMDSEP Open an output path if one is named
 cmpb #V$CR
 beq OPNC99
 stx I.IOPT
 ldd #WRITE.*256+UPDAT.+PREAD.
 lbra OPNCH0
OPNC99 rts

GETNUM ldy I.OPBG Positive integer from the command line
 lbsr J$ASNM
 lda ,Y+
 cmpa #S.REAL
 beq GETNCS
 clra
 ldd ,Y
 bne GETNU9
GETNCS coma
GETNU9 rts

CMDSEP ldb ,Y+ Skip a command separator
 cmpb #',
 beq CMDSE9
 cmpb #V$SPAC
 beq CMDSE9
 leay -1,Y
CMDSE9 rts

PRCREF lbsr J$NAME A procedure name, or the current one
 bne PRCRE9
 ldy I.APRC
 beq PRCRE1
 ldd M$NAME,Y
 leay D,Y
 rts
PRCRE1 leay DEFNAM,PCR
PRCRE9 rts

 use rename
 lbsr J$BIND Rebind the procedure
 clra carry clear
 rts

 use mem
 use dir
ItoA jsr M.COMAND
 fcb X$ITOA DIRNUM falls through to ItoA

 use pack

FREE fcs " free"
DEFNAM fcs "Program"
DIRHDR fcb $A
 fcs "  Name      Proc-Size  Data-Size"

 emod
OVLEND equ *
