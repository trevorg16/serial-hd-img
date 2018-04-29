section .text
org 0x100

;;;;;;;;;;;;
;;This can be assembled with NASM:
;;nasm -f bin cserhd.s -o cserhd.com
;;;;;;;;;;;;

		mov		dx,start_msg
		mov		ah,0x09
		int		0x21
		call	GET_DRV_DATA
		call	SER_INIT
		mov		ax, 0xffff
		call	DUMP_STATUS
L_START:mov		cx, [blkcnt]
		call	CMP64
		cmp		ax, 0
		je		L_END
		call	READ_DISK_FUNC

		mov		si, d_lba
		mov		cx, [blkcnt]
		call	INC64
		mov		ah, 0x01
		int		0x16			;Check for keystroke
		jne		L_CHK_KEY		;if any key is hit, jump to L_CHK_KEY. ax register will be non-zero due to keystroke
		jmp		L_START
L_END:	call	DUMP_STATUS		;ax must be 0 due to cmp
		mov		ax, 0x4c00		;terminate 4c, return code 00
		int		0x21			;interrupt to DOS, terminate


L_CHK_KEY:
		mov		ah, 0x00
		int		0x16
		cmp 	al, 0x61
		jne		J_I_KEY
		jmp		L_END
J_I_KEY:pusha
		mov		ax, 0xffff
		call	DUMP_STATUS
		popa
		jmp		L_START



DUMP_STATUS:
		mov 	dx, fin_msg
		cmp		ax, 0
		je		DUMP_STATUS_FIN
		mov		dx, info_msg
		cmp		ax, 0xffff
		je		DUMP_STATUS_FIN
		mov		dx, stop_msg
DUMP_STATUS_FIN:
		mov		al, 0
		mov		ah, 0x09
		int		0x21
		call	PRINT_STATS
		ret


;cx will have increment amount, si has base address to inc
INC64:	add		[si+0], cx			 ;di register will contain amount to increment; this is a recursive call
		adc		WORD[si+2], 0
		adc		WORD[si+4], 0
		adc		WORD[si+6], 0
		ret


CP64:	mov		dx, [d_lba]
		mov		[d_lba_try], dx
		mov		dx, [d_lba+2]
		mov		[d_lba_try+2], dx
		mov		dx, [d_lba+4]
		mov		[d_lba_try+4], dx
		mov		dx, [d_lba+6]
		mov		[d_lba_try+6], dx
		ret

;di conatains the thing that should be larger, si contins that thing that should be smaller, cx contains the max possible value(generally 16, blkcnt), cx will be set to what we SHOULD inc by
;ax = 1 -> Good to continue, is at least blkcnt left;ax = 0 -> STOP
;PURPOSE: This function provides the high level imp of looping through all of the values of blkcnt if needed until one is fopund for which a sufficieve
CMP64:	call	TEST64
		cmp		ax, 1
		je		CMP64_END
		dec		cx
		cmp		cx, 0
		je		CMP64_FAIL
		jmp		CMP64
CMP64_FAIL:
		mov		ax, 0
CMP64_END:
		mov		[blkcnt], cx
		ret

;return 1 iff sufficiently less(cx less)
;cx has CMP64
;This function is what uses the _try addr
TEST64:	call	CP64
		mov		si, d_lba_try
		call	INC64
		mov		bx, 6
T64_LS:	mov		ax, [d_lba_try+bx]
		cmp		ax, [sect_cnt+bx]
		jne		T64_SUCCESS
		cmp		bx,2
		je		T64_LAST
		sub		bx, 2
		jmp		T64_LS
T64_LAST:mov	ax, [sect_cnt]
		sub		ax, [d_lba_try]
		cmp		ax, 0
		jl		T64_FAIL
		;else it is success, continue onwards
T64_SUCCESS:
		mov		ax, 1
		ret
T64_FAIL:
		mov		ax, 0
		ret



GET_DRV_DATA:					;di,si,dx,cx; ret=ax
		mov		ah,0x48
		mov		dl,0x80			;the drive
		xor		di,di			;prevents bios bugs acc. ctyme
		mov		si,DRVDAT		;ds register will alreads contain the segment adress(i hope...)
		int		0x13

		ret
		
		
READ_DISK_FUNC:
		mov		WORD [db_add], mem_p ;move the adress of mem_p into the db_add location
		mov		[db_add+2], ds	;move the contents of the segment register into the appropriate location
		mov		dl, 0x80		;0x80 is C drive, 0x81 is D drive

		mov		si, DAPACK		;Pointer to drive data packet
		mov		ah, 0x42		;extended HD Read
		int		0x13			;HD interrupt

		mov		si,[blkcnt]		;1 block is 512 bytes, first argument for WRITE_FUNC
		shl		si, 9			;multiply by 512
		mov		di,mem_p		;Pointer to empty memory in the call stack(or somewhere else)
		call	WRITE_FUNC

		ret


WRITE_FUNC:						;x86_64 calling convention di,si,dx,cx ret=ax. di<-point to what to data block. si<-#of values to read, 16 bit number.
		xor		ah,ah			;ah register contains number of 0's repeated
		xor		bx,bx
WF_LP_START:
		cmp		si, bx			;if the count equals the second argument loop complete
		je		WF_END			;jmp to return instruction<- Need to dump if val in ah
		mov		ch, [di+bx]
		cmp		ch, 0
		je		WF_LP_INC_ZERO_START
		cmp		ah, 0			;If there is not a zero stored in ah (zero count) dump the current byte
		je		WF_LP_WRITE_DATA
		call	W_DUMP_ZERO
