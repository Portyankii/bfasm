format ELF64 executable 3
segment readable executable
entry main
main:
    mov rdi, [rsp]      ; argc into rdi
    cmp rdi, 2          ; check if we have at least 2 args (program + filename)
    jl usage_error      ; jump if less than 2 arguments
    mov rsi, [rsp + 16] ; argv[1] - the filename
    ; Now open the file using rsi as filename
    mov rax, 2          ; sys_open
    mov rdi, rsi        ; filename from argv[1]
    mov rsi, 0          ; O_RDONLY
    mov rdx, 0          ; mode
    syscall
    cmp rax, 0
    js file_error       ; negative means error
    mov rbx, rax        ; save file descriptor
    ; Read from file
    mov rax, 0          ; sys_read
    mov rdi, rbx        ; file descriptor
    mov rsi, buffer     ; buffer
    mov rdx, 1024       ; bytes to read
    syscall
    mov rsi, tape       ; data pointer
    mov rdi, buffer     ; instruction pointer
interpret:
    mov al, byte [rdi]
    cmp al, '+'
    je increment
    cmp al, '-'
    je decrement
    cmp al, '>'
    je right
    cmp al, '<'
    je left
    cmp al, '.'
    je output
    cmp al, ','
    je input
    cmp al, '['
    je loop_start
    cmp al, ']'
    je loop_end
    cmp al, 0
    je exit
next:
    inc rdi
    jmp interpret
right:
    inc rsi
    jmp next
left:
    dec rsi
    jmp next
increment:
    inc byte [rsi]
    jmp next
decrement:
    dec byte [rsi]
    jmp next
output:
    push rdi
    push rsi
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, rsi        ; current cell (data pointer is in rsi)
    mov rdx, 1
    syscall
    pop rsi
    pop rdi
    jmp next
input:
    push rdi
    push rsi
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    mov rdx, 1
    syscall
    pop rsi
    pop rdi
    jmp next
loop_start:
    ; Check if current cell is zero
    cmp byte [rsi], 0
    je skip_loop        ; if zero, skip to matching ]
    jmp next            ; otherwise continue normally
skip_loop:
    ; Find matching ] bracket
    mov rcx, 1          ; bracket counter
    inc rdi             ; move past current [
skip_loop_search:
    mov al, byte [rdi]
    cmp al, 0           ; end of program
    je exit             ; error: unmatched [
    cmp al, '['
    je skip_loop_inc
    cmp al, ']'
    je skip_loop_dec
    inc rdi
    jmp skip_loop_search
skip_loop_inc:
    inc rcx
    inc rdi
    jmp skip_loop_search
skip_loop_dec:
    dec rcx
    cmp rcx, 0
    je next             ; found matching ], continue from next instruction
    inc rdi
    jmp skip_loop_search
loop_end:
    ; Check if current cell is non-zero
    cmp byte [rsi], 0
    jne jump_back       ; if non-zero, jump back to matching [
    jmp next            ; otherwise continue normally
jump_back:
    ; Find matching [ bracket
    mov rcx, 1          ; bracket counter
    dec rdi             ; move before current ]
jump_back_search:
    cmp rdi, buffer     ; check if we've gone before the start
    jl exit             ; error: unmatched ]
    mov al, byte [rdi]
    cmp al, ']'
    je jump_back_inc
    cmp al, '['
    je jump_back_dec
    dec rdi
    jmp jump_back_search
jump_back_inc:
    inc rcx
    dec rdi
    jmp jump_back_search
jump_back_dec:
    dec rcx
    cmp rcx, 0
    je next             ; found matching [, continue from next instruction
    dec rdi
    jmp jump_back_search
exit:
    ; Close file
    mov rax, 3          ; sys_close
    mov rdi, rbx
    syscall
    mov rax, 60         ; sys_exit
    xor rdi, rdi
    syscall
file_error:
    ; Handle file open error
    mov rax, 1          ; sys_write
    mov rdi, 2          ; stderr
    mov rsi, errormsg
    mov rdx, errormsglen
    syscall
    jmp exit
usage_error:
    ; Print usage message and exit
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, usagemsg
    mov rdx, usagelen
    syscall
    jmp exit
segment readable writeable
usagemsg db "Usage: bf <filename>", 10, 0
usagelen = $ - usagemsg
errormsg db "Error: Could not open file", 10, 0
errormsglen = $ - errormsg
tape rb 30000           ; increased tape size for typical brainfuck programs
buffer rb 2560000
