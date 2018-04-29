# serial-hd-img
Hard drive imager over serial in 16bit x86 DOS assembly 


cserhd.s usage:
	- Check that no changes are needed to the source code of cserhd.com. By default, the C: drive is selected to copy (0x80). To copy a secondary drive change this to 0x81 in the two places in the code.
	- Assemble the program with NASM
		`nasm -f bin cserhd.s -o cserhd.com`
	- Start a program, at 115200 baud, on the remote computer connected via null modem cable to receive a file and write it to disk (it is sent raw, not with a protocol like zmodem or kermit)
	- Run the program `cserhd.com`
	- Wait for the process to complete. Hitting `a` will abort; hitting any other key will display the current copy status.

dump.c usage
	- Compile the program with `gcc dump.c -o dummp`
	- `./dump > drive.img.compressed`

expand.c usage
	- Compile the program with `gcc expand.c -o expand`
	- `cat drive.img.compressed | ./expand drive.img`
