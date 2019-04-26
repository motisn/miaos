[bits	16] ; Real mode
[org	0x8200] ; 0x8200 (readBuff address)

    mov al, 'A'
	mov	ah, 0x0e	; 1-char output
	mov	bx, 15	; Color code = white
	int	0x10	; Call bios interrupt; video

fin:
    hlt
    jmp     fin