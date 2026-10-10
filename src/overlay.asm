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
* Entry 0: PACK (src/pack, the stock DUMP routine)

 nam l2b09ovl
 ttl l2basic09 cold-command overlay
 use defs

OVLBEG mod OVLEND,OVLNAM,SBRTN+OBJCT,REENT+1,OVLENT,0
OVLNAM fcs /l2b09ovl/
 fcb 1 edition

OVLENT lbra DUMP entry 0: PACK

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
J$BIND jsr M.BINDER
 fcb X$BIND Bind procedure

***************
* Error exits, as in comand.asm

ERRST lbsr CLSCHL Close the path
 bra ERREXT
ERABRT ldb #M$ERST
 bra ERREXT
ERMFUL ldb #M$MFUL
ERREXT lbsr J$EREX Print error number
 jsr M.COMAND
 fcb X$EXIT Exit via the trap

 use pack

 emod
OVLEND equ *
