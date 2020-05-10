[bits	16] ; Real mode
[org	0x7c00]	; Tell nasm that the code is read into 0x7c00

;-----------------------------------------------;
; MI NE UZAS TION SEKTOROJN POR FACILO
; FAT12 boot sector
; FD has 1440 KB
; FAT12 is for CountofClusters < 4086

; FATStartSector = 1
; = BPB_RsvdSecCnt
; FATSectors = 9 * 2 = 18
; = BPB_FATSz * BPB_NumFATS
; RootDirStartSector = 1 + 18 = 19
; = FatStartSector + FatSectors
; RootDirSectors = (32 * 224 + 512 - 1) / 512 = 14.998...
; = (32 * BPB_RootEntCnt + BPB_BytsPerSec - 1) / BPB_BytsPerSec
; DataStartSector = 19 + 14 = 33
; = RootDirStartSector + RootDirSectors
; DataSectors = 2880 - 33 = 2847
; = BPB_TotSec - DataStartSector
; CountofClusters = 2847 / 1 = 2847 < 4086
; = DataSectors / BPB_SecPerClus

;	JMP	entry			; BS_Jmpboot
;	DB	0x90			; /
;	DB	"MIAOS^8^"		; BS_OEMName (+8)
;	DW	512				; BPB_BytsPerSec
;	DB	1				; BPB_SecPerClus
;	DW	1				; BPB_RsvdSecCnt
;	DB	2				; BPB_NumFATS
;	DW	224				; BPB_RootEntCnt
;	DW	2880			; BPB_TotSec16
;	DB	0xf0			; BPB_Media
;	DW	9				; BPB_FATSz16
;	DW	18				; BPB_SecPerTrk
;	DW	2				; BPB_NumHeads
;	DD	0				; BPB_HiddSec
;	DD	0				; BPB_TotSec32
;; For FAT12/16
;	DB	0x00			; BS_DrvNum
;	DB	0				; BS_Reserved1
;	DB	0x29			; BS_BootSig
;
;	DD	0xffffffff		; BS_VolID
;	DB	"MIA_PLEJETA"	; BS_VolLab (+11)
;	DB	"FAT12   "		; BS_FilSysType (+8)
;	TIMES	18 DB 0			; 

;-----------------------------------------------;
entry:
; Init registors
	mov	ax, 0	; accumlator <- 0
	mov	ss, ax	; stack segment <- 0
	mov	sp, 0x7c00	; stack pointer <- 0x7c00
	mov	ds, ax	; data segment <- 0
	mov	es, ax	; extra segment <- 0

; Read FD
; Sector[0-18] -> Back side -> Next cylinder -> ...
	CYLS	equ 10	; number of read cylinder

	mov	ax, 0x0820	; Buffer = mem[es:bx = 0x8200 + bx]
	mov	es, ax		; /
	mov	ch, 0		; cylinder 0
	mov	dh, 0		; head 0
	mov	cl, 2		; sector 2 (sector 1 is filled at 0x7c00~0x7cff by IPL)

readFDSector:
	mov	si, 0		; Counter failure times
retry:
	mov	ah, 0x02	; read disk
	mov	al, 1		; read 1 sector
	mov	bx, 0		; set buffer address
	mov	dl, 0x00	; A-drive (A:)
	int	0x13		; Call bios interrupt; disk
	jnc	next

	add	si, 1
	cmp	si, 5		; Retry 5 times
	jb	$+8			; if under 5, continue (+2)
	mov	si, _error_	; Disp error (+2)
	call	putStr	; / (+2)
	jmp		fin		; / (+2)

	mov	ah, 0	; Reset drive
	mov	dl, 0	; /
	int	0x13
	jmp	retry

next:
	mov	ax, es		; Increment address; es <- es + 0x20
	add	ax, 0x20	; /
	mov	es, ax		; /
	add	cl, 1		; Read next sector
	cmp	cl, 18		; Sector number <= 18
	jbe	readFDSector

	mov	cl, 1		; Read by head 1 (bask side)
	add	dh, 1
	cmp	dh, 2
	jb	readFDSector

	mov	dh, 0		; Read next cylinder
	add	ch, 1
	cmp	ch, CYLS
	jb	readFDSector

ok:
	mov	al, 'O'
	call	putChar
	mov	al, 'K'
	call	putChar
	mov	al, 10	;'\n'=10=0x0a
	call	putChar	; /
	mov	al, 13	;'\r'=13=0x0d
	call	putChar ; /

