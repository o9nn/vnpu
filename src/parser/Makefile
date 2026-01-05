# vNPU Parser Makefile
# For Plan9/Inferno C toolchain compatibility

CC = gcc
LEX = flex
YACC = bison
CFLAGS = -Wall -g

TARGET = vnpu_parser

all: $(TARGET)

$(TARGET): vnpu.tab.c lex.yy.c
	$(CC) $(CFLAGS) -o $@ vnpu.tab.c lex.yy.c 

vnpu.tab.c vnpu.tab.h: vnpu.y
	$(YACC) -d vnpu.y

lex.yy.c: vnpu.l vnpu.tab.h
	$(LEX) vnpu.l

clean:
	rm -f $(TARGET) vnpu.tab.c vnpu.tab.h lex.yy.c

test: $(TARGET)
	./$(TARGET) < ../../examples/hello.vnpu

.PHONY: all clean test
