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
* abort (S$Abort): back to command mode
signal 2
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
* export for RunB (PACK strips the workspace copy; reload before packing again)
send pack* p3pk
expect %READY
send bye
wait
