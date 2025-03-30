%option noyywrap
%option yylineno

%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cerrno>
#include "parser.hpp"

int yylex();
%}


%%
[ \t\n]  ;
#.*\n ;
[[:digit:]]+ {
    errno = 0;
    char* _;
    long long val = strtoll(yytext, &_, 10);
    if (errno == ERANGE) {
        fprintf(stderr, "Number %s used at line %d is out of range\n", yytext, yylineno);
        exit(-1);
    }
    yylval.val = val;
    return NUMBER;
}
[_a-z]+ {
    yylval.id = strdup(yytext);
    return PID;
}
"PROCEDURE" {return PROCEDURE;}
"PROGRAM"   {return PROGRAM;}
"IS"        {return IS;}
"BEGIN"     {return BEG;}
"END"       {return END;}
"IF"        {return IF;}
"THEN"      {return THEN;}
"ELSE"      {return ELSE;}
"ENDIF"     {return ENDIF;}
"WHILE"     {return WHILE;}
"DO"        {return DO;}
"ENDWHILE"  {return ENDWHILE;}
"REPEAT"    {return REPEAT;}
"UNTIL"     {return UNTIL;}
"FOR"       {return FOR;}
"FROM"      {return FROM;}
"TO"        {return TO;}
"DOWNTO"    {return DOWNTO;}
"ENDFOR"    {return ENDFOR;}
"READ"      {return READ;}
"WRITE"     {return WRITE;}
"T"         {return T;}
";"         {return ENDL;}
"("         {return POPEN;}
")"         {return PCLOSE;}
"["         {return TOPEN;}
":"         {return TRANGE;}
"]"         {return TCLOSE;}
":="        {return ASSIGN;}
"+"         {return PLUS;}
"-"         {return MINUS;}
"*"         {return TIMES;}
"/"         {return DIVIDE;}
"%"         {return MOD;}
"="         {return EQ;}
"!="        {return NEQ;}
">"         {return GR;}
"<"         {return LS;}
">="        {return GEQ;}
"<="        {return LEQ;}
","         {return COMMA;}
.           {fprintf(stderr, "Unknown character %s at line %d\n", yytext, yylineno); exit(-1);}
%%