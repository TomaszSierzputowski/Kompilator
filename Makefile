.PHONY = all clean cleanall

all: kompilator

kompilator: parser.o lexer.o
	$(CXX) -o kompilator parser.o lexer.o

lexer.o: lexer.cpp
	$(CXX) -o lexer.o -c lexer.cpp

parser.o: parser.cpp
	$(CXX) -o parser.o -c parser.cpp

lexer.cpp: lexer.l parser.hpp
	flex -o lexer.cpp lexer.l

parser.cpp parser.hpp: parser.y
	bison -d -o parser.cpp parser.y

clean:
	rm -f parser.o lexer.o parser.cpp parser.hpp lexer.cpp
	
cleanall: clean
	rm -f kompilator
