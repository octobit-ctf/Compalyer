%{
/* -------- C prologue -------- */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Bison / Lexer externs */
extern int yylineno;
extern int yycolumn;
extern FILE *yyin;
int yylex(void);
void yyerror(const char *s);
%}

/* ========== Advanced Bison Features ========== */
%define parse.error detailed
%locations

/* Move type definitions here, before %union */
%code requires {
/* ---- Types & helper structs ---- */
typedef enum { T_INT = 1, T_FLOAT, T_BOOL } Type;
typedef enum { EQ, NE, LT, LE, GT, GE } RelOp;
typedef struct id_list {
    char *name;
    int has_value;
    double value;
    struct id_list *next;
} id_list;
typedef struct Symbol {
    char *name;
    int type;      /* T_INT, T_FLOAT, T_BOOL */
    int is_const;  /* 1 if const, 0 if variable */
    int has_value; /* 1 if value is set (for tracking initialization) */
    union {
        int ival;
        double fval;
        id_list *list;
    } value;
    struct Symbol *next;
} Symbol;
}

%code {
/* Function declarations and globals */
#define HASH_TABLE_SIZE 101
static Symbol *hash_table[HASH_TABLE_SIZE];

/* Function declarations used in semantic actions */
unsigned int hash(const char *name);
void init_hash_table(void);
void add_symbol(char *name, int type, int is_const, int has_value, double val);
Symbol* find_symbol(const char *name);
void check_assignment_with_type(const char *name, int expr_type);
void update_symbol_value(const char *name, double value);
void free_hash_table(void);
void print_symbol_table(void);

/* Type promotion: allows int->float widening */
static int unify_numeric(int a, int b) {
    if ((a == T_INT || a == T_FLOAT) && (b == T_INT || b == T_FLOAT))
        return (a == T_FLOAT || b == T_FLOAT) ? T_FLOAT : T_INT;
    return a; /* fallback */
}
}

/* --------- Semantic value union --------- */
%union {
  int ival;
  double fval;
  char *str;
  id_list *list;
  RelOp op;
  int type;  /* for expression types */
  struct {
    int type;
    double value;
    int has_value;
  } expr_val; /* expression type and value */
}
/* --------- Tokens --------- */
%token <str> IDF
%token <ival> INT_CONST
%token <fval> FLOAT_CONST
%token <ival> TYPE_
%token BEGIN_ END_ FOR_ IF_ ELSE_ CONST_

%token ASSIGN ASSIGN_CONST SC COMMA LPAR RPAR LBR RBR
%token PLUS MINUS MUL DIV
%token <op> RELOP
/* ---- Nonterminals semantic types ---- */
%type <list> assign_list
%type <list> idf_list
%type <expr_val> expr
%type <expr_val> const_value
%type <type> condition


%start program

/* --------- Precedence (fix ambig like dangling-else & expr prec) --------- */
%left PLUS MINUS
%right UMINUS UPLUS 
%left MUL
%left DIV
%nonassoc RELOP
%right ASSIGN   
%right ASSIGN_CONST     /* assignment right-assoc */
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE_

%%

/* =================== Grammar =================== */

program:
    declarations BEGIN_ statements END_
    ;

declarations:
    /* empty */
  | declarations decl
    ;

decl:
    /* constant declarations - using const_value for signed constants */
    CONST_ TYPE_ IDF ASSIGN_CONST const_value SC {
        /* Check if declared type matches the constant value type */
        if ($2 == T_INT && $5.type == T_FLOAT) {
            fprintf(stderr, "Semantic Error at line %d: cannot assign float to int constant '%s'\n", 
                    yylineno, $3);
        }
        add_symbol($3, $2, 1, 1, $5.value); /* is_const = 1, has_value = 1 */
        free($3);
    }
    /* variable declarations */
  | TYPE_ idf_list SC {
        /* $2 is an id_list, add each to symbol table */
        id_list *tmp;
        id_list *current = $2;
        while (current) {
            add_symbol(current->name, $1, 0, current->has_value, current->value);
            tmp = current;
            current = current->next;
            free(tmp->name);
            free(tmp);
        }
    }
    ;

