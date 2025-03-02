%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex(void);
void yyerror(const char* s);

/* string table: store string constants for output later */
#define MAX_STRINGS 100
char *stringTable[MAX_STRINGS];
int stringCount = 0;

/* help fn to add string constant (strips quotes) */
int addString(char *s) {
    int len = strlen(s);
    if (len < 2) {
        fprintf(stderr, "error: string too short to strip quotes\n");
        exit(1);
    }
    char *stripped = (char *) malloc(len - 1); // Allocate enough space
    if (!stripped) {
        fprintf(stderr, "error: memory allocation failed\n");
        exit(1);
    }
    strncpy(stripped, s+1, len-2); // copy everything except first and last char
    stripped[len-2] = '\0'; // make sure it's null terminated
    
    if (stringCount >= MAX_STRINGS) {
        fprintf(stderr, "error: too many strings\n");
        free(stripped);
        exit(1);
    }
    
    stringTable[stringCount] = stripped;
    return stringCount++;
}

/* print data section w/ all string constants */
void printDataSection() {
    printf("#\n# data section\n#\n");
    printf("      .section    .rodata\n");
    for (int i = 0; i < stringCount; i++) {
         printf(".SC%d: .string    \"%s\"\n", i, stringTable[i]);
    }
    printf("\n");
}

/* print code prologue for main fn */
void printCodePrologue() {
    printf("#\n# code section\n#\n");
    printf("      .text\n");
    printf("      .globl    main\n");
    printf("main:\n");
    printf("      pushq    %%rbp\n");
    printf("      movq    %%rsp, %%rbp\n");
}

/* print code epilogue for main fn */
void printCodeEpilogue() {
    printf("      movl    $0, %%eax\n");
    printf("      leave\n");
    printf("      ret\n");
    printf("      .section    .note.GNU-stack,\"\",@progbits\n");
}

/* global structure for call args (max 6 allowed) */
typedef enum { ARG_STRING, ARG_NUMBER } ArgType;
typedef struct {
    ArgType type;
    int ival; /* for ARG_STRING: index in stringTable; for ARG_NUMBER: computed value */
} ArgInfo;

#define MAX_ARGS 6
ArgInfo callArgs[MAX_ARGS];
int callArgCount = 0;

%}

%expect 1

/* define semantic types */
%union { int ival; char* str; }

/* start symbol */
%start wholeprogram

/* nonterminals (produce code strings) */
%type <str> wholeprogram program functions function statements statement funcall
%type <str> arguments argument
%type <ival> expression

/* tokens */
%token <ival> KWPROGRAM KWCALL SEMICOLON LPAREN RPAREN LBRACE RBRACE NUMBER
%token <str> ID STRING
%token KWFUNCTION COMMA PLUS

%%

/* whole program: fn defs followed by main program */
wholeprogram:
    functions program {
      printDataSection();
      /* emit fn defs */
      printf("%s", $1);
      /* emit main fn code */
      printCodePrologue();
      printf("%s", $2);
      printCodeEpilogue();
    }
;

/* list of fn defs */
functions:
    function functions {
         int len = strlen($1) + strlen($2) + 1;
         $$ = (char *) malloc(len);
         strcpy($$, $1);
         strcat($$, $2);
    }
    | /* empty */ { $$ = strdup(""); }
;

/* fn def: no params, block of stmts */
function:
    KWFUNCTION ID LPAREN RPAREN LBRACE statements RBRACE {
         char buffer[1024];
         /* gen label for fn + handle params */
         sprintf(buffer, "%s:\n\tpushq\t%%rbp\n\tmovq\t%%rsp, %%rbp\n%s\tleave\n\tret\n", $2, $6);
         $$ = strdup(buffer);
    }
;

/* main program */
program:
    KWPROGRAM LBRACE statements RBRACE { $$ = $3; }
;

/* stmts: concat stmts */
statements:
    statement statements {
         int len = strlen($1) + strlen($2) + 1;
         $$ = (char *) malloc(len);
         strcpy($$, $1);
         strcat($$, $2);
    }
    | /* empty */ { $$ = strdup(""); }
;

/* stmt: currently only a fn call */
statement:
    funcall { $$ = $1; }
;

/* fn call:
   - reset global callArgs count,
   - record args in global array,
   - generate code that loads args into registers and calls the fn.
*/
funcall:
    KWCALL ID LPAREN { callArgCount = 0; } arguments RPAREN SEMICOLON {
         char codeBuffer[512];
         codeBuffer[0] = '\0';
         const char *regs[] = {"%rdi", "%rsi", "%rdx", "%rcx", "%r8", "%r9"};
         for (int i = 0; i < callArgCount; i++) {
             if (i >= MAX_ARGS) {
                 fprintf(stderr, "too many args (more than 6) not supported.\n");
                 exit(1);
             }
             char temp[128];
             if (callArgs[i].type == ARG_STRING) {
                 sprintf(temp, "\tleaq\t.SC%d(%%rip), %s\n", callArgs[i].ival, regs[i]);
             } else if (callArgs[i].type == ARG_NUMBER) {
                 sprintf(temp, "\tmovq\t$%d, %s\n", callArgs[i].ival, regs[i]);
             }
             strcat(codeBuffer, temp);
         }
         char callInstr[128];
         sprintf(callInstr, "\tcall\t%s@PLT\n", $2);
         strcat(codeBuffer, callInstr);
         $$ = strdup(codeBuffer);
    }
;

/* args list: empty or comma-sep list; no code generated here */
arguments:
    /* empty */ { $$ = strdup(""); }
    | argument { $$ = strdup(""); }
    | argument COMMA arguments { $$ = strdup(""); }
;

/* arg: either string literal or simple expr */
argument:
    STRING {
         int sid = addString($1);
         if (callArgCount >= MAX_ARGS) {
             fprintf(stderr, "too many args\n");
             exit(1);
         }
         callArgs[callArgCount].type = ARG_STRING;
         callArgs[callArgCount].ival = sid;
         callArgCount++;
         $$ = strdup("");
    }
    | expression {
         if (callArgCount >= MAX_ARGS) {
             fprintf(stderr, "too many args\n");
             exit(1);
         }
         callArgs[callArgCount].type = ARG_NUMBER;
         callArgs[callArgCount].ival = $1;
         callArgCount++;
         $$ = strdup("");
    }
;

/* simple expr: a number or plus expr */
expression:
    NUMBER { $$ = $1; }
    | expression PLUS expression { $$ = $1 + $3; }
;

%%

int main(int argc, char **argv) {
    extern FILE *yyin;
    if (argc > 2) {
        fprintf(stderr, "usage: %s [filename]\n", argv[0]);
        return 1;
    }
    if (argc == 2) {
        FILE *file = fopen(argv[1], "r");
        if (!file) {
            perror("fopen");
            return 1;
        }
        yyin = file;
    }
    yyparse();
    return 0;
}

void yyerror(const char *s) {
    fprintf(stderr, "parse error: %s\n", s);
}
