[bits	16] ; Real mode
[org	0x7c00]	; Tell nasm that the code is read into 0x7c00

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

entry:
; Init registors
	mov	ax, 0	; accumlator <- 0
	mov	ss, ax	; stack segment <- 0
	mov	sp, 0x7c00	; stack pointer <- 0x7c00
	mov	ds, ax	; data segment <- 0
	mov	es, ax	; extra segment <- 0

readFD:
	mov	ax, 0x0820	; Buffer = mem[es:bx = 0x8200 + bx]
	mov	es, ax		; /
	mov	ch, 0		; cylinder 0
	mov	dh, 0		; head 0
	mov	cl, 2		; sector 2 (sector 1 is filled by IPL)

	mov	si, 0		; Counter failure times
retry:
	mov	ah, 0x02	; read disk
	mov	al, 1		; read 1 sector
	mov	bx, 0		; set buffer address
	mov	dl, 0x00	; A-drive (A:)
	int	0x13		; Call bios interrupt; disk
	jnc	ok

	add	si, 1
	cmp	si, 5		; if si >= 5
	jae	error		; then jump

	mov	ah, 0	; Reset drive
	mov	dl, 0	; /
	int	0x13
	jmp	retry

ok:
	mov	al, 'O'
	call	putChar
	mov	al, 'K'
	call	putChar
	mov	al, 10	;'\n'=10=0x0a
	call	putChar	; /
	mov	al, 13	;'\r'=13=0x0d
	call	putChar ; /

	mov	si, 0
dispFD:
	mov	ax, 0x0820	; Buffer = mem[es:bx = 0x8200 + bx]
	mov	es, ax		; /
	mov	al, [es:si]

	call	putHex

	mov	al, ' '
	call	putChar
	add	si, 1
	cmp	si, 64
	jbe	dispFD

	mov	si, mssg
	call	putStr
	;jmp	fin
	jmp	0x8200

error:
	mov	si, emssg
	call	putStr

fin:
	hlt
	jmp	fin ; End of the program

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
	add	al, 7	; else +55 (al <- [a,e]) (+2)
	add	al, 48	; Translate binary to charactor
	call	putChar
	ret

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

emssg:
	db	"error"
	dw	0x0a0d
	db	0
mssg:
	db	"end"
	dw	0x0a0d
	db	0


; disk[510;511]: Boot signature
	times	510-($-$$) db 0
	dw	0xaa55