idf_list:
    IDF {
        id_list *n = malloc(sizeof(id_list));
        n->name = $1;
        n->has_value = 0;
        n->value = 0.0;
        n->next = NULL;
        $$ = n;
    }
  | IDF ASSIGN INT_CONST {
        id_list *n = malloc(sizeof(id_list));
        n->name = $1;
        n->has_value = 1;
        n->value = (double)$3;
        n->next = NULL;
        $$ = n;
    }
  | IDF ASSIGN FLOAT_CONST {
        id_list *n = malloc(sizeof(id_list));
        n->name = $1;
        n->has_value = 1;
        n->value = $3;
        n->next = NULL;
        $$ = n;
    }
  | idf_list COMMA IDF {
        id_list *node = malloc(sizeof(id_list));
        node->name = $3;
        node->has_value = 0;
        node->value = 0.0;
        node->next = NULL;
        id_list *p = $1;
        while (p->next) p = p->next;
        p->next = node;
        $$ = $1;
    }
  | idf_list COMMA IDF ASSIGN INT_CONST {
        id_list *node = malloc(sizeof(id_list));
        node->name = $3;
        node->has_value = 1;
        node->value = (double)$5;
        node->next = NULL;
        id_list *p = $1;
        while (p->next) p = p->next;
        p->next = node;
        $$ = $1;
    }  | idf_list COMMA IDF ASSIGN FLOAT_CONST {
        id_list *node = malloc(sizeof(id_list));
        node->name = $3;
        node->has_value = 1;
        node->value = $5;
        node->next = NULL;
        id_list *p = $1;
        while (p->next) p = p->next;
        p->next = node;
        $$ = $1;
    }
    ;

/* const_value handles signed constants (+/- prefix) */
const_value:
    INT_CONST {
        $$.type = T_INT;
        $$.value = (double)$1;
        $$.has_value = 1;
    }
  | MINUS INT_CONST {
        $$.type = T_INT;
        $$.value = (double)(-$2);
        $$.has_value = 1;
    }
  | PLUS INT_CONST {
        $$.type = T_INT;
        $$.value = (double)$2;
        $$.has_value = 1;
    }
  | FLOAT_CONST {
        $$.type = T_FLOAT;
        $$.value = $1;
        $$.has_value = 1;
    }
  | MINUS FLOAT_CONST {
        $$.type = T_FLOAT;
        $$.value = -$2;
        $$.has_value = 1;
    }
  | PLUS FLOAT_CONST {
        $$.type = T_FLOAT;
        $$.value = $2;
        $$.has_value = 1;
    }
    ;

statements:
    /* empty */
  | statements statement
    ;

/* assign_list builds a linked list of identifiers and checks types */
assign_list:
    IDF ASSIGN expr {
        /* Check type compatibility */
        check_assignment_with_type($1, $3.type);
        /* Update the value in symbol table if expression has a value */
        if ($3.has_value) {
            update_symbol_value($1, $3.value);
        }
        
        id_list *n = malloc(sizeof(id_list));
        n->name = $1; n->next = NULL;
        $$ = n;
    }
  | assign_list COMMA IDF ASSIGN expr {
        /* Check type compatibility */
        check_assignment_with_type($3, $5.type);
        /* Update the value in symbol table if expression has a value */
        if ($5.has_value) {
            update_symbol_value($3, $5.value);
        }
        
        id_list *node = malloc(sizeof(id_list));
        node->name = $3; node->next = NULL;
        id_list *p = $1;
        while (p->next) p = p->next;
        p->next = node;
        $$ = $1;
    }
    ;

/* A statement can be an assign-list ended with semicolon, if, for, or block */
statement:
    assign_list SC {
        /* Type checking is now done in assign_list rules */
        /* free list */
        id_list *tmp;
        while ($1) {
            tmp = $1;
            $1 = $1->next;
            free(tmp->name);
            free(tmp);
        }
    }
  | IF_ LPAR condition RPAR LBR statements RBR %prec LOWER_THAN_ELSE
  | IF_ LPAR condition RPAR LBR statements RBR ELSE_ LBR statements RBR    | FOR_ LPAR IDF ASSIGN expr SC condition SC IDF ASSIGN expr RPAR LBR statements RBR {
        
        check_assignment_with_type($3, $5.type);
        check_assignment_with_type($9, $11.type);
        free($3);
        free($9);
    }
    ;

/* condition uses RELOP (yylval.op tells which relop) */
condition:
    expr RELOP expr {
        int t = unify_numeric($1.type, $3.type);
        if (t != T_INT && t != T_FLOAT) {
            fprintf(stderr, "Semantic Error at line %d, column %d: incompatible types in condition\n", 
                    @1.first_line, @1.first_column);
        }
        $$ = T_BOOL;
    }
    ;

