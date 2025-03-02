%{
#include "jc.tab.h"
#include <string.h>
#include <stdlib.h>
%}

%option noyywrap

%%
"program"           { return KWPROGRAM; }
"function"          { return KWFUNCTION; }
"call"              { return KWCALL; }
"{"                 { return LBRACE; }
"}"                 { return RBRACE; }
"("                 { return LPAREN; }
")"                 { return RPAREN; }
";"                 { return SEMICOLON; }
","                 { return COMMA; }
"\+"               { return PLUS; }
[0-9]+              { yylval.ival = strtol(yytext, NULL, 10); return NUMBER; }

\"[^\"]*\"         {
                      yylval.str = strdup(yytext);
                      return STRING;
                   }

[a-zA-Z_][a-zA-Z0-9_]* {
                      yylval.str = strdup(yytext);
                      return ID;
                   }

[ \t\n]+            { /* ignore whitespace */ }

.                   { /* ignore any other character */ }
%%
