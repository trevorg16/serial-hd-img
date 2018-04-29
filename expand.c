#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char ** argv){
	if(argc < 2)
	{
		printf("Must have argument with name of output file");
		return 1;
	}
	char * zeroBuf = malloc(sizeof(char)*255);
	memset(zeroBuf, 0, 255);
	int inputChar = 0;
	FILE * decompOut = fopen(argv[1], "w");//Decompressed output
	while(inputChar != EOF){
		inputChar = getchar();
		if (inputChar == 0){
			inputChar = getchar();
			fwrite(zeroBuf, inputChar, sizeof(char), decompOut);
		}
		else{
			fwrite(&inputChar, 1, sizeof(char), decompOut);
		}
	}
	free(zeroBuf);
	return 0;
}
