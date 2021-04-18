; minimal asmUnit (xUnit) for NASM
; --------------------------------
; Copyright (c) 2015, Peter Kofler, licensed under BSD License.

; What would a unit testing framework need?
; * assert macros (which abort current test)
;   - DONE, just clear stack & return
; * before/after hooks for each test case
;   - DONE, with startTest and endTest Macros
; * test public APIs
;   - NOP, only test against exported symbols
; * stub system calls
;   - SUT needs to be designed like that
; * test cases and names
;   - DONE, easy with labels
; * run all test cases in test, auto discover (optional)

bits 32
register_size equ 4

        section .text

; --------------------------------------------------------------------------------
; call convention
; *stdcall* call convention (parameters pushed in right-to-left order, callee clean-up)
; used in Microsoft Win32 API
; see https://en.wikipedia.org/wiki/X86_calling_conventions#stdcall

; begin method, create stack frame and space for local variables
%macro create_local_variables 1         ; number of local variables
        push    ebp
        mov     ebp, esp
        sub     esp, %1 * register_size
%endmacro

; end method, drop paremeters from stack before returning
%macro ret_and_remove_params 1          ; number of parameters to remove
        leave
        ret     %1 * register_size
%endmacro

; --------------------------------------------------------------------------------
; logging/output

        extern  _GetStdHandle@4
        extern  _WriteFile@20

STD_OUTPUT_HANDLE equ -11
%define NULL    dword 0

; void print(*String message, int messageLength)
_print:
.p_message      equ 4 + 1 * register_size
.p_messageLen   equ 4 + 2 * register_size

        create_local_variables 1
.l_bytesWritten equ -1 * register_size

        ; get handle for stdout
        ;push    STD_OUTPUT_HANDLE
        ;call    _GetStdHandle@4
        ;mov     ebx, eax

        ; write message to StdOut
        ;push    NULL                    ; 0
        ;lea     eax, [ebp + .l_bytesWritten]
        ;push    eax                     ; &bytesWritten
        ;mov     eax, [ebp + .p_messageLen]
        ;push    eax                     ; length(message)
        ;mov     eax, [ebp + .p_message]
        ;push    eax                     ; &message
        ;push    ebx                     ; hstdOut
        ;call    _WriteFile@20

	mov eax, 4
	mov ebx, 1
	mov ecx, [ebp + .p_message]
	mov edx, [ebp + .p_messageLen]
	int 0x80

        ret_and_remove_params 2

; void println()
_println:
        push    cr_len
        push    cr
        call    _print
        ret

cr:     db      13, 10                  ; Windows \n\r
cr_len  equ     $ - cr

; void log(*String message, int messageLength)
_log:
.p_message      equ 4 + 1 * register_size
.p_messageLen   equ 4 + 2 * register_size
        create_local_variables 0

        mov     eax, [ebp + .p_messageLen]
        push    eax
        mov     eax, [ebp + .p_message]
        push    eax
        call    _print

        call    _println

        ret_and_remove_params 2

; log shortcut
%macro log 2                            ; message and length
        push    %2
        push    %1
        call    _log
%endmacro

; show a dot without newline to indicate progress
; void print('.')
_show_progress:
        push    eax             ; conserve ALL registers
        push    ebx
        push    ecx             ; maybe used by _WriteFile@20
        push    edx

        push    dot_len
        mov     eax, dot
        push    eax
        call    _print

        pop     edx
        pop     ecx
        pop     ebx
        pop     eax

        ret

dot:    db      '.'
dot_len equ     1

; --------------------------------------------------------------------------------
; assertions

; fail a test and stop executing it
%macro fail 0
        log msg_failed, msg_failed_len

        ; skip further test method execution, return immediately
        end_test
%endmacro

        ; TODO could use ANSI color codes for failed
msg_failed:     db 'FAILED'
msg_failed_len  equ $ - msg_failed

; assert equality
%macro assert_equals 2                  ; expected, actual
        cmp     %1, %2
        je      %%_end
        fail
%%_end:
        call    _show_progress
%endmacro

; --------------------------------------------------------------------------------
; life cycle and test methods

; start the before method
%macro before 0-1 0                     ; optional number of locals (else 0)
        %ifdef ctx_before
                %error "before used more than once"
        %endif

        %define ctx_before, 1
_before_hook:
        create_local_variables %1
%endmacro

%macro after 0-1 0                      ; optional number of locals (else 0)
        %ifdef ctx_after
                %error "after used more than once"
        %endif

        %define ctx_after, 1
_after_hook:
        create_local_variables %1
%endmacro

%macro end 0
        ret_and_remove_params 0
%endmacro

%macro begin_test 0-1 0                 ; optional number of locals (else 0)
        create_local_variables %1
        %ifdef ctx_before
                call _before_hook
        %endif
%endmacro

%macro end_test 0
        %ifdef ctx_after
                call _after_hook
        %endif
        end
%endmacro

; --------------------------------------------------------------------------------
; demo tests for testing the framework

_before_each_test_initialize_sut:
        before

        nop

        end

_after_each_test_clean_up:
        after

        nop

        end

_happy_path_should_add_one_and_one_to_two:
        begin_test

        mov     eax, 1
        add     eax, 1
        assert_equals eax, 2            ; success, print a dot

        end_test

_fails_and_skips_should_add_one_and_one_to_two:
        begin_test

        mov     eax, 1
        add     eax, 2
        assert_equals eax, 2            ; fails, print FAILED

        ; should not reach
        log     skip_nok, skip_nok_len

        end_test

skip_nok:      db  'asmUnit failure: Did not leave test method on test failure'
skip_nok_len   equ $ - skip_nok

; --------------------------------------------------------------------------------
; test runner

; void exit()
_exit:
        ; TODO set error code != 0 if tests failed

        ; void ExitProcess(UINT uExitCode)
	mov eax, 0
	int 0x80

        ; never here
        hlt

; --------------------------------------------------------------------------------
        global  _main

        section .bss

stackp: resd    1

        section .text

_main:
        mov     [stackp], esp

        ; show welcome message
        log     msg_hello, msg_hello_end - msg_hello

        ; run tests, shows .,
        call    _happy_path_should_add_one_and_one_to_two
        call    _fails_and_skips_should_add_one_and_one_to_two

.done:
        ; show complete message
        log     msg_done, msg_done_end - msg_done

        ; development stack corruption check
        cmp     [stackp], esp
        jne     .stack_is_different
        jmp     .exit

.stack_is_different:
        log     stack_diff, stack_diff_len

.exit:
        jmp     _exit

msg_hello:      db 'HELLO asmUnit'
msg_hello_end:

msg_done:       db 'DONE'
msg_done_end:

stack_diff:     db  'asmUnit failure: Stack size inconsistant at end'
stack_diff_len  equ $-stack_diff

; used time
; flight  2h
; cleanup 0.5h
; before/after 1h
