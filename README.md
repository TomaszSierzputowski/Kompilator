<!--
 * Projekt z JFTT2024
 * Kompilator
 *
 * Autor: Tomasz Sierzputowski
 * Numer indeksu: 272364
 *
 * Luty 2025
-->
# Kompilator

----------------------------------------
Narzędzia:

bison (GNU Bison) 3.5.1
flex 2.6.4
GNU Make 4.2.1
g++ 9.4.0

----------------------------------------
Pliki:

README.md
Makefile
lexer.l
parser.y

----------------------------------------
Testowano pod:

Ubuntu 20.04
g++ (Ubuntu 9.4.0-1ubuntu1~20.04.2) 9.4.0

----------------------------------------
Kompilacja:

Polecenie 'make' kompiluje program tworząc pliki:\
  'kompilator' 'parser.o' 'lexer.o' 'parser.cpp' 'parser.hpp' 'lexer.cpp'

Polecenie 'make clean' usuwa pliki:\
  'parser.o' 'lexer.o' 'parser.cpp' 'parser.hpp' 'lexer.cpp'
zostawiając jedynie:\
  'kompilator'

Polecenie 'make cleanall' usuwa wszyskie utworzone pliki:\
  'kompilator' 'parser.o' 'lexer.o' 'parser.cpp' 'parser.hpp' 'lexer.cpp'

----------------------------------------
Użycie:

./kompilator <plik_wejściowy> <plik_wyjściowy>

----------------------------------------
Gramatyka języka
```
program-all   -> procedures main

procedures    -> procedures PROCEDURE proc_head IS declarations BEGIN commands END
              |  procedures PROCEDURE proc_head IS BEGIN commands END
              |

main          -> PROGRAM IS declarations BEGIN commands END
              |  PROGRAM IS BEGIN commands END

commands      -> commands command
              |  command

command       -> identifier := expression;
              |  IF condition THEN commands ELSE commands ENDIF
              |  IF condition THEN commands ENDIF
              |  WHILE condition DO commands ENDWHILE
              |  REPEAT commands UNTIL condition;
              |  FOR pidentifier FROM value TO value DO commands ENDFOR
              |  FOR pidentifier FROM value DOWNTO value DO commands ENDFOR
              |  proc_call;
              |  READ identifier;
              |  WRITE value;

proc_head     -> pidentifier ( args_decl )

proc_call     -> pidentifier ( args )

declarations  -> declarations, pidentifier
              |  declarations, pidentifier[num:num]
              |  pidentifier
              |  pidentifier[num:num]

args_decl     -> args_decl, pidentifier
              |  args_decl, T pidentifier
              |  pidentifier
              |  T pidentifier

args          -> args, pidentifier
              |  pidentifier

expression    -> value
              |  value + value
              |  value - value
              |  value * value
              |  value * value
              |  value / value
              |  value % value

condition     -> value = value
              |  value != value
              |  value > value
              |  value < value
              |  value >= value
              |  value <= value

value         -> num
              |  identifier

identifier    -> pidentifier
              |  pidetnifier[pidentifier]
              |  pidentifier[num]
```
----------------------------------------
Możliwości maszyny wirtualnej

Maszyna składa się z licznika rozkazów $k$ oraz ciągu komórek pamięci $p_i$

Dostępne rozkazy:
| GET i     | pobraną liczbę zapisuje w komórce pamięci $p_i$, $k$ <- $k+1$ |
| PUT i     | wyświetla zawartość komórki pamięci $p_i$, $k$ <- $k+1$ |
| LOAD i    | $p_0$ <- $p_i$, $k$ <- $k+1$ |
| STORE i   | $p_i$ <- $p_0$, $k$ <- $k+1$ |
| LOADI i   | $p_0$ <- $p_{p_i}$, $k$ <- $k+1$ |
| STOREI i  | $p_{p_i}$ <- $p_0$, $k$ <- $k+1$ |
| ADD i     | $p_0$ <- $p_0 + p_i$, $k$ <- $k+1$ |
| SUB i     | $p_0$ <- $p_0 - p_i$, $k$ <- $k+1$ |
| ADDI i    | $p_0$ <- $p_0 + p_{p_i}$, $k$ <- $k+1$ |
| SUBI i    | $p_0$ <- $p_0 - p_{p_i}$, $k$ <- $k+1$ |
| SET x     | $p_0$ <- $x$, $k$ <- $k+1$ |
| HALF      | $p_0$ <- $floor(\frac{p_0}{2})$, $k$ <- $k+1$ |
| JUMP j    | $k$ <- $k+j$ |
| JPOS j    | if $p_0 > 0$ then $k$ <- $k+j$ else $k$ <- $k+1$ |
| JZERO j   | if $p_0 = 0$ then $k$ <- $k+j$ else $k$ <- $k+1$ |
| JNEG j    | if $p_0 < 0$ then $k$ <- $k+j$ else $k$ <- $k+1$ |
| RTRN i    | $k$ <- $p_i$ |
| HALT      | kończy działanie programu |
