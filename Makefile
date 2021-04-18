NASM=nasm -w+orphan-labels -w+macro-params -w+number-overflow -f elf
STRIP=strip -R .note -R .comment
LD=ld -s
RM=rm -f

.PHONY: all clean test

all: snakeasm

snakeasm: main.asm
	${NASM} -o main.o main.asm
	${LD} -m elf_i386 -e snake_start -o snakeasm main.o
	${STRIP} snakeasm

test:
	${NASM} -o asmunit.o asmunit.asm
	${LD} -m elf_i386 -e _main -o test asmunit.o
	./test

clean:
	${RM} *.bak *~ snakeasm main.o core asmunit.o test