/* Arithmetic expressions with type tracking and value evaluation */
expr:
    expr PLUS expr {
        $$.type = ($1.type == T_FLOAT || $3.type == T_FLOAT) ? T_FLOAT : T_INT;
        if ($1.has_value && $3.has_value) {
            $$.has_value = 1;
            $$.value = $1.value + $3.value;
        } else {
            $$.has_value = 0;
            $$.value = 0.0;
        }
    }
  | expr MINUS expr {
        $$.type = ($1.type == T_FLOAT || $3.type == T_FLOAT) ? T_FLOAT : T_INT;
        if ($1.has_value && $3.has_value) {
            $$.has_value = 1;
            $$.value = $1.value - $3.value;
        } else {
            $$.has_value = 0;
            $$.value = 0.0;
        }
    }
  | expr MUL expr {
        $$.type = ($1.type == T_FLOAT || $3.type == T_FLOAT) ? T_FLOAT : T_INT;
        if ($1.has_value && $3.has_value) {
            $$.has_value = 1;
            $$.value = $1.value * $3.value;
        } else {
            $$.has_value = 0;
            $$.value = 0.0;
        }
    }
  | expr DIV expr {
        $$.type = ($1.type == T_FLOAT || $3.type == T_FLOAT) ? T_FLOAT : T_INT;
        if ($1.has_value && $3.has_value) {
            if ($3.value != 0.0) {
                $$.has_value = 1;
                $$.value = $1.value / $3.value;
            } else {
                fprintf(stderr, "Runtime Error at line %d: division by zero\n", yylineno);
                $$.has_value = 0;
                $$.value = 0.0;
            }
        } else {
            $$.has_value = 0;
            $$.value = 0.0;
        }
    }
  | LPAR expr RPAR {
        $$ = $2;
    }
  | PLUS expr %prec UPLUS {
        $$ = $2;
    }
  | MINUS expr %prec UMINUS {
        $$.type = $2.type;
        if ($2.has_value) {
            $$.has_value = 1;
            $$.value = -$2.value;
        } else {
            $$.has_value = 0;
            $$.value = 0.0;
        }
    }
  | INT_CONST {
        $$.type = T_INT;
        $$.has_value = 1;
        $$.value = (double)$1;
    }
  | FLOAT_CONST {
        $$.type = T_FLOAT;
        $$.has_value = 1;
        $$.value = $1;
    }
  | IDF {
        Symbol *s = find_symbol($1);
        if (s) {
            $$.type = s->type;
            if (s->has_value) {
                $$.has_value = 1;
                $$.value = (s->type == T_INT) ? (double)s->value.ival : s->value.fval;
            } else {
                $$.has_value = 0;
                $$.value = 0.0;
            }
        } else {
            fprintf(stderr, "Semantic Error at line %d: identifier '%s' not declared\n", yylineno, $1);
            $$.type = T_INT;
            $$.has_value = 0;
            $$.value = 0.0;
        }
        free($1);
    }
    ;

%%

/* ========== C code: hash table & helper functions ========== */

/* djb2 hash */
unsigned int hash(const char *name ) {
    unsigned long h = 5381;
    int c;
    while ((c = *name++))
        h = ((h << 5) + h) + c; /* h*33 + c */
    return h % HASH_TABLE_SIZE;
}

void init_hash_table(void) {
    for (int i = 0; i < HASH_TABLE_SIZE; ++i) hash_table[i] = NULL;
}

void add_symbol(char *name, int type, int is_const, int has_value, double val) {
    if (!name) return;
    if (find_symbol(name) != NULL) {
        fprintf(stderr, "Semantic Error at line %d: identifier '%s' already declared\n", yylineno, name);
        return;
    }
    Symbol *s = malloc(sizeof(Symbol));
    s->name = strdup(name);
    s->type = type;
    s->is_const = is_const;
    s->has_value = has_value;
    
    /* Store the value if provided */
    if (has_value) {
        if (type == T_INT) {
            s->value.ival = (int)val;
        } else if (type == T_FLOAT) {
            s->value.fval = val;
        }
    } else {
        /* No initial value */
        s->value.ival = 0;
        s->value.fval = 0.0;
    }
    
    s->next = NULL;
    unsigned int idx = hash(name);
    s->next = hash_table[idx];
    hash_table[idx] = s;
}

