# Makefile for J compiler

CC = gcc
CFLAGS = -Wall -g
LEX = flex
YACC = bison -d -v

all: jc

jc: jc.o lex.yy.o
	$(CC) $(CFLAGS) -o jc jc.o lex.yy.o

jc.o: jc.y
	$(YACC) jc.y
	$(CC) $(CFLAGS) -c jc.tab.c -o jc.o

lex.yy.o: jc.l jc.tab.h
	$(LEX) jc.l
	$(CC) $(CFLAGS) -c lex.yy.c -o lex.yy.o

clean:
	rm -f jc jc.o lex.yy.o jc.tab.c jc.tab.h lex.yy.c jc.output

test: jc
	./jc hello.j > hello.s
	$(CC) $(CFLAGS) -o hello hello.s
	./hello
