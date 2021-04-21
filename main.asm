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

%assign SECOND 1_000_000_000
%assign WAIT_NANOSECONDS (SECOND / 10)

;****************************************************************************
;* game data
;****************************************************************************
section .data
	exiting dd 0
	positionx dd 10
	positiony dd 10
	lblpos db `\033[            `
	lblposlen equ $-lblpos
	clear db `\033[2J`
	clearlen equ $-clear
	direction db FLAG_DIR_STOPPED
	left dd 0
	right dd 0
	up dd 0
	down dd 0

	timeval:
		tv_sec  dd 0 
		tv_nsec dd 0 

section .bss
	character resb 4
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
	call hide_cursor

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

.move_up:
	mov dword [up], 1
	mov dword [down], 0
	mov dword [left], 0
	mov dword [right], 0
	ret

.move_down:
	mov dword [up], 0
	mov dword [down], 1
	mov dword [left], 0
	mov dword [right], 0
	ret

.move_left:
	mov dword [up], 0
	mov dword [down], 0
	mov dword [left], 2
	mov dword [right], 0
	ret

.move_right:
	mov dword [up], 0
	mov dword [down], 0
	mov dword [left], 0
	mov dword [right], 2
	ret

.readkey:
	mov	dword eax, SYS_READ
	mov	dword ebx, STDIN
	mov	dword ecx, character
	mov	dword edx, 4
	int	byte  0x80

	mov	dword ebx, [character]
	mov	byte bl, [character]

	cmp eax, 1
	jne .not_escape

	cmp	byte [character], `\033`
	je	near  exit_norestore

.not_escape:
	cmp	dword ebx, `\033[A` ; arrow up
	je .move_up
	
	cmp	byte  bl, 119 ; w
	je .move_up

	cmp	dword ebx, `\033[B` ; arrow down
	je .move_down

	cmp	byte  bl, 115 ; s
	je .move_down

	cmp	dword ebx, `\033[D` ; arrow left
	je .move_left

	cmp	byte  bl, 97 ; a
	je .move_left

	cmp	dword ebx, `\033[C` ; arrow right
	je .move_right

	cmp	byte  bl, 100 ; d
	je .move_right

	ret

.display:
	mov eax, [right]
	add [positionx], eax
	mov eax, [left]
	sub [positionx], eax
	mov eax, [down]
	add [positiony], eax
	mov eax, [up]
	sub dword [positiony], eax

	mov eax, [positiony]
	mov ebx, [positionx]
	mov dword ecx, '😃'
	call near printchar

	; Sleep
	mov dword [tv_sec], 0
	mov dword [tv_nsec], WAIT_NANOSECONDS
	mov eax, 162
	mov ebx, timeval
	mov ecx, 0
	int 0x80

	mov	eax, [exiting]
	cmp	eax, 1
	je	near  exit
	ret

;****************************************************************************
;* exit
;****************************************************************************
section .data
lbldone db "Done!"
lbldonelen equ $-lbldone

section .text
exit_norestore:
	mov dword [exiting], 1
	mov eax, 1
	int 0x80

exit:
	mov eax, 4
	mov ebx, 1
	mov ecx, lbldone
	mov edx, lbldonelen
	int 0x80

	call show_cursor

	call	near  rawkb_restore
	xor	dword eax, eax
	mov	dword ebx, eax
	inc	dword eax
	int	byte  0x80

;****************************************************************************
;* printchar
;****************************************************************************
section .data
tracker db 4

section .text
printchar:
	push ecx
	push ebx
	mov ebx, lblpos + 2
	mov [tracker], ebx
	call printnumber

	mov byte [edx], ';'
	inc edx

	pop eax
	mov [tracker], edx
	call printnumber

	mov byte [edx], 'f'

	pop ecx
	mov dword [edx + 1], ecx
	add edx, 5
	sub edx, lblpos

	mov eax, 4
	mov ebx, 1
	mov ecx, lblpos
	int 0x80

	ret

printnumber:
	mov ecx, 10         ; divisor
	xor bx, bx          ; count digits

	divide:
		xor edx, edx        ; high part = 0
		div ecx             ; eax = edx:eax/ecx, edx = remainder
		push dx             ; DL is a digit in range [0..9]
		inc bx              ; count digits
		test eax, eax       ; EAX is 0?
		jnz divide    ; no, continue

		; POP digits from stack in reverse order
		mov cx, bx          ; number of digits
		mov edx, [tracker]
	next_digit:
		pop ax
		add al, '0'         ; convert to ASCII
		mov [edx], al        ; write it to the buffer
		inc edx
		loop next_digit
	ret

;****************************************************************************
;* cursor
;****************************************************************************
section .data
command_hide_cursor db `\033[?25l`
command_hide_cursorlen equ $-command_hide_cursor

command_show_cursor db `\033[?25h`
command_show_cursorlen equ $-command_show_cursor

section .text
hide_cursor:
	mov eax, SYS_WRITE
	mov ebx, STDOUT
	mov ecx, command_hide_cursor
	mov edx, command_hide_cursorlen
	int 0x80
	ret

show_cursor:
	mov eax, SYS_WRITE
	mov ebx, STDOUT
	mov ecx, command_show_cursor
	mov edx, command_show_cursorlen
	int 0x80
	ret