Symbol* find_symbol(const char *name) {
    if (!name) return NULL;
    unsigned int idx = hash(name);
    for (Symbol *p = hash_table[idx]; p; p = p->next) {
        if (strcmp(p->name, name) == 0) return p;
    }    return NULL;
}

void check_assignment_with_type(const char *name, int expr_type) {
    Symbol *s = find_symbol(name);
    if (!s) {
        fprintf(stderr, "Semantic Error at line %d: identifier '%s' not declared\n", yylineno, name);
        return; /* Don't exit - allow finding more errors */
    }
    if (s->is_const) {
        fprintf(stderr, "Semantic Error at line %d: cannot assign to constant '%s'\n", yylineno, name);
        return; /* Don't exit - allow finding more errors */
    }
    
    /* Type compatibility check with automatic widening (int -> float) */
    if (s->type == T_FLOAT && expr_type == T_INT) {
        /* Allow widening: int can be assigned to float */
        return;
    }
    
    if (s->type != expr_type) {
        const char *var_type = (s->type == T_INT) ? "int" : (s->type == T_FLOAT) ? "float" : "bool";
        const char *exp_type = (expr_type == T_INT) ? "int" : (expr_type == T_FLOAT) ? "float" : "bool";
        fprintf(stderr, "Semantic error at line %d: type mismatch, can't assign %s to %s var '%s'\n", 
                yylineno, exp_type, var_type, name);
        /* Don't exit - allow finding more errors */
    }
}

void update_symbol_value(const char *name, double value) {
    Symbol *s = find_symbol(name);
    if (s) {
        s->has_value = 1;  /* Mark as having a value */
        if (s->type == T_INT) {
            s->value.ival = (int)value;
        } else if (s->type == T_FLOAT) {
            s->value.fval = value;
        }
    }
}

void free_hash_table(void) {
    for (int i = 0; i < HASH_TABLE_SIZE; ++i) {
        Symbol *p = hash_table[i];
        while (p) {
            Symbol *t = p;
            p = p->next;
            free(t->name);
            free(t);
        }
        hash_table[i] = NULL;
    }
}

void print_symbol_table(void) {
    printf("\n");
    printf("╔════════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                                       SYMBOL TABLE                                 ║\n");
    printf("╠═══════════════════════╦════════════╦═══════════════════════╦═══════════════════════╣\n");
    printf("║       Name            ║    Type    ║       Category        ║     Value             ║\n");
    printf("╠═══════════════════════╬════════════╬═══════════════════════╬═══════════════════════╣\n");

    int count = 0;
    for (int i = 0; i < HASH_TABLE_SIZE; ++i) {
        Symbol *p = hash_table[i];
        while (p) {
            const char *type_str = (p->type == T_INT) ? "INT" : 
                                   (p->type == T_FLOAT) ? "FLOAT" : "BOOL";
            const char *category = p->is_const ? "CONSTANT" : "VARIABLE";

            char value_buf[64];
            if (p->has_value) {
                if (p->type == T_INT) {
                    snprintf(value_buf, sizeof(value_buf), "%d", p->value.ival);
                } else if (p->type == T_FLOAT) {
                    snprintf(value_buf, sizeof(value_buf), "%.6g", p->value.fval);
                } else {
                    strcpy(value_buf, "-");
                }
            } else {
                strcpy(value_buf, "(uninitialized)");
            }

            printf("║ %-21s ║ %-10s ║ %-21s ║ %-21s ║\n", 
                   p->name, type_str, category, value_buf);
            p = p->next;
            count++;
        }
    }

    if (count == 0) {
        printf("║                          (No symbols declared)                                     ║\n");
    }

    printf("╚═══════════════════════╩════════════╩═══════════════════════╩═══════════════════════╝\n");
    printf("Total symbols: %d\n\n", count);
}

/* ========== main, error handling ========== */

int main(int argc, char **argv) {
    init_hash_table();
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) { perror("fopen"); return 1; }
    }
    printf("Starting Lang_F parsing...\n");
    yyparse();
    printf("Parsing finished.\n");
    print_symbol_table();
    free_hash_table();
    
    return 0;
}

void yyerror(const char *s) {
    fprintf(stderr, "Parse error at line %d, column %d: %s\n", 
            yylloc.first_line, yylloc.first_column, s);
}

