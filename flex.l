%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "Bison.tab.h"

/* Location tracking */
extern int yylineno;
int yycolumn = 1;
void showERROR();

/* Update location for each token */
#define YY_USER_ACTION \
    yylloc.first_line = yylloc.last_line = yylineno; \
    yylloc.first_column = yycolumn; \
    yylloc.last_column = yycolumn + yyleng - 1; \
    yycolumn += yyleng;
%}

DIGIT     [0-9]
LETTER    [A-Za-z]
ID_START  [A-Z]
ID_CHAR   [A-Za-z0-9]
WS        [ \t\r]+
NL        \n

%%

{WS}                   {}
{NL}                   { yylineno++; yycolumn = 1; }

"BEGIN"                { return BEGIN_; }
"END"                  { return END_; }
"CONST"                { return CONST_; }
"IF"                   { return IF_; }
"ELSE"                 { return ELSE_; }
"FOR"                  { return FOR_; }


"INT"                  { yylval.ival = T_INT; return TYPE_; }
"FLOAT"                { yylval.ival = T_FLOAT; return TYPE_; }
"BOOL"                 { yylval.ival = T_BOOL; return TYPE_; }

{ID_START}([A-Za-z0-9_]*)  {
    /* Check for double underscore */
    if (strstr(yytext, "__") != NULL) {
        fprintf(stderr, "Lexical Error at line %d, column %d: identifier '%s' contains double underscore '__' (not allowed)\n", 
                yylineno, yycolumn - yyleng, yytext);
        /* Skip this token and continue */
    } else {
        yylval.str = strdup(yytext);
        return IDF;
    }
}
{DIGIT}+"."{DIGIT}+ {
    yylval.fval = atof(yytext);
    return FLOAT_CONST;
}

{DIGIT}+ {
    yylval.ival = atoi(yytext);
    return INT_CONST;
}
"="                    { return ASSIGN_CONST;}
":="                   { return ASSIGN; }
";"                    { return SC; }
","                    { return COMMA; }
"("                    { return LPAR; }
")"                    { return RPAR; }
"{"                    { return LBR; }
"}"                    { return RBR; }
"=="                   { yylval.op = EQ; return RELOP; }
"<>"                   { yylval.op = NE; return RELOP; }
"<="                   { yylval.op = LE; return RELOP; }
">="                   { yylval.op = GE; return RELOP; }
"<"                    { yylval.op = LT; return RELOP; }
">"                    { yylval.op = GT; return RELOP; }
"+"                    { return PLUS; }
"-"                    { return MINUS; }
"*"                    { return MUL; }
"/"                    { return DIV; }


\\([^\\\n]+)\\               { }


.                      { showERROR(); }

%%

void showERROR() {
    fprintf(stderr, "Lexical Error at line %d, column %d: '%s'\n", yylineno, yycolumn, yytext);
}

int yywrap() {
    return 1;
}