loop:
	mov	si, menulist
	call	putStr
	call	getChar
	push	ax
	mov	si, _ret_
	call	putStr
	pop	ax

	cmp	al, 'q'
	je	endloop	; break

	cmp	al, '!'
	je	0x8200	; To main bootloader

	; Memory dump
	cmp	al, 'm'
	jne	loop
	; 1st argument
	mov	si, fromAddr
	call	putStr
	call	getHex
	push	ax
	mov	si, _ret_
	call	putStr
	; 2nd argument
	mov	si, toAddr
	call	putStr
	call	getHex
	push	ax
	mov	si, _ret_
	call	putStr
	; Set args and call
	pop	cx
	pop	ax
	call	dispMem

	; Otherwise, continue loop
	jmp	loop
endloop:
	mov	si, _end_
		call	putStr

fin:
	hlt
	jmp	fin ; End of the program

dispMem:
	mov	si, 0
	mov	es, ax
_dispMem:
	;mov	ax, 0x0820	; Buffer = mem[es:bx = 0x8200 + bx]
	;mov	es, ax		; /
	mov	al, [es:si]

	call	putHex

	mov	al, ' '
	call	putChar
	add	si, 1
	cmp	si, cx
	jb	_dispMem

	mov	si, _end_
	call	putStr
	ret

putHex:
	mov	dl, al
	shr	al, 4		;High-4bits
	and	al, 0x0f	; /
	cmp	al, 9	; if al <- [0,9] (al <= 9)
	jbe	$+4	; then +48 (+2)
	add	al, 7	; else +55 (al <- [a,e]) (+2)
	add	al, 48	; Translate binary to charactor
	call	putChar
	mov	al, dl
	and	al, 0x0f	; Low-4bits
	cmp	al, 9	; if al <- [0,9] (al <= 9)
	jbe	$+4	; then +48 (+2)
	add	al, 7	; else +55 (al <- [A,F]) (+2)
	add	al, 48	; Translate binary to charactor
	call	putChar
	ret

getHex:
; < 0xffff
	mov	si, 0
getHex0:
	call	getChar
	cmp	al, 0x0a
	je	getHex0_end
	cmp	al, 0x0d
	je	getHex0_end

	cmp	al, '9'	; if al <= '9'
	jbe	$+10	; then -48 (+2)
	cmp	al, 'F'	; if al <= 'F' (+2)
	jbe	$+4	; then -48 (+2)
	sub	al, 32	; else -87 (al <- ['a','f']) (+2)
	sub	al, 7	; else -55 (al <- ['A','F']) (+2)
	sub	al, 48	; Translate charactor to integer

	mov	ah, 0
	push	ax
	add	si, 1
	jmp	getHex0
getHex0_end:

	mov	ax, 0
	mov	di, 0
getHex1:
	pop	dx

	mov	cx, 0
getHex2:
	cmp	cx, di	; if cx >= di
	jae	$+9		; then (+2)
	sal dx, 4	; dx * 0x10 (+3)
	add	cx, 1	; (+2)
	jmp	getHex2	; (+2)

	add	ax, dx
	add	di, 1
	cmp	di, si	; if di >= si
	jae	$+4		; then return (+2)
	jmp	getHex1	; (+2)
	ret

;-----------------------------------------------;
; Functions using BIOS
putStr:
	mov	al, [si]	; Set charactor
	cmp	al, 0	; if al != 0 (end of message)
	jne	$+1	; then put charactor (+2)
	ret		; else return (+1)
	call	putChar
	add	si, 1	; Forward pointer
	jmp	putStr
putChar:
	mov	ah, 0x0e	; 1-char output
	mov	bx, 15	; Color code = white
	int	0x10	; Call bios interrupt; video
	ret

getChar:
	mov	ah, 0x00	; Read Keyboard Input
	int	0x16		; Call bios interrupt; keyboard
	call putChar
	ret

;-----------------------------------------------;
; Constant text
_ret_:
	dw	0x0a0d
	db	0
_error_:
	db	"error"
	dw	0x0a0d
	db	0
_end_:
	db	"end"
	dw	0x0a0d
	db	0
menulist:
	db	"q: Quit"
	dw	0x0a0d
	db	"!: Boot OS"
	dw	0x0a0d
	db	"m: Memory dump"
	dw	0x0a0d
	db	"> "
	db	0
fromAddr:
	db	"from? > 16 * 0x"
	db	0
toAddr:
	db	"to? > + 0x"
	db	0


; disk[510;511]: Boot signature
	times	510-($-$$) db 0
	dw	0xaa55
