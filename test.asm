%include "main.asm"
%include "asmunit.asm"

global test_start

section .data
hellotest db "TEST!"
htlen equ $ - hellotest

section .text
test_start:
        mov eax, SYS_WRITE
        mov ebx, STDOUT
        mov ecx, hellotest
        mov edx, htlen
        int 0x80
