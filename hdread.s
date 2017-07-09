section .text
org 0x100
		call	GET_DRV_DATA
		call    SER_INIT
		;mov		WORD[d_lba], 0x1f00
		;mov		ax, WORD[sect_cnt]
		;mov		ax, WORD[sect_cnt+2]
		;mov		ax, WORD[sect_cnt+4]
		;mov		ax, WORD[sect_cnt+6]
		mov		ax, 1
L_START:mov		cx, [blkcnt]
		;mov		si, d_lba
		;mov		di, sect_cnt
		call	CMP64
		;mov		[blkcnt], cx;this is done in cmp64 now....
		cmp		ax, 0
		je		L_END
		;push	ax
		call	READ_DISK_FUNC
		;Here we would do a disk read and print etc.(how big should this disk read be? -- i now think it should be blkcnt size and this is correct.)
        mov     ax, [d_lba]             ;Get the current d_lba just for debugging purposes
        mov     bx, [d_lba+2]
        mov     cx, [d_lba+4]
		mov     dx, [d_lba+6]

		mov		si, d_lba
		mov		cx, [blkcnt]
		call	INC64
		;pop		ax
		jmp		L_START
		
L_END:	mov     ax, 0x4c00	    ;terminate
        mov     al, 0			;return code
        int     0x21			;interrupt to DOS
        

;cx will have increment amount, si has base address to inc
INC64:  add     [si+0], cx           ;di register will contain amount to increment; this is a recursive call
        adc     WORD[si+2], 0
        adc     WORD[si+4], 0
        adc     WORD[si+6], 0
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

;di conatains the thing that should be larger, si contins that thing that should be smaller, cx contains the max possible value(generally 16), cx will be set to what we SHOULD inc by
;ax = 1 -> Good to continue, is at least;ax = 0 -> STOP
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
T64_LS: mov		ax, [d_lba_try+bx]
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
		
		
		
GET_DRV_DATA:                   ;di,si,dx,cx; ret=ax
        mov     ah,0x48
        mov     dl,0x80         ;the drive
        xor     di,di           ;prevents bios bugs acc. ctyme
        mov     si,DRVDAT       ;ds register will alreads contain the segment adress(i hope...)
        int     0x13

        ret
		
		
READ_DISK_FUNC:
        ;mov     bx,0xffff      ;TESTING
        mov     WORD [db_add], mem_p ;move the adress of mem_p into the db_add location
        mov     [db_add+2], ds  ;move the contents of the segment register into the appropriate location
        mov     dl, 0x80        ;0x80 is C drive, 0x81 is D drive

        mov     si, DAPACK      ;Pointer to drive data packet
        mov     ah, 0x42        ;extended HD Read
        int     0x13            ;HD interrupt

        mov     si,[blkcnt]     ;1 block is 512 bytes, first argument for PRINT_FUNC
        shl     si, 9           ;multiply by 512
        mov     di,mem_p        ;Pointer to empty memory in the call stack(or somewhere else)
        call    PRINT_FUNC

        ret
		
		
PRINT_FUNC:                     ;x86_64 calling convention di,si,dx,cx ret=ax. di<-point to what to data block. si<-#of values to read, 16 bit number.
        xor     bx,bx
PF_LP_START:
        cmp     si, bx          ;if the count equals the second argument loop complete
        je      PF_RET          ;jmp to return instruction

        mov     dx, 3fdh        ;Line status registed
PF_LP_TEST_REP:
        in      al, dx
        test    al,20h
        jz      PF_LP_TEST_REP
        mov     al, [di+bx]     ;Char to print in al
        mov     dx, 3f8h
        out     dx, al

PF_LP_NEXT:
        add     bx, 1
        jmp     PF_LP_START
PF_LP_FLAG:
        jmp     PF_LP_NEXT
PF_RET: ret                     ;return to the caller function

SER_INIT:
        mov     al, 83h
        mov     dx, 3fbh
        out     dx, al
        ;set latch and LCR params
        mov     dx, 3f9h
        mov     al, 0
        out     dx, al
        mov     dx, 3f8h
        mov     al, 01h
        out     dx, al
        ;disable latch, leave lcr params
        mov     al, 03h
        mov     dx, 3fbh
        out     dx, al
        ret
		
section .data
init_msg: db 'HDREAD3',13,10,'=======',13,10,'$'
msg2:   db "123456789"

DRVDAT: dw      0x1e            ;size of this buffer
        dw      0               ;information flags
cyl_cnt:dd      0               ;number of cylinders
head_cnt: dd    0               ;number of logical heads
sect_trk_cnt:dd 0               ;Sectors per track on the disk
sect_cnt: dw    0x0000           ;full sector count LSB first
          dw	0x0000
		  dw	0x0000
		  dw	0x0000			 ;MSB Last
byt_sect: dw    0               ;bytes per sector
edd_cofig: dd   0               ;enhanced config params

loc_sect_cnt:dd 0               ;analogour to the sect_cnt for locat incrementing
             dd 0

DAPACK: db      0x10
        db      0
blkcnt: dw      16              ;Has been set to one for a single 512b? block
db_add: dw      0x0             ;The memory read destination address
        dw      0x0             ;Upper word of memory read destination adress
d_lba:  dd      0x0             ;the block to read -- start at 0; 
        dd      0               ;4 more bytes for block to read -- according to wikipedia this is never used

d_lba_try:dd    0x0
          dd    0x0
section	.bss
mem_p:  resb    8192
