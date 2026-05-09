# vNPU Parser Makefile
# For Plan9/Inferno C toolchain compatibility

CC     = gcc
LEX    = flex
YACC   = bison
CFLAGS = -Wall -g

TARGET = vnpu_parser

SRCS = vnpu.tab.c lex.yy.c ast.c sema.c codegen.c

# Resolve absolute path to repo root so sub-targets work from any cwd
REPO_ROOT := $(abspath ../..)

.PHONY: all build clean test e2e grammar-check

all: build

build: $(TARGET)

$(TARGET): $(SRCS)
	$(CC) $(CFLAGS) -o $@ $(SRCS)

vnpu.tab.c vnpu.tab.h: vnpu.y
	$(YACC) -d vnpu.y

lex.yy.c: vnpu.l vnpu.tab.h
	$(LEX) vnpu.l

clean:
	rm -f $(TARGET) vnpu.tab.c vnpu.tab.h lex.yy.c *.o vnpu_out.h

# Quick smoke-test: parse the canonical hello example
test: build
	./$(TARGET) < ../../examples/hello.vnpu

# Full fixture-based end-to-end test suite
e2e: build
	@cd $(REPO_ROOT) && bash tests/run_e2e.sh $(REPO_ROOT)/src/parser/$(TARGET)

# Verify ANTLR grammar and lex/yacc parser stay in sync
grammar-check:
	@cd $(REPO_ROOT) && bash tests/run_grammar_check.sh

# Validate every example in examples/ compiles without error
validate-examples: build
	@cd $(REPO_ROOT) && bash tests/validate_examples.sh $(REPO_ROOT)/src/parser/$(TARGET)

# Regenerate golden files from current compiler output
update-goldens: build
	@cd $(REPO_ROOT) && bash tests/update_goldens.sh $(REPO_ROOT)/src/parser/$(TARGET)
