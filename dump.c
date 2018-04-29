#define _BSD_SOURCE

#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <stdint.h>

int main(int argc, char * argv[]){
	//	struct sigaction new_action, old_action
	//	new_action.sa_handler = ctrlC;
	//	sigemptyset
	if (argc<2){
		printf("incorrect parameters\n");
		return 1;

	}
	//Assume the device is the first argument
	int sf;
	sf = open(argv[1], O_RDWR | O_NOCTTY);
	if(sf == -1){
		printf("failed to open file\n");
		return 2;
	}
	if(!isatty){
		printf("file does not refer to a TTY device\n");
		return 3;
	}
	struct termios serConfig;
	if(tcgetattr(sf, &serConfig)<0){
		printf("Unable to get attrib for port");
		return 4;
	}
	//Serconfig now contains the current config, Update the relevant fields of the struct

	//
	// Input flags - Turn off input processing
	//
	// convert break to null byte, no CR to NL translation,
	// no NL to CR translation, don't mark parity errors or breaks
	// no input parity check, don't strip high bit off,
	// no XON/XOFF software flow control
	//
	serConfig.c_iflag &= ~(IGNBRK | BRKINT | ICRNL | INLCR | PARMRK | INPCK | ISTRIP | IXON);

	//
	// Output flags - Turn off output processing
	//
	// no CR to NL translation, no NL to CR-NL translation,
	// no NL to CR translation, no column 0 CR suppression,
	// no Ctrl-D suppression, no fill characters, no case mapping,
	// no local output processing
	//
	// serConfig.c_oflag &= ~(OCRNL | ONLCR | ONLRET |
	//                     ONOCR | ONOEOT| OFILL | OLCUC | OPOST);
	serConfig.c_oflag = 0;

	//
	// No line processing
	//
	// echo off, echo newline off, canonical mode off, 
	// extended input processing off, signal chars off
	//
	serConfig.c_lflag &= ~(ECHO | ECHONL | ICANON | IEXTEN | ISIG);

	//
	// Turn off character processing
	//
	// clear current char size mask, no parity checking,
	// no output processing, force 8 bit input
	//
	serConfig.c_cflag &= ~(CSIZE | PARENB);
	serConfig.c_cflag |= CS8;

	//
	// One input byte is enough to return from read()
	// Inter-character timer off
	//
	serConfig.c_cc[VMIN]  = 1;
	serConfig.c_cc[VTIME] = 0;

	//
	// Communication speed (simple version, using the predefined
	// constants)
	//
	if(cfsetispeed(&serConfig, B115200) < 0 || cfsetospeed(&serConfig, B115200) < 0) {
	       printf("error setting tx or rx speed\n");
	       return 5; 
	}


	if(tcsetattr(sf, TCSAFLUSH, &serConfig) < 0){
	       printf("error updating termios config\n");
	       return 6;
	}
	ssize_t bWritten = 0;
	char * c = malloc(sizeof(char) * 100);
	while(1==1){
		bWritten = 0;
		while(bWritten < 1){
			usleep(10);
			memset(c, 0, 100);
			bWritten = read(sf, c, 99);
		}
		fwrite(c, sizeof(char), bWritten, stdout);
		fflush(stdout);
	}
	free(c);
	close(sf);
	return 0;
}
