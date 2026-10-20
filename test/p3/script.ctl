* The editor side of the l2b09run protocol
start -t=/dd/l2b09/term.out
expect %READY
send load p3prog.b09
expect %READY
send run p3main
sleep 30
* break (S$Intrpt): the debugger stops at the current statement
signal 3
expect %DEBUG
send print n
expect %DEBUG
send cont
sleep 20
* abort (S$Abort, RUN/STOP): a break too, so the program stops in the
* debugger; q ends it
signal 2
expect %DEBUG
send q
expect %READY
* compile and bind errors come back with procedure and line
send load p3bad.b09
expect %BERR
expect %READY
* reload just the fixed procedure and run it
send load p3fix.b09
expect %READY
send run p3calc
expect %READY
* save twice: the second time the file exists and the runtime asks
send save* p3sv
expect %READY
send save* p3sv
expect %ASK Rewrite?
send y
expect %READY
* l2b09run has no DIR or RENAME: "What?"
send dir
expect %READY
send rename p3calc,p3sum
expect %READY
* MEM is resident
send mem
expect %READY
* grow the workspace (F$Mem)
send mem 16000
expect %READY
* below the minimum: carry set, "What?"
send mem 1
expect %READY
* an empty line does nothing
send
expect %READY
* PACK runs from the overlay module l2b09ovl (in /dd/CMDS): an error
* in the runtime unlinks it on the way out, and it loads again
send pack nosuch
expect %READY
* export for RunB (PACK strips the workspace copy; reload before packing again)
send pack* p3pk
expect %READY
* an error inside the overlay: the second PACK fails with 51
send pack* p3pk2
expect %READY
send bye
wait
