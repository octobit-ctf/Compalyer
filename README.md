# Lang_F Compiler

A simple compiler/interpreter for a custom programming language built with **Flex** (lexical analyzer) and **Bison** (parser).

## Features

- ✅ Variable declarations with optional initialization (`INT X := 5;`)
- ✅ Constant declarations (`CONST INT MAX = 100;`)
- ✅ Type checking (INT, FLOAT, BOOL)
- ✅ Type promotion (int → float widening)
- ✅ Arithmetic expressions (+, -, *, /)
- ✅ Relational operators (==, <>, <, >, <=, >=)
- ✅ Control structures (IF/ELSE, FOR)
- ✅ Runtime value tracking
- ✅ Symbol table with formatted output
- ✅ Detailed error messages with line/column numbers

## Language Syntax

```
CONST INT MAX = 100;
INT X := 1, Y, Z;
FLOAT Pi := 3.14;

BEGIN
    X := 5;
    Y := X + 10;
    
    IF (X < Y) {
        Z := X + 6;
    } ELSE {
        Z := Y;
    }
    
    FOR (I := 0; I < 10; I := I + 1) {
        X := X + 1;
    }
END
```

## Build Instructions

```bash
# Generate parser from Bison
bison -d Bison.y

# Generate lexer from Flex
flex flex.l

# Compile everything
gcc -o langf Bison.tab.c lex.yy.c -lfl

# Run the compiler
./langf algo
```

## Example Output

```
Starting Lang_F parsing...
Parsing finished.

╔════════════════════════════════════════════════════════════════════════════════════╗
║                                       SYMBOL TABLE                                 ║
╠═══════════════════════╦════════════╦═══════════════════════╦═══════════════════════╣
║       Name            ║    Type    ║       Category        ║     Value             ║
╠═══════════════════════╬════════════╬═══════════════════════╬═══════════════════════╣
║ X                     ║ INT        ║ VARIABLE              ║ 5                     ║
║ Y                     ║ INT        ║ VARIABLE              ║ 15                    ║
║ MAX                   ║ INT        ║ CONSTANT              ║ 100                   ║
╚═══════════════════════╩════════════╩═══════════════════════╩═══════════════════════╝
Total symbols: 3
```

## Files

- `Bison.y` - Parser grammar and semantic actions
- `flex.l` - Lexical analyzer
- `algo` - Sample program file

## Error Handling

The compiler provides detailed error messages:
- **Lexical errors**: Invalid characters, double underscores in identifiers
- **Syntax errors**: Unexpected tokens with line/column info
- **Semantic errors**: Undeclared variables, type mismatches, constant reassignment

## Author

Built as a compiler construction project.
