# vNPU Parser Makefile
# For Plan9/Inferno C toolchain compatibility

CC = gcc
LEX = flex
YACC = bison
CFLAGS = -Wall -g

TARGET = vnpu_parser

SRCS = vnpu.tab.c lex.yy.c ast.c sema.c codegen.c

all: $(TARGET)

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) -o $@ $(SRCS)

vnpu.tab.c vnpu.tab.h: vnpu.y
	$(YACC) -d vnpu.y

lex.yy.c: vnpu.l vnpu.tab.h
	$(LEX) vnpu.l

clean:
	rm -f $(TARGET) vnpu.tab.c vnpu.tab.h lex.yy.c *.o vnpu_out.h

test: $(TARGET)
	./$(TARGET) < ../../examples/hello.vnpu

.PHONY: all clean test
