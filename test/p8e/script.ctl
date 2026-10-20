* RUN/STOP (the keyboard abort, signal 2) while INPUT waits on a real
* terminal: a break, as ^C (signal 3), not "ERROR #002"
start -t=/term
expect %READY
send load p8einp.b09
expect %READY
send run p8einp
sleep 30
signal 2
expect %DEBUG
* continuing asks for the input again
send cont
expect %INPUT
sleep 20
signal 2
expect %DEBUG
send q
expect %READY
send run p8einp
sleep 30
signal 3
expect %DEBUG
send q
expect %READY
* GET waits on the terminal too
send load p8eget.b09
expect %READY
send run p8eget
sleep 30
signal 2
expect %DEBUG
send cont
expect %INPUT
sleep 20
signal 3
expect %DEBUG
send q
expect %READY
send bye
