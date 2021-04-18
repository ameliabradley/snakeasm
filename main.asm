global snake_start

%include "threads.asm"
%include "rawkb.asm"

;****************************************************************************
;* assigns
;****************************************************************************
%assign SYS_READ			3
%assign SYS_WRITE			4

%assign STDIN				0
%assign STDOUT				1

;****************************************************************************
;* data
;****************************************************************************
section .data
clear db `\033[2J`
clearlen equ $-clear
lblpos db `\033[000;000f    `
lblposlen equ $-lblpos
direction db FLAG_DIR_STOPPED
positionx db '000'
positiony db '000'
left db 0
right db 0
up db 0
down db 0

timeval:
	tv_sec  dd 0 
	tv_usec dd 0 

section .bss
hex_number:				resd	1
character:				resb	1
sz resb 4

;****************************************************************************
;* snake_start
;****************************************************************************
section .text
clearscreen:
	mov eax, SYS_WRITE
	mov ebx, STDOUT
	mov ecx, clear
	mov edx, clearlen
	int 0x80
	ret

snake_start:
	call setup_rawkb
	call clearscreen

	mov eax, SYS_IOCTL
	mov edi, STDOUT
	mov esi, 0x5413             ; TIOCGWINSZ
	mov edx, sz                 ; struct winsize sz
	int 0x80

	mov ebx, .displayloop
	call thread_create

.readloop:
	call .readkey
	jmp .readloop

.displayloop:
	call .display
	jmp .displayloop

.readkey:
	mov	dword eax, SYS_READ
	mov	dword ebx, STDIN
	mov	dword ecx, character
	mov	dword edx, 1
	int	byte  0x80

	mov	byte  bl, [character]

	cmp	byte  bl, 0x1B
	je	near  exit
	
	;test	byte  bl, 77 ; w
	;mov up, zf

	;test	byte  bl, 73 ; s
	;mov down, zf

	;test	byte  bl, 61 ; a
	;mov left, zf

	;test	byte  bl, 64 ; d
	;mov right, zf

	ret

.display:
	;add positionx, right
	;sub positionx, left
	;add positiony, down
	;sub positiony, up

	mov eax, SYS_WRITE
	mov ebx, STDOUT
	mov ecx, lblpos
	mov edx, lblposlen
	int 0x80

	; Sleep
	mov dword [tv_sec], 1
	mov dword [tv_usec], 0
	mov eax, 162
	mov ebx, timeval
	mov ecx, 0
	int 0x80

	xor	dword ebx, ebx
	xor	dword ecx, ecx
	mov	byte  bl, [character]
	mov	byte  cl, bl
	cmp	byte  bl, 0x1B
	je	near  exit
	shr	dword ecx, 4
	and	byte  bl, 0x0f
	mov	dword eax, 0x0a680000
	mov	byte  ah, [.hex_table + ebx]
	mov	byte  al, [.hex_table + ecx]
	mov	dword [hex_number], eax
	mov	dword eax, SYS_WRITE
	mov	dword ebx, STDOUT
	mov	dword ecx, hex_number
	mov	dword edx, 4
	int	byte  0x80
	ret

.hex_table:				db	"0123456789abcdef"

;****************************************************************************
;* exit
;****************************************************************************
section .text
exit:
	call	near  rawkb_restore
	xor	dword eax, eax
	mov	dword ebx, eax
	inc	dword eax
	int	byte  0x80