WF_LP_WRITE_DATA:
		mov		dx, 3fdh		;Line status register
WF_LP_WRITE_DATA_T1:
		in		al, dx
		test	al, 20h
		jz		WF_LP_WRITE_DATA_T1
		mov		al, ch			;Char to print in al
		mov		dx, 3f8h
		out		dx, al
WF_LP_NEXT:
		inc		bx
		jmp		WF_LP_START
WF_END:
		cmp		ah, 0
		je		WF_END_RET
		call	W_DUMP_ZERO
WF_END_RET:
		ret
		
		
WF_LP_INC_ZERO_START:
		cmp		ah, 255
		jne		WF_LP_INC_ZERO
		call	W_DUMP_ZERO
WF_LP_INC_ZERO:
		inc		ah
		jmp		WF_LP_NEXT
		

W_DUMP_ZERO:
		mov		dx, 3fdh
W_DUMP_ZERO_T1:
		in		al, dx
		test	al, 20h
		jz		W_DUMP_ZERO_T1
		mov		al, 0
		mov		dx, 3f8h
		out		dx, al
		mov		dx, 3fdh
W_DUMP_ZERO_T2:
		in		al, dx
		test	al, 20h
		jz		W_DUMP_ZERO_T2
		mov		al, ah
		mov		dx, 3f8h
		out		dx, al
		xor		ah, ah
		ret
		

PRINT_STATS:
		mov		dx, string_blkcnt
		mov		ah, 0x09
		int		0x21
		mov		di, blkcnt
		mov		si, 2
		call	RECURSIVE_HEXIFY
		mov		dx, newline
		mov		ah, 0x09
		int		0x21
		
		mov		dx, string_d_lba
		mov		ah, 0x09
		int		0x21
		mov		di, d_lba
		mov		si, 8
		call	RECURSIVE_HEXIFY
		mov		dx, newline
		mov		ah, 0x09
		int		0x21
		
		mov		dx, string_sect_cnt
		mov		ah, 0x09
		int		0x21
		mov		di, sect_cnt
		mov		si, 8
		call	RECURSIVE_HEXIFY
		mov		dx, newline
		mov		ah, 0x09
		int		0x21
		ret
		

; di contains pointer to byte to write, si contains number of bytes to write
RECURSIVE_HEXIFY:
		mov		bx, si
		add		bx, di
		dec 	bx
		mov		al, [bx]
		push	ax
		mov		dl, 0xf0
		and 	dl, al
		shr		dl, 4
		cmp		dl, 0x0a
		jge		R_HEX_LTR_1
		add		dl, 0x30
		jmp		R_HEX_PRINT_1
R_HEX_LTR_1:
		add		dl, 0x37
R_HEX_PRINT_1:
		mov		ah, 0x02
		int		0x21

		pop		ax
		mov		dl, 0x0f
		and		dl, al
		cmp		dl, 0x0a
		jge		R_HEX_LTR_2
		add		dl, 0x30
		jmp		R_HEX_PRINT_2
R_HEX_LTR_2:
		add		dl, 0x37
R_HEX_PRINT_2:
		mov		ah, 0x02
		int		0x21
		
		cmp		si, 1
		jle		R_HEX_RET
		dec		si
		; Print a space
		mov		dl, 0x20
		mov		ah, 0x02
		int		0x21
		; Setup to call again
		call	RECURSIVE_HEXIFY
R_HEX_RET:
		ret


SER_INIT:
		mov		al, 83h
		mov		dx, 3fbh
		out		dx, al
		;set latch and LCR params
		mov		dx, 3f9h
		mov		al, 0
		out		dx, al
		mov		dx, 3f8h
		mov		al, 01h
		out		dx, al
		;disable latch, leave lcr params
		mov		al, 03h
		mov		dx, 3fbh
		out		dx, al
		ret
		
section .data
fin_msg:  db 'cserhd complete',13,10,'$'
stop_msg: db 'cserhd HALTED',13,10,'$'
info_msg: db 'cserhd info:',
newline:  db 13,10,'$'
start_msg:db 'Welcome to cserhd',13,10,'=================',13,10,'Press "a" to abort, any other key to print info',13,10,13,10,'$'
string_blkcnt:  db 'blkcnt:  $'
string_d_lba:	db 'd_lba:   $'
string_sect_cnt:db 'sect_cnt:$'


DRVDAT: dw		0x1e			;size of this buffer
		dw		0				;information flags
cyl_cnt:dd		0				;number of cylinders
head_cnt: dd	0				;number of logical heads
sect_trk_cnt:dd 0				;Sectors per track on the disk
sect_cnt: dw	0x0000			 ;full sector count LSB first
		  dw	0x0000
		  dw	0x0000
		  dw	0x0000			 ;MSB Last
byt_sect: dw	0				;bytes per sector
edd_cofig: dd	0				;enhanced config params

DAPACK: db		0x10
		db		0
blkcnt: dw		16				;Reads 16 512B sectors
db_add: dw		0x0				;The memory read destination address
		dw		0x0				;Upper word of memory read destination adress
d_lba:	dd		0x0				;the block to read -- start at 0; 
		dd		0				;4 more bytes for block to read -- according to wikipedia this is never used

d_lba_try:dd	0x0
		  dd	0x0
section	.bss
mem_p:	resb	8192
