%code requires {

struct line {
    char command = 0;
    long long val = -1;
    struct line* next = nullptr;
};

typedef struct {
    struct line* first = nullptr;
    struct line** add = &first;
    long long no_lines = 0;
    long long* jtoset = 0;
} assembly;

struct pos_type {
    long long pos;
    int type;
    assembly* code = nullptr;
};

}

%code {
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#define LLONG_MAX 9223372036854775807LL

extern int yylineno;
extern int yylex();
extern FILE* yyin;
extern FILE* yyout;
char* yyout_name;

void yyerror(const char* s);

#define VAR_TYPE    1
#define ARG_TYPE    2
#define ARR_TYPE    3
#define IN_TYPE     4
#define OUT_TYPE    5

#define ITER_TYPE   6
#define PROC_TYPE   7
#define ARRG_TYPE   8

#define HALT    0

#define GET     1
#define PUT     2

#define LOAD    3
#define STORE   4
#define LOADI   5
#define STOREI  6

#define ADD     7
#define SUB     8
#define ADDI    9
#define SUBI    10

#define SET     11

#define HALF    12

#define JUMP    13
#define JPOS    14
#define JZERO   15
#define JNEG    16

#define RTRN    17

#define JPROC   20
#define GETLINE 21
#define LOADA   23
#define STOREA  24
#define ADDA    27
#define SUBA    28

#define PUTC    30
#define ADDC    31

assembly* append(assembly* base, char command, long long val) {
    struct line* tmp = new line{command, val, nullptr};
    *(base->add) = tmp;
    base->add = &(tmp->next);
    ++base->no_lines;
    return base;
}

assembly* append_jump(assembly* base, char command) {
    struct line* tmp = new line{command, 0, nullptr};
    *(base->add) = tmp;
    base->add = &(tmp->next);
    ++base->no_lines;
    base->jtoset = &(tmp->val);
    return base;
}

assembly* append_all(assembly* base, assembly* to_add) {
    if (to_add->no_lines > 0) {
        *(base->add) = to_add->first;
        base->add = to_add->add;
        base->no_lines += to_add->no_lines;
    }
    delete to_add;
    return base;
}

struct iterator {
    char* name;
    long long pos;
    struct iterator* next;
};
struct iterator* iterators = nullptr;

struct var_id {
    char* name;
    long long pos;
    bool initialized;
    struct var_id* next;
};
struct var_id* var_ids = nullptr;

void clear_var_ids() {
    struct var_id* tmp = var_ids, *next;
    while (tmp != nullptr) {
        next = tmp->next;
        delete tmp;
        tmp = next;
    }
    var_ids = nullptr;
}

struct array_id {
    char* name;
    long long pos;
    long long first;
    long long last;
    struct array_id* next;
};
struct array_id* array_ids = nullptr;

void clear_array_ids() {
    struct array_id* tmp = array_ids, *next;
    while (tmp != nullptr) {
        next = tmp->next;
        delete tmp;
        tmp = next;
    }
    array_ids = nullptr;
}

struct arg_id {
    char* name;
    long long pos;
    int type;
    struct arg_id* next;
};

struct proc_id {
    char* name;
    long long no_lines;
    long long rtrn;
    struct arg_id* arg_ids;
    long long arg_end;
    struct proc_id* next;
};
struct proc_id* proc_ids = nullptr;

long long all_proc_lines = 0;

struct const_id {
    long long val;
    long long pos;
    struct const_id* next;
};
struct const_id* const_ids = nullptr;
bool need_consts = false;

long long first_empty_memory = 3;

long long operators_memo = 0;
assembly* multiplication = new assembly;
assembly* division = new assembly;
assembly* modulus = new assembly;

bool need_multiplication = false;
bool need_division = false;
bool need_modulus = false;

long long rtrn;
long long a;
long long b;
long long res;
long long k;
long long t1;
long long t2;

void set_const(long long c) {
    if (c == 0) {
        return;
    }
    struct const_id* tmp = const_ids;
    while (tmp != nullptr && tmp->val != c) {
        tmp = tmp->next;
    }
    if (tmp == nullptr) {
        const_ids = new const_id{c, 0, const_ids};
    } else if (tmp->pos == 0) {
        tmp->pos = first_empty_memory;
        first_empty_memory++;
        need_consts = true;
    }
}

void add_const(long long c) {
    struct const_id* tmp = const_ids;
    while (tmp != nullptr && tmp->val != c && tmp->val != -c) {
        tmp = tmp->next;
    }
    if (tmp == nullptr) {
        const_ids = new const_id{c, first_empty_memory, const_ids};
        first_empty_memory++;
        need_consts = true;
    } else if (tmp->pos == 0) {
        tmp->pos = first_empty_memory;
        first_empty_memory++;
        need_consts = true;
    }
}

void put_const(long long c) {
    struct const_id* tmp = const_ids;
    while (tmp != nullptr && tmp->val != c) {
        tmp = tmp->next;
    }
    if (tmp == nullptr) {
        const_ids = new const_id{c, first_empty_memory, const_ids};
        first_empty_memory++;
        need_consts = true;
    } else if (tmp->pos == 0) {
        tmp->pos = first_empty_memory;
        first_empty_memory++;
        need_consts = true;
    }
}

long long find_const(long long c) {
    struct const_id* tmp = const_ids;
    while (tmp != nullptr && tmp->val != c) {
        tmp = tmp->next;
    }
    if (tmp == nullptr) {
        return 0;
    } else {
        return tmp->pos;
    }
}

struct line** lines;

void do_line(long long i) {
    struct line* tmp = lines[i];
    switch (tmp->command) {
        case SET:
            set_const(tmp->val);
            break;
        case PUTC:
            put_const(tmp->val);
            break;
        case GETLINE:
            set_const(i + 4);
            break;
    }
}

void do_line(struct line* tmp, long long i) {
    switch (tmp->command) {
        case SET:
            set_const(tmp->val);
            break;
        case PUTC:
            put_const(tmp->val);
            break;
        case GETLINE:
            set_const(i + 4);
            break;
        case JUMP:
        case JZERO:
        case JPOS:
        case JNEG:
            if (tmp->val < 0) {
                for (int j = i + tmp->val; j < i; ++j) {
                    do_line(j);
                }
            }
            break;
    }
}

void write_all(assembly* base) {
    lines = new line*[base->no_lines];

    struct line* tmp = base->first, *tmp2;
    long long i = 0;
    long long proc_begin;
    while (tmp != nullptr) {
        lines[i] = tmp;
        if (tmp->command == HALT) {
            proc_begin = i + 1;
        }
        tmp = tmp->next;
        ++i;
    }
    tmp = base->first;
    i = 0;
    while (tmp != nullptr) {
        if (tmp->command == JPROC) {
            if (tmp->val >= 0) {
                tmp->val += proc_begin - i;
            } else if (tmp->val == -1) {
                tmp->val = proc_begin + all_proc_lines - i;
            } else if (tmp->val == -2) {
                tmp->val = proc_begin + all_proc_lines + multiplication->no_lines - i;
            } else if (tmp->val == -3) {
                tmp->val = proc_begin + all_proc_lines + multiplication->no_lines + division->no_lines - i;
            }
            tmp->command = JUMP;
        }
        tmp = tmp->next;
        ++i;
    }
    tmp = base->first;
    i = 0;
    while (tmp != nullptr) {
        do_line(tmp, i);
        tmp = tmp->next;
        ++i;
    }
    i = proc_begin - 1;
    tmp = lines[i];
    while (tmp != nullptr) {
        do_line(i);
        tmp = tmp->next;
        ++i;
    }
    tmp = base->first;
    while (tmp != nullptr) {
        if (tmp->command == ADDC) {
            add_const(tmp->val);
        }
        tmp = tmp->next;
    }
    tmp = base->first;
    i = 0;
    long long j;
    if (need_consts) {
        while (tmp != nullptr) {
            switch (tmp->command) {
                case SET:
                    if (tmp->val == 0) {
                        tmp->command = SUB;
                        tmp->val = 0;
                    } else {
                        j = find_const(tmp->val);
                        if (j > 0) {
                            tmp->command = LOAD;
                            tmp->val = j;
                        }
                    }
                    break;
                case PUTC:
                    tmp->command = PUT;
                    tmp->val = find_const(tmp->val);
                    break;
                case ADDC:
                    j = find_const(tmp->val);
                    if (j > 0) {
                        tmp->command = ADD;
                        tmp->val = j;
                    } else {
                        tmp->command = SUB;
                        tmp->val = find_const(-tmp->val);
                    }
                    break;
                case GETLINE:
                    j = find_const(i + 4);
                    if (j > 0) {
                        tmp->command = LOAD;
                        tmp->val = j;
                    } else {
                        tmp->command = SET;
                        tmp->val = i + 4;
                    }
                    break;
            }
            tmp = tmp->next;
            ++i;
        }
    } else {
        while (tmp != nullptr) {
            if (tmp->command == GETLINE) {
                tmp->command = SET;
                tmp->val = i + 3;
            }
            tmp = tmp->next;
            ++i;
        }
    }

    yyout = fopen(yyout_name, "w");
    if (need_consts) {
        fprintf(yyout, "JUMP %lld\n", base->no_lines + 1);
    }
    tmp = base->first;
    while (tmp != nullptr) {
        switch (tmp->command) {
            case HALT:
                fprintf(yyout, "HALT\n");
                break;
            case GET:
                fprintf(yyout, "GET %lld\n", tmp->val);
                break;
            case PUT:
                fprintf(yyout, "PUT %lld\n", tmp->val);
                break;
            case LOAD:
                fprintf(yyout, "LOAD %lld\n", tmp->val);
                break;
            case STORE:
                fprintf(yyout, "STORE %lld\n", tmp->val);
                break;
            case LOADI:
                fprintf(yyout, "LOADI %lld\n", tmp->val);
                break;
            case STOREI:
                fprintf(yyout, "STOREI %lld\n", tmp->val);
                break;
            case ADD:
                fprintf(yyout, "ADD %lld\n", tmp->val);
                break;
            case SUB:
                fprintf(yyout, "SUB %lld\n", tmp->val);
                break;
            case ADDI:
                fprintf(yyout, "ADDI %lld\n", tmp->val);
                break;
            case SUBI:
                fprintf(yyout, "SUBI %lld\n", tmp->val);
                break;
            case SET:
                fprintf(yyout, "SET %lld\n", tmp->val);
                break;
            case HALF:
                fprintf(yyout, "HALF\n");
                break;
            case JUMP:
                fprintf(yyout, "JUMP %lld\n", tmp->val);
                break;
            case JPOS:
                fprintf(yyout, "JPOS %lld\n", tmp->val);
                break;
            case JZERO:
                fprintf(yyout, "JZERO %lld\n", tmp->val);
                break;
            case JNEG:
                fprintf(yyout, "JNEG %lld\n", tmp->val);
                break;
            case RTRN:
                fprintf(yyout, "RTRN %lld\n", tmp->val);
                break;
            default:
                fprintf(yyout, "ERRORERRORERRORERRORERRORERROR    %d\n", tmp->command);
                break;
        }
        tmp = tmp->next;
    }
    if (need_consts) {
        i = 0;
        struct const_id* tmpc = const_ids;
        while (tmpc != nullptr) {
            if (tmpc->pos > 0) {
                fprintf(yyout, "SET %lld\n", tmpc->val);
                fprintf(yyout, "STORE %lld\n", tmpc->pos);
                i += 2;
            }
            tmpc = tmpc->next;
        }
        fprintf(yyout, "JUMP %lld\n", -(base->no_lines + i));
    }
    fclose(yyout);
}

void add_multiplication() {
    need_multiplication = true;
    if (operators_memo == 0) {
        operators_memo = first_empty_memory;
        rtrn = operators_memo;
        a = operators_memo + 1;
        b = operators_memo + 2;
        res = operators_memo + 3;
        k = operators_memo + 4;
        t1 = operators_memo + 5;
        t2 = operators_memo + 6;
        first_empty_memory += 7;
    }

    append(multiplication, SUB, 0);
    append(multiplication, STORE, res);
    append(multiplication, LOAD, a);
    append(multiplication, JPOS, 6);
    append(multiplication, SUB, 0);
    append(multiplication, SUB, b);
    append(multiplication, STORE, b);
    append(multiplication, SUB, 0);
    append(multiplication, SUB, a);
    append(multiplication, STORE, a);
    append(multiplication, HALF, 0);
    append(multiplication, ADD, 0);
    append(multiplication, SUB, a);
    append(multiplication, JZERO, 4);
    append(multiplication, LOAD, res);
    append(multiplication, ADD, b);
    append(multiplication, STORE, res);
    append(multiplication, LOAD, b);
    append(multiplication, ADD, b);
    append(multiplication, STORE, b);
    append(multiplication, LOAD, a);
    append(multiplication, HALF, 0);
    append(multiplication, JPOS, -13);
    append(multiplication, LOAD, res);
    append(multiplication, RTRN, rtrn);
}

void add_division() {
    need_division = true;
    if (operators_memo == 0) {
        operators_memo = first_empty_memory;
        rtrn = operators_memo;
        a = operators_memo + 1;
        b = operators_memo + 2;
        res = operators_memo + 3;
        k = operators_memo + 4;
        t1 = operators_memo + 5;
        t2 = operators_memo + 6;
        first_empty_memory += 7;
    }

    append(division, SUB, 0);
    append(division, STORE, res);
    append(division, ADDC, 1);
    append(division, STORE, k);
    append(division, STORE, t1);
    append(division, STORE, t2);
    append(division, LOAD, a);
    append(division, JPOS, 5);
    append(division, SUB, a);
    append(division, STORE, t1);
    append(division, SUB, a);
    append(division, STORE, a);
    append(division, LOAD, b);
    append(division, JPOS, 5);
    append(division, SUB, b);
    append(division, STORE, t2);
    append(division, SUB, b);
    append(division, STORE, b);
    append(division, SUB, a);
    append(division, JPOS, 8);
    append(division, LOAD, k);
    append(division, ADD, k);
    append(division, STORE, k);
    append(division, LOAD, b);
    append(division, ADD, b);
    append(division, STORE, b);
    append(division, JUMP, -8);
    append(division, LOAD, k);
    append(division, HALF, 0);
    append(division, JZERO, 13);
    append(division, STORE, k);
    append(division, LOAD, b);
    append(division, HALF, 0);
    append(division, STORE, b);
    append(division, LOAD, a);
    append(division, SUB, b);
    append(division, JNEG, -9);
    append(division, STORE, a);
    append(division, LOAD, res);
    append(division, ADD, k);
    append(division, STORE, res);
    append(division, JUMP, -14);
    append(division, LOAD, t1);
    append(division, SUB, t2);
    append(division, JZERO, 6);
    append(division, LOAD, a);
    append(division, JZERO, 2);
    append(division, SET, -1);
    append(division, SUB, res);
    append(division, RTRN, rtrn);
    append(division, LOAD, res);
    append(division, RTRN, rtrn);
}

void add_modulus() {
    need_modulus = true;
    if (operators_memo == 0) {
        operators_memo = first_empty_memory;
        rtrn = operators_memo;
        a = operators_memo + 1;
        b = operators_memo + 2;
        res = operators_memo + 3;
        k = operators_memo + 4;
        t1 = operators_memo + 5;
        t2 = operators_memo + 6;
        first_empty_memory += 7;
    }

    append(modulus, LOAD, a);
    append(modulus, STORE, t1);
    append(modulus, STORE, t2);
    append(modulus, JPOS, 5);
    append(modulus, SUB, a);
    append(modulus, STORE, t1);
    append(modulus, SUB, a);
    append(modulus, STORE, a);
    append(modulus, LOAD, b);
    append(modulus, JPOS, 5);
    append(modulus, SUB, b);
    append(modulus, STORE, t2);
    append(modulus, SUB, b);
    append(modulus, STORE, b);
    append(modulus, SUB, a);
    append(modulus, JPOS, 25);
    append(modulus, ADD, a);
    append(modulus, ADD, 0);
    append(modulus, SUB, a);
    append(modulus, JPOS, 4);
    append(modulus, ADD, a);
    append(modulus, ADD, 0);
    append(modulus, JUMP, -4);
    append(modulus, ADD, a);
    append(modulus, HALF, 0);
    append(modulus, STORE, k);
    append(modulus, LOAD, a);
    append(modulus, SUB, k);
    append(modulus, STORE, a);
    append(modulus, LOAD, k);
    append(modulus, HALF, 0);
    append(modulus, SUB, b);
    append(modulus, JNEG, 8);
    append(modulus, ADD, b);
    append(modulus, STORE, k);
    append(modulus, LOAD, a);
    append(modulus, SUB, k);
    append(modulus, JNEG, -8);
    append(modulus, STORE, a);
    append(modulus, JUMP, -10);
    append(modulus, LOAD, t2);
    append(modulus, JZERO, 5);
    append(modulus, LOAD, t1);
    append(modulus, JZERO, 9);
    append(modulus, LOAD, a);
    append(modulus, RTRN, rtrn);
    append(modulus, LOAD, t1);
    append(modulus, JZERO, 9);
    append(modulus, LOAD, a);
    append(modulus, JZERO, 2);
    append(modulus, SUB, b);
    append(modulus, RTRN, rtrn);
    append(modulus, SUB, a);
    append(modulus, JZERO, 2);
    append(modulus, ADD, b);
    append(modulus, RTRN, rtrn);
    append(modulus, SUB, a);
    append(modulus, RTRN, rtrn);
}

struct proc_id* scope = nullptr;

void make_out(long long pos) {
    struct arg_id* tmp = scope->arg_ids;
    while (tmp->pos != pos) {
        tmp = tmp->next;
    }
    tmp->type = OUT_TYPE;
}

//TODO może da się to wykorzystać
void fix_args(assembly* proc) {
    struct line* tmp = proc->first;
    while (tmp != nullptr) {
        if (tmp->command >= LOADA && tmp->command <= SUBA) {
            /*struct arg_id* arg = scope->arg_ids;
            while (tmp->val != arg->pos) {
                arg = arg->next;
            }
            if (arg->type == IN_TYPE) {
                tmp->command -= 20;
            } else {
                tmp->command -= 18;
            }*/
            tmp->command -= 18;
        }

        tmp = tmp->next;
    }
}

int is_sum_in_range(long long a, long long b) {
    if (a > 0) {
        if (b > LLONG_MAX - a) {
            return 1;
        }
    } else {
        if (-b > LLONG_MAX + a) {
            return -1;
        }
    }
    return 0;
}

assembly* ident_minus_ident(struct pos_type* a, struct pos_type* b) {
    assembly* ret = new assembly;
    if (a->type == ARR_TYPE) {
        if (b->type == ARG_TYPE) {
            append_all(ret, a->code);
            append(ret, LOADI, 0);
            append(ret, SUBA, b->pos);
        } else if (b->type == ARR_TYPE) {
            struct line* cmpa = a->code->first;
            struct line* cmpb = b->code->first;
            while (cmpa != nullptr && cmpb != nullptr && cmpa->command == cmpb->command && cmpa->val == cmpb->val) {
                cmpa = cmpa->next;
                cmpb = cmpb->next;
            }
            if (cmpa == nullptr && cmpb == nullptr) {
                append(ret, SET, 0);
            } else {
                append_all(ret, b->code);
                append(ret, STORE, 1);
                append_all(ret, a->code);
                append(ret, LOADI, 0);
                append(ret, SUBI, 1);
            }
        } else {
            append_all(ret, a->code);
            append(ret, LOADI, 0);
            append(ret, SUB, b->pos);
        }
    } else if (b->type == ARR_TYPE) {
        append_all(ret, b->code);
        append(ret, STORE, 1);
        if (a->type == ARG_TYPE) {
            append(ret, LOADA, a->pos);
        } else {
            append(ret, LOAD, a->pos);
        }
        append(ret, SUBI, 1);
    } else if (a->pos == b->pos) {
        append(ret, SET, 0);
    } else {
        if (a->type == ARG_TYPE) {
            append(ret, LOADA, a->pos);
        } else {
            append(ret, LOAD, a->pos);
        }
        if (b->type == ARG_TYPE) {
            append(ret, SUBA, b->pos);
        } else {
            append(ret, SUB, b->pos);
        }
    }

    return ret;
}

assembly* num_minus_ident(long long a, struct pos_type* b) {
    assembly* ret = new assembly;
    if (b->type == ARG_TYPE) {
        append(ret, SET, a);
        append(ret, SUBI, b->pos);
    } else if (b->type == ARR_TYPE) {
        append_all(ret, b->code);
        append(ret, STORE, 1);
        append(ret, SET, a);
        append(ret, SUBI, 1);
    } else {
        append(ret, SET, a);
        append(ret, SUB, b->pos);
    }

    return ret;
}

assembly* multiply_by_number(long long a1) {
    int no_ones = 0;
    int log = 0;
    int add = 0;
    long long a2 = a1;
    do {
        no_ones++;
        a2 = a2 & (a2 - 1);
    } while (a2 != 0);
    a2 = a1;
    while (a2 > 1) {
        a2 >>= 1;
        log += 1;
    }
    assembly* tmp = new assembly;
    if (no_ones <= 3 && log + (no_ones - 1) * 2 <= 10) {
        a2 = a1;
        while (a2 > 1) {
            if (a2 % 2 == 1) {
                add++;
                append(tmp, STORE, add);
            }
            a2 >>= 1;
            append(tmp, ADD, 0);
        }
        if (add >= 1) {
            append(tmp, ADD, 1);
        }
        if (add >= 2) {
            append(tmp, ADD, 2);
        }
    } else {
        if (!need_multiplication) {
            add_multiplication();
        }
        append(tmp, STORE, b);
        append(tmp, SET, a1);
        append(tmp, STORE, a);
        append(tmp, GETLINE, 0);
        append(tmp, STORE, rtrn);
        append(tmp, JPROC, -1);
    }
    assembly* ret = new assembly;
    append(ret, JZERO, tmp->no_lines + 1);
    append_all(ret, tmp);
    return ret;
}

void print_type(int type) {
    switch (type) {
        case VAR_TYPE:
            fprintf(stderr, "Variable");
            break;
        case ARR_TYPE:
            fprintf(stderr, "Array");
            break;
        case ITER_TYPE:
            fprintf(stderr, "For loop iterator");
            break;
        case PROC_TYPE:
            fprintf(stderr, "Procedure");
            break;
        case ARG_TYPE:
            fprintf(stderr, "Argument");
            break;
        case ARRG_TYPE:
            fprintf(stderr, "Array argument");
            break;
    }
}

void check_for_name_duplicate(int type, char* name) {
    struct iterator* tmpi = iterators;
    while (tmpi != nullptr) {
        if (strcmp(tmpi->name, name) == 0) {
            print_type(type);
            fprintf(stderr, " declared at line %d has the same name as iterator %s declared for outer for loop\n", yylineno, name);
            exit(-1);
        }
        tmpi = tmpi->next;
    }
    struct var_id* tmpv = var_ids;
    while (tmpv != nullptr) {
        if (strcmp(tmpv->name, name) == 0) {
            print_type(type);
            if (scope != nullptr && tmpv->pos < scope->arg_end) {
                fprintf(stderr, " declared at line %d has the same name as argument %s\n", yylineno, name);
            } else {
                fprintf(stderr, " declared at line %d has the same name as variable %s\n", yylineno, name);
            }
            exit(-1);
        }
        tmpv = tmpv->next;
    }
    struct array_id* tmpa = array_ids;
    while (tmpa != nullptr) {
        if (strcmp(tmpa->name, name) == 0) {
            print_type(type);
            if (scope != nullptr && tmpa->pos < scope->arg_end) {
                fprintf(stderr, " declared at line %d has the same name as array argument %s\n", yylineno, name);
            } else {
                fprintf(stderr, " declared at line %d has the same name as array %s\n", yylineno, name);
            }
            exit(-1);
        }
        tmpa = tmpa->next;
    }
    struct proc_id* tmpp = proc_ids;
    while (tmpp != nullptr) {
        if (strcmp(tmpp->name, name) == 0) {
            print_type(type);
            fprintf(stderr, " declared at line %d has the same name as procedure %s\n", yylineno, name);
            exit(-1);
        }
        tmpp = tmpp->next;
    }
    if (type != PROC_TYPE && scope != nullptr && strcmp(scope->name, name) == 0) {
        print_type(type);
        fprintf(stderr, " declared at line %d has the same name as procedure %s\n", yylineno, name);
        exit(-1);
    }
}

int trash;
}

%union {
    struct pos_type* ident;
    long long pos;
    long long val;
    char* id;
    struct arg_id* proc_args;
    assembly* code;
}

%token <val> NUMBER
%token <id> PID
%token PROCEDURE PROGRAM IS BEG END
%token IF THEN ELSE ENDIF
%token WHILE DO ENDWHILE
%token REPEAT UNTIL
%token FOR FROM TO DOWNTO ENDFOR
%token READ WRITE
%token T
%token ENDL
%token POPEN PCLOSE
%token TOPEN TRANGE TCLOSE
%token ASSIGN
%token PLUS MINUS TIMES DIVIDE MOD
%token EQ NEQ GR LS GEQ LEQ
%token COMMA

%type <code> procedures
%type <code> procedure
%type <proc_args> args_decl
%type <proc_args> args
%type <code> main
%type <code> commands
%type <code> command
%type <code> expression
%type <code> condition
%type <val> updown
%type <val> number
%type <ident> identifier
%type <ident> sidentifier
%type <pos> iidentifier

%%
input:
    procedures main {
        all_proc_lines = $1->no_lines;
        assembly* tmp = append_all($2, $1);
        append_all(tmp, multiplication);
        append_all(tmp, division);
        append_all(tmp, modulus);
        write_all(tmp);
    }
    | main {
        assembly* tmp = $1;
        append_all(tmp, multiplication);
        append_all(tmp, division);
        append_all(tmp, modulus);
        write_all(tmp);
    }
    | error {
        exit(-1);
    }
;

procedures:
    procedures procedure {
        $$ = append_all($1, $2);
    }
    | procedure {
        $$ = $1;
    }
;

procedure:
    PROCEDURE proc_head IS declarations BEG commands END {
        fix_args($6);
        scope->rtrn = first_empty_memory;
        ++first_empty_memory;
        $$ = append($6, RTRN, scope->rtrn);
        scope->no_lines = $$->no_lines;

        proc_ids = scope;
        scope = nullptr;
        clear_var_ids();
        clear_array_ids();
    }
    | PROCEDURE proc_head IS BEG commands END {
        fix_args($5);
        scope->rtrn = first_empty_memory;
        ++first_empty_memory;
        $$ = append($5, RTRN, scope->rtrn);
        scope->no_lines = $$->no_lines;

        proc_ids = scope;
        scope = nullptr;
        clear_var_ids();
        clear_array_ids();
    }
;

proc_head:
    PID POPEN args_decl PCLOSE {
        check_for_name_duplicate(PROC_TYPE, $1);
        scope = new proc_id{strdup($1), 0, 0, $3, 0, proc_ids};
        struct arg_id* tmp = $3;
        while (tmp != nullptr) {
            if (tmp->type == ARR_TYPE) {
                check_for_name_duplicate(ARRG_TYPE, tmp->name);
                array_ids = new array_id{tmp->name, first_empty_memory, 0, 0, array_ids};
                tmp->pos = first_empty_memory;
            } else {
                check_for_name_duplicate(ARG_TYPE, tmp->name);
                var_ids = new var_id{tmp->name, first_empty_memory, true, var_ids};
                tmp->pos = first_empty_memory;
            }
            ++first_empty_memory;
            tmp = tmp->next;
        }
        scope->arg_end = first_empty_memory;
    }
;

declarations:
    declarations COMMA PID {
        check_for_name_duplicate(VAR_TYPE, $3);
        var_ids = new var_id{strdup($3), first_empty_memory, false, var_ids};
        ++first_empty_memory;
    }
    | declarations COMMA PID TOPEN number TRANGE number TCLOSE {
        check_for_name_duplicate(ARR_TYPE, $3);
        if ($7 < $5) {
            fprintf(stderr, "Array %s[%lld:%lld] declared at line %d has inappropriate range (for range [a:b] b has to be greater or equal to a)\n", $3, $5, $7, yylineno);
            exit(-1);
        }
        array_ids = new array_id{strdup($3), first_empty_memory - $5, $5, $7, array_ids};
        first_empty_memory += $7 - $5 + 1;
    }
    | PID {
        check_for_name_duplicate(VAR_TYPE, $1);
        var_ids = new var_id{strdup($1), first_empty_memory, false, var_ids};
        ++first_empty_memory;
    }
    | PID TOPEN number TRANGE number TCLOSE {
        check_for_name_duplicate(ARR_TYPE, $1);
        if ($5 < $3) {
            fprintf(stderr, "Array %s[%lld:%lld] declared at line %d has inappropriate range (for range [a:b] b has to be greater or equal to a)\n", $1, $3, $5, yylineno);
            exit(-1);
        }
        array_ids = new array_id{strdup($1), first_empty_memory - $3, $3, $5, array_ids};
        first_empty_memory += $5 - $3 + 1;
    }
;

args_decl:
    args_decl COMMA PID {
        check_for_name_duplicate(ARG_TYPE, $3);
        $$ = new arg_id{strdup($3), 0, IN_TYPE, $1};
    }
    | args_decl COMMA T PID {
        check_for_name_duplicate(ARG_TYPE, $4);
        $$ = new arg_id{strdup($4), 0, ARR_TYPE, $1};
    }
    | PID {
        check_for_name_duplicate(ARG_TYPE, $1);
        $$ = new arg_id{strdup($1), 0, IN_TYPE, nullptr};
    }
    | T PID {
        check_for_name_duplicate(ARG_TYPE, $2);
        $$ = new arg_id{strdup($2), 0, ARR_TYPE, nullptr};
    }
;

args:
    args COMMA PID {
        $$ = new arg_id{strdup($3), 0, 0, $1};
    }
    | PID {
        $$ = new arg_id{strdup($1), 0, 0, nullptr};
    }
;

main:
    PROGRAM IS declarations BEG commands END {
        $$ = append($5, HALT, 0);
    }
    | PROGRAM IS BEG commands END {
        $$ = append($4, HALT, 0);
    }
;

commands:
    commands command {
        $$ = append_all($1, $2);
    }
    | command {
        $$ = $1;
    }
;

command:
    sidentifier ASSIGN expression ENDL {
        if ($1->type == VAR_TYPE) {
            $$ = append($3, STORE, $1->pos);
        } else if ($1->type == ARG_TYPE) {
            $$ = append($3, STOREI, $1->pos);
        } else if ($1->type == ARR_TYPE) {
            $$ = append($1->code, STORE, 2);
            append_all($$, $3);
            append($$, STOREI, 2);
        }
    }
    | IF condition THEN commands ELSE commands ENDIF {
        if ($2->no_lines == -2) {
            $$ = $6;
        } else if ($2->no_lines == -1) {
            $$ = $4;
        } else if ($6->no_lines > 0) {
            *($2->jtoset) = $4->no_lines + 2;
            $$ = append_all($2, $4);
            append($$, JUMP, $6->no_lines + 1);
            append_all($$, $6);
        } else if ($4->no_lines > 0) {
            *($2->jtoset) = $4->no_lines + 1;
            $$ = append_all($2, $4);
        } else {
            $$ = new assembly;
        }
    }
    | IF condition THEN commands ENDIF {
        if ($2->no_lines == -2) {
            $$ = new assembly;
        } else if ($2->no_lines == -1) {
            $$ = $4;
        } else if ($4->no_lines > 0) {
            *($2->jtoset) = $4->no_lines + 1;
            $$ = append_all($2, $4);
        } else {
            $$ = new assembly;
        }
    }
    | WHILE condition DO commands ENDWHILE {
        if ($2->no_lines == -2) {
            $$ = new assembly;
        } else if ($2->no_lines == -1) {
            $$ = $4;
            append($$, JUMP, -$$->no_lines);
        } else {
            *($2->jtoset) = $4->no_lines + 2;
            $$ = append_all($2, $4);
            append($$, JUMP, -$$->no_lines);
        }
    }
    | REPEAT commands UNTIL condition ENDL {
        if ($2->no_lines == -2) {
            $$ = $2;
            append($$, JUMP, -$$->no_lines);
        } else if ($2->no_lines == -1) {
            $$ = $2;
        } else {
            *($4->jtoset) = -($2->no_lines + $4->no_lines - 1);
            $$ = append_all($2, $4);
        }
    }
    | FOR iidentifier FROM number updown number DO commands ENDFOR {
        $$ = new assembly;
        if ($8->no_lines > 0) {
            if ($6 * $5 > $4 * $5) {
                append($$, SET, $4);
                append($$, STORE, iterators->pos);
                append($$, SET, $6);
                append($$, STORE, iterators->pos + 1);
                append_all($$, $8);
                append($$, LOAD, iterators->pos);
                append($$, ADDC, $5);
                append($$, STORE, iterators->pos);
                append($$, SUB, iterators->pos + 1);
                append($$, JZERO - $5, 2); // JZERO = 15 -> JZERO - 1 = 14 = JPOS && JZERO - -1 = 16 = JNEG
                append($$, JUMP, -$$->no_lines + 4);
            } else if ($6 == $4) {
                append($$, SET, $4);
                append($$, STORE, iterators->pos);
                append_all($$, $8);
            }
        }
        struct iterator* tmp = iterators;
        iterators = iterators->next;
        delete tmp;
    }
    | FOR iidentifier FROM number updown identifier DO commands ENDFOR {
        $$ = new assembly;
        if ($6->type == VAR_TYPE && $6->pos == iterators->pos) {
            fprintf(stderr, "Trying to set for loop range using its iterator at line %d what is forbidden\n", yylineno);
            exit(-1);
        } else if ($8->no_lines > 0) {
            if ($6->type == ARG_TYPE) {
                append($$, LOADA, $6->pos);
            } else if ($6->type == ARR_TYPE) {
                append_all($$, $6->code);
                append($$, LOADI, 0);
            } else {
                append($$, LOAD, $6->pos);
            }
            append($$, STORE, iterators->pos + 1);
            append($$, SET, $4);
            int no_skip_lines = $$->no_lines;
            append($$, STORE, iterators->pos);
            append($$, SUB, iterators->pos + 1);
            append($$, JZERO - $5, $8->no_lines + 4); // JZERO = 15 -> JZERO - 1 = 14 = JPOS && JZERO - -1 = 16 = JNEG
            append_all($$, $8);
            append($$, LOAD, iterators->pos);
            append($$, ADDC, $5);
            append($$, JUMP, -$$->no_lines + no_skip_lines);
        }
        struct iterator* tmp = iterators;
        iterators = iterators->next;
        delete tmp;
    }
    | FOR iidentifier FROM identifier updown number DO commands ENDFOR {
        $$ = new assembly;
        if ($4->type == VAR_TYPE && $4->pos == iterators->pos) {
            fprintf(stderr, "Trying to set for loop range using its iterator at line %d what is forbidden\n", yylineno);
            exit(-1);
        } else if ($8->no_lines > 0) {
            append($$, SET, $6);
            append($$, STORE, iterators->pos + 1);
            if ($4->type == ARG_TYPE) {
                append($$, LOADA, $4->pos);
            } else if ($4->type == ARR_TYPE) {
                append_all($$, $4->code);
                append($$, LOADI, 0);
            } else {
                append($$, LOAD, $4->pos);
            }
            int no_skip_lines = $$->no_lines;
            append($$, STORE, iterators->pos);
            append($$, SUB, iterators->pos + 1);
            append($$, JZERO - $5, $8->no_lines + 4); // JZERO = 15 -> JZERO - 1 = 14 = JPOS && JZERO - -1 = 16 = JNEG
            append_all($$, $8);
            append($$, LOAD, iterators->pos);
            append($$, ADDC, $5);
            append($$, JUMP, -$$->no_lines + no_skip_lines);
        }
        struct iterator* tmp = iterators;
        iterators = iterators->next;
        delete tmp;
    }
    | FOR iidentifier FROM identifier updown identifier DO commands ENDFOR {
        $$ = new assembly;
        if ($4->type == VAR_TYPE && $4->pos == iterators->pos) {
            fprintf(stderr, "Trying to set for loop range using its iterator at line %d what is forbidden\n", yylineno);
            exit(-1);
        } else if ($6->type == VAR_TYPE && $6->pos == iterators->pos) {
            fprintf(stderr, "Trying to set for loop range using its iterator at line %d what is forbidden\n", yylineno);
            exit(-1);
        } else if ($8->no_lines > 0) {
            if ($6->type == ARG_TYPE) {
                append($$, LOADA, $6->pos);
            } else if ($6->type == ARR_TYPE) {
                append_all($$, $6->code);
                append($$, LOADI, 0);
            } else {
                append($$, LOAD, $6->pos);
            }
            append($$, STORE, iterators->pos + 1);
            if ($4->type == ARG_TYPE) {
                append($$, LOADA, $4->pos);
            } else if ($4->type == ARR_TYPE) {
                append_all($$, $4->code);
                append($$, LOADI, 0);
            } else {
                append($$, LOAD, $4->pos);
            }
            int no_skip_lines = $$->no_lines;
            append($$, STORE, iterators->pos);
            append($$, SUB, iterators->pos + 1);
            append($$, JZERO - $5, $8->no_lines + 4); // JZERO = 15 -> JZERO - 1 = 14 = JPOS && JZERO - -1 = 16 = JNEG
            append_all($$, $8);
            append($$, LOAD, iterators->pos);
            append($$, ADDC, $5);
            append($$, JUMP, -$$->no_lines + no_skip_lines);
        }
        struct iterator* tmp = iterators;
        iterators = iterators->next;
        delete tmp;
    }
    | PID POPEN args PCLOSE ENDL {
        struct proc_id* tmp = proc_ids;
        while (tmp != nullptr && strcmp(tmp->name, $1) != 0) {
            tmp = tmp->next;
        }
        if (tmp == nullptr) {
            fprintf(stderr, "Procedure %s encountered at line %d has not been declared\n", $1, yylineno);
            exit(-1);
        }
        long long proc_line = 0;
        struct proc_id* tmp2 = tmp->next;
        while (tmp2 != nullptr) {
            proc_line += tmp2->no_lines;
            tmp2 = tmp2->next;
        }
        $$ = new assembly;
        struct arg_id* required = tmp->arg_ids;
        struct arg_id* given = $3;
        while (required != nullptr && given != nullptr) {
            if (required->type == ARR_TYPE) {
                struct array_id* arr = array_ids;
                while (arr != nullptr) {
                    if (strcmp(arr->name, given->name) == 0) {
                        if (scope != nullptr && arr->pos < scope->arg_end) {
                            append($$, LOAD, arr->pos);
                        } else {
                            append($$, SET, arr->pos);
                        }
                        append($$, STORE, required->pos);
                        break;
                    }
                    arr = arr->next;
                }
                if (arr == nullptr) {
                    fprintf(stderr, "Array %s encountered at line %d has not been declared\n", $1, yylineno);
                    exit(-1);
                }
            } else {
                struct iterator* iter = iterators;
                while (iter != nullptr) {
                    if (strcmp(iter->name, given->name) == 0) {
                        fprintf(stderr, "Trying to use for loop iterator %s as procedure argument at line %d what is forbidden\n", given->name, yylineno);
                        exit(-1);
                    }
                    iter = iter->next;
                }
                struct var_id* var = var_ids;
                while (var != nullptr) {
                    if (strcmp(var->name, given->name) == 0) {
                        if (scope != nullptr && var->pos < scope->arg_end) {
                            /*if (required->type == IN_TYPE) {
                                append($$, LOADA, var->pos);
                            } else {
                                append($$, LOAD, var->pos);
                                make_out(var->pos);
                            }*/
                            append($$, LOAD, var->pos);
                        } else {
                            /*if (required->type == IN_TYPE) {
                                append($$, LOAD, var->pos);
                                var->initialized = true;
                            } else {
                                append($$, SET, var->pos);
                                var->initialized = true;
                            }*/
                            append($$, SET, var->pos);
                            var->initialized = true;
                        }
                        append($$, STORE, required->pos);
                        break;
                    }
                    var = var->next;
                }
                if (var == nullptr) {
                    fprintf(stderr, "Variable %s encountered at line %d has not been declared\n", given->name, yylineno);
                    exit(-1);
                }
            }
            required = required->next;
            given = given->next;
        }
        if (required != nullptr || given != nullptr) {
            fprintf(stderr, "Procedure %s at line %d received different number of arguments than declared\n", $1, yylineno);
            exit(-1);
        }
        append($$, GETLINE, 0);
        append($$, STORE, tmp->rtrn);
        append($$, JPROC, proc_line);
    }
    | READ sidentifier ENDL {
        $$ = new assembly;
        if ($2->type == VAR_TYPE) {
            append($$, GET, $2->pos);
        } else if ($2->type == ARG_TYPE) {
            append($$, GET, 0);
            append($$, STOREA, $2->pos);
        } else if ($2->type == ARR_TYPE) {
            append_all($$, $2->code);
            append($$, STORE, 1);
            append($$, GET, 0);
            append($$, STOREI, 1);
        }
    }
    | WRITE number ENDL {
        $$ = new assembly;
        append($$, PUTC, $2);
    }
    | WRITE identifier ENDL {
        $$ = new assembly;
        if ($2->type == ARG_TYPE) {
            append($$, LOADA, $2->pos);
            append($$, PUT, 0);
        } else if ($2->type == ARR_TYPE) {
            append_all($$, $2->code);
            append($$, LOADI, 0);
            append($$, PUT, 0);
        } else {
            append($$, PUT, $2->pos);
        }
    }
;

updown:
    TO {
        $$ = 1;
    }
    | DOWNTO {
        $$ = -1;
    }
;

expression:
    number {
        $$ = new assembly;
        append($$, SET, $1);
    }
    | identifier {
        $$ = new assembly;
        if ($1->type == ARG_TYPE) {
            append($$, LOADA, $1->pos);
        } else if ($1->type == ARR_TYPE) {
            append_all($$, $1->code);
            append($$, LOADI, 0);
        } else {
            append($$, LOAD, $1->pos);
        }
    }
    | number PLUS number {
        $$ = new assembly;
        int test = is_sum_in_range($1, $3);
        if (test == 0) {
            append($$, SET, $1 + $3);
        } else if (test == 1) {
            append($$, SET, $1 - LLONG_MAX + $3);
            append($$, ADDC, LLONG_MAX);
        } else if (test == -1) {
            append($$, SET, $1 + LLONG_MAX + $3);
            append($$, ADDC, -LLONG_MAX);
        }
    }
    | identifier PLUS number {
        $$ = new assembly;
        if ($1->type == ARG_TYPE) {
            if ($3 != 0) {
                append($$, SET, $3);
                append($$, ADDA, $1->pos);
            } else {
                append($$, LOADA, $1->pos);
            }
        } else if ($1->type == ARR_TYPE) {
            append_all($$, $1->code);
            append($$, LOADI, 0);
            if ($3 != 0) {
                append($$, ADDC, $3);
            }
        } else {
            if ($3 != 0) {
                append($$, SET, $3);
                append($$, ADD, $1->pos);
            } else {
                append($$, LOAD, $1->pos);
            }
        }
    }
    | number PLUS identifier {
        $$ = new assembly;
        if ($3->type == ARG_TYPE) {
            if ($3 != 0) {
                append($$, SET, $1);
                append($$, ADDA, $3->pos);
            } else {
                append($$, LOADA, $3->pos);
            }
        } else if ($3->type == ARR_TYPE) {
            append_all($$, $3->code);
            append($$, LOADI, 0);
            if ($3 != 0) {
                append($$, ADDC, $1);
            }
        } else {
            if ($3 != 0) {
                append($$, SET, $1);
                append($$, ADD, $3->pos);
            } else {
                append($$, LOAD, $3->pos);
            }
        }
    }
    | identifier PLUS identifier {
        $$ = new assembly;
        if ($1->type == ARR_TYPE) {
            append_all($$, $1->code);
            if ($3->type == ARG_TYPE) {
                append($$, LOADI, 0);
                append($$, ADDA, $3->pos);
            } else if ($3->type == ARR_TYPE) {
                append($$, STORE, 1);
                append_all($$, $3->code);
                append($$, LOADI, 0);
                append($$, ADDI, 1);
            } else {
                append($$, LOADI, 0);
                append($$, ADD, $3->pos);
            }
        } else if ($3->type == ARR_TYPE) {
            append_all($$, $3->code);
            append($$, LOADI, 0);
            if ($3->type == ARG_TYPE) {
                append($$, ADDA, $3->pos);
            } else {
                append($$, ADD, $3->pos);
            }
        } else {
            if ($1->type == ARG_TYPE) {
                append($$, LOADA, $1->pos);
            } else {
                append($$, LOAD, $1->pos);
            }
            if ($3->type == ARG_TYPE) {
                append($$, ADDA, $3->pos);
            } else {
                append($$, ADD, $3->pos);
            }
        }
    }
    | number MINUS number {
        $$ = new assembly;
        int test = is_sum_in_range($1, -$3);
        if (test == 0) {
            append($$, SET, $1 - $3);
        } else if (test == 1) {
            append($$, SET, $1 - LLONG_MAX - $3);
            append($$, ADDC, LLONG_MAX);
        } else if (test == -1) {
            append($$, SET, $1 + LLONG_MAX - $3);
            append($$, ADDC, -LLONG_MAX);
        }
    }
    | identifier MINUS number {
        $$ = new assembly;
        if ($1->type == ARG_TYPE) {
            if ($3 != 0) {
                append($$, SET, -$3);
                append($$, ADDA, $1->pos);
            } else {
                append($$, LOADA, $1->pos);
            }
        } else if ($1->type == ARR_TYPE) {
            append_all($$, $1->code);
            append($$, LOADI, 0);
            if ($3 != 0) {
                append($$, ADDC, -$3);
            }
        } else {
            if ($3 != 0) {
                append($$, SET, -$3);
                append($$, ADD, $1->pos);
            } else {
                append($$, LOAD, $1->pos);
            }
        }
    }
    | number MINUS identifier {
        $$ = num_minus_ident($1, $3);
    }
    | identifier MINUS identifier {
        $$ = ident_minus_ident($1, $3);
    }
    | number TIMES number {
        $$ = new assembly;
        unsigned long long high, low, ua, ub, al, ah, bl, bh, ll, lh, hl, hh;
        if ($1 > 0) {
            ua = $1;
        } else {
            ua = -$1;
        }
        if ($3 > 0) {
            ub = $3;
        } else {
            ub = -$3;
        }
        if ($1 == 0 || $3 == 0) {
            append($$, SET, 0);
        } else if (ua < LLONG_MAX / ub || (ua == LLONG_MAX / ub && LLONG_MAX % ub == 0)) {
            append($$, SET, $1 * $3);
        } else {
            ah = ua >> 32;
            al = ua & 0xffffffff;
            bh = ub >> 32;
            bl = ub & 0xffffffff;
            ll = al * bl;
            lh = al * bh;
            hl = ah * bl;
            hh = ah * bh;
            high = hh + ((lh + hl) >> 32);
            low = (((lh + hl) & 0xffffffff) << 32);
            if (low > 0xffffffffffffffff - ll) high += 1;
            low += ll;
            if (high == 0) {
                if (($1 > 0) == ($3 > 0)) {
                    append($$, SET, low - LLONG_MAX);
                    append($$, ADDC, LLONG_MAX);
                } else {
                    append($$, SET, -(long long)(low - LLONG_MAX));
                    append($$, ADDC, -LLONG_MAX);
                }
            } else {
                int k = 64;
                while (high >> 62 == 0) {
                    high = (high << 1);
                    k--;
                }
                unsigned long long mask = 0xffffffffffffffff;
                high += (low & ~(mask >> (64 - k))) >> k;
                low = low & (mask >> (64 - k));
                if (($1 > 0) == ($3 > 0)) {
                    append($$, SET, high);
                    for (int i = 0; i < k; ++i) {
                        append($$, ADD, 0);
                    }
                    append($$, ADDC, low);
                } else {
                    append($$, SET, -high);
                    for (int i = 0; i < k; ++i) {
                        append($$, ADD, 0);
                    }
                    append($$, ADDC, -low);
                }
            }
        }
    }
    | identifier TIMES number {
        $$ = new assembly;
        if ($3 == 0) {
            append($$, SET, 0);
        } else {
            long long tms;
            if ($3 > 0) {
                if ($1->type == ARR_TYPE) {
                    append_all($$, $1->code);
                    append($$, LOADI, 0);
                } else if ($1->type == ARG_TYPE) {
                    append($$, LOADA, $1->pos);
                } else {
                    append($$, LOAD, $1->pos);
                }
                tms = $3;
            } else {
                if ($1->type == ARR_TYPE) {
                    append_all($$, $1->code);
                    append($$, STORE, 1);
                    append($$, SET, 0);
                    append($$, SUBI, 1);
                } else if ($1->type == ARG_TYPE) {
                    append($$, SET, 0);
                    append($$, SUBA, $1->pos);
                } else {
                    append($$, SET, 0);
                    append($$, SUB, $1->pos);
                }
                tms = -$3;
            }
            append_all($$, multiply_by_number(tms));
        }
    }
    | number TIMES identifier {
        $$ = new assembly;
        if ($1 == 0) {
            append($$, SET, 0);
        } else {
            long long tms;
            if ($1 > 0) {
                if ($3->type == ARR_TYPE) {
                    append_all($$, $3->code);
                    append($$, LOADI, 0);
                } else if ($3->type == ARG_TYPE) {
                    append($$, LOADA, $3->pos);
                } else {
                    append($$, LOAD, $3->pos);
                }
                tms = $1;
            } else {
                if ($3->type == ARR_TYPE) {
                    append_all($$, $3->code);
                    append($$, STORE, 1);
                    append($$, SET, 0);
                    append($$, SUBI, 1);
                } else if ($3->type == ARG_TYPE) {
                    append($$, SET, 0);
                    append($$, SUBA, $3->pos);
                } else {
                    append($$, SET, 0);
                    append($$, SUB, $3->pos);
                }
                tms = -$1;
            }
            append_all($$, multiply_by_number(tms));
        }
    }
    | identifier TIMES identifier {
        if (!need_multiplication) {
            add_multiplication();
        }
        $$ = new assembly;
        if ($1->type == ARR_TYPE) {
            append_all($$, $1->code);
            append($$, LOADI, 0);
        } else if ($1->type == ARG_TYPE) {
            append($$, LOADA, $1->pos);
        } else {
            append($$, LOAD, $1->pos);
        }
        assembly* tmp = new assembly;
        append(tmp, STORE, a);
        if ($3->type == ARR_TYPE) {
            append_all(tmp, $3->code);
            append(tmp, LOADI, 0);
        } else if ($3->type == ARG_TYPE) {
            append(tmp, LOADA, $3->pos);
        } else {
            append(tmp, LOAD, $3->pos);
        }
        append(tmp, JZERO, 5);
        append(tmp, STORE, b);
        append(tmp, GETLINE, 0);
        append(tmp, STORE, rtrn);
        append(tmp, JPROC, -1);
        append($$, JZERO, tmp->no_lines + 1);
        append_all($$, tmp);
    }
    | number DIVIDE number {
        long long result = 0;
        if ($3 != 0) {
            result = $1 / $3;
            if (result < 0 && $1 % $3 != 0) {
                result -= 1;
            }
        }
        $$ = new assembly;
        append($$, SET, result);
    }
    | identifier DIVIDE number {
        $$ = new assembly;
        if ($3 == 0) {
            append($$, SET, 0);
        } else {
            long long a1;
            if ($3 > 0) {
                a1 = $3;
            } else {
                a1 = -$3;
            }
            int log = 0;
            long long a2 = a1;
            while (a2 > 1) {
                a2 >>= 1;
                log += 1;
            }
            assembly* tmp = new assembly;
            if (a1 & (a1 - 1) == 0 && log <= 10) {
                if ($3 > 0) {
                    if ($1->type == ARR_TYPE) {
                        append_all($$, $1->code);
                        append($$, LOADI, 0);
                    } else if ($1->type == ARG_TYPE) {
                        append($$, LOADA, $1->pos);
                    } else {
                        append($$, LOAD, $1->pos);
                    }
                } else {
                    if ($1->type == ARR_TYPE) {
                        append_all($$, $1->code);
                        append($$, STORE, 1);
                        append($$, SET, 0);
                        append($$, SUBI, 1);
                    } else if ($1->type == ARG_TYPE) {
                        append($$, SET, 0);
                        append($$, SUBA, $1->pos);
                    } else {
                        append($$, SET, 0);
                        append($$, SUB, $1->pos);
                    }
                }
                for (int i = 0; i < log; ++i) {
                    append(tmp, HALF, 0);
                }
            } else {
                if (!need_division) {
                    add_division();
                }
                if ($1->type == ARR_TYPE) {
                    append_all($$, $1->code);
                    append($$, LOADI, 0);
                } else if ($1->type == ARG_TYPE) {
                    append($$, LOADA, $1->pos);
                } else {
                    append($$, LOAD, $1->pos);
                }
                append(tmp, STORE, a);
                append(tmp, SET, $3);
                append(tmp, STORE, b);
                append(tmp, GETLINE, 0);
                append(tmp, STORE, rtrn);
                append(tmp, JPROC, -2);
            }
            append($$, JZERO, tmp->no_lines + 1);
            append_all($$, tmp);
        }
    }
    | number DIVIDE identifier {
        $$ = new assembly;
        if ($1 == 0) {
            append($$, SET, 0);
        } else if ($1 == -1) {
            if ($3->type == ARR_TYPE) {
                append_all($$, $3->code);
                append($$, LOADI, 0);
            } else if ($3->type == ARG_TYPE) {
                append($$, LOADA, $3->pos);
            } else {
                append($$, LOAD, $3->pos);
            }
            append($$, JZERO, 9);
            append($$, JPOS, 5);
            append($$, ADDC, 1);
            append($$, JZERO, 5);
            append($$, SET, 0);
            append($$, JUMP, 4);
            append($$, SET, -1);
            append($$, JUMP, 2);
            append($$, SET, 1);
        } else if ($1 == 1) {
            if ($3->type == ARR_TYPE) {
                append_all($$, $3->code);
                append($$, LOADI, 0);
            } else if ($3->type == ARG_TYPE) {
                append($$, LOADA, $3->pos);
            } else {
                append($$, LOAD, $3->pos);
            }
            append($$, JZERO, 9);
            append($$, JNEG, 5);
            append($$, ADDC, -1);
            append($$, JZERO, 5);
            append($$, SET, 0);
            append($$, JUMP, 4);
            append($$, SET, -1);
            append($$, JUMP, 2);
            append($$, SET, 1);
        } else {
            if (!need_division) {
                add_division();
            }
            append($$, SET, $1);
            append($$, STORE, a);
            if ($3->type == ARR_TYPE) {
                append_all($$, $3->code);
                append($$, LOADI, 0);
            } else if ($3->type == ARG_TYPE) {
                append($$, LOADA, $3->pos);
            } else {
                append($$, LOAD, $3->pos);
            }
            append($$, JZERO, 5);
            append($$, STORE, b);
            append($$, GETLINE, 0);
            append($$, STORE, rtrn);
            append($$, JPROC, -2);
        }
    }
    | identifier DIVIDE identifier {
        bool skipped = false;
        if ($1->type == $3->type && $1->type == ARR_TYPE) {
            struct line* cmpa = $1->code->first;
            struct line* cmpb = $3->code->first;
            while (cmpa != nullptr && cmpb != nullptr && cmpa->command == cmpb->command && cmpa->val == cmpb->val) {
                cmpa = cmpa->next;
                cmpb = cmpb->next;
            }
            if (cmpa == nullptr && cmpb == nullptr) {
                append($$, SET, 1);
                skipped = true;
            }
        }
        if (!skipped && $1->type == $3->type && $1->type != ARR_TYPE && $1->pos == $3->pos) {
            append($$, SET, 1);
            skipped = true;
        }
        if (!skipped) {
            if (!need_division) {
                add_division();
            }
            $$ = new assembly;
            if ($1->type == ARR_TYPE) {
                append_all($$, $1->code);
                append($$, LOADI, 0);
            } else if ($1->type == ARG_TYPE) {
                append($$, LOADA, $1->pos);
            } else {
                append($$, LOAD, $1->pos);
            }
            assembly* tmp = new assembly;
            append(tmp, STORE, a);
            if ($3->type == ARR_TYPE) {
                append_all(tmp, $3->code);
                append(tmp, LOADI, 0);
            } else if ($3->type == ARG_TYPE) {
                append(tmp, LOADA, $3->pos);
            } else {
                append(tmp, LOAD, $3->pos);
            }
            append(tmp, JZERO, 5);
            append(tmp, STORE, b);
            append(tmp, GETLINE, 0);
            append(tmp, STORE, rtrn);
            append(tmp, JPROC, -2);
            append($$, JZERO, tmp->no_lines + 1);
            append_all($$, tmp);
        }
    }
    | number MOD number {
        long long result = 0;
        if ($3 != 0) {
            result = $1 % $3;
            if (result != 0 && (result > 0) != ($3 > 0)) {
                result += $3;
            }
        }
        $$ = new assembly;
        append($$, SET, result);
    }
    | identifier MOD number {
        $$ = new assembly;
        if ($3 == 0 || $3 == 1 || $3 == -1) {
            append($$, SET, 0);
        } else {
            long long a1;
            if ($3 > 0) {
                a1 = $3;
            } else {
                a1 = -$3;
            }
            int log = 0;
            long long a2 = a1;
            while (a2 > 1) {
                a2 >>= 1;
                log += 1;
            }
            assembly* tmp = new assembly;
            if (a1 & (a1 - 1) == 0 && log <= 5) {
                if ($1->type == ARR_TYPE) {
                    append_all($$, $1->code);
                    append($$, LOADI, 0);
                } else if ($1->type == ARG_TYPE) {
                    append($$, LOADA, $1->pos);
                } else {
                    append($$, LOAD, $1->pos);
                }
                append(tmp, STORE, 1);
                for (int i = 0; i < log; ++i) {
                    append(tmp, HALF, 0);
                }
                for (int i = 0; i < log; ++i) {
                    append(tmp, ADD, 0);
                }
                append(tmp, STORE, 2);
                append(tmp, LOAD, 1);
                append(tmp, SUB, 2);
                if ($3 < 0) {
                    append(tmp, JZERO, 2);
                    append(tmp, ADDC, $3);
                }
            } else {
                if (!need_modulus) {
                    add_modulus();
                }
                if ($1->type == ARR_TYPE) {
                    append_all($$, $1->code);
                    append($$, LOADI, 0);
                } else if ($1->type == ARG_TYPE) {
                    append($$, LOADA, $1->pos);
                } else {
                    append($$, LOAD, $1->pos);
                }
                append(tmp, STORE, a);
                append(tmp, SET, $3);
                append(tmp, STORE, b);
                append(tmp, GETLINE, 0);
                append(tmp, STORE, rtrn);
                append(tmp, JPROC, -3);
            }
            append($$, JZERO, tmp->no_lines + 1);
            append_all($$, tmp);
        }
    }
    | number MOD identifier {
        $$ = new assembly;
        if ($1 == 0) {
            append($$, SET, 0);
        } else {
            if (!need_modulus) {
                add_modulus();
            }
            $$ = new assembly;
            append($$, SET, $1);
            append($$, STORE, a);
            if ($3->type == ARR_TYPE) {
                append_all($$, $3->code);
                append($$, LOADI, 0);
            } else if ($3->type == ARG_TYPE) {
                append($$, LOADA, $3->pos);
            } else {
                append($$, LOAD, $3->pos);
            }
            append($$, JZERO, 5);
            append($$, STORE, b);
            append($$, GETLINE, 0);
            append($$, STORE, rtrn);
            append($$, JPROC, -3);
        }
    }
    | identifier MOD identifier {
        bool skipped = false;
        if ($1->type == $3->type && $1->type == ARR_TYPE) {
            struct line* cmpa = $1->code->first;
            struct line* cmpb = $3->code->first;
            while (cmpa != nullptr && cmpb != nullptr && cmpa->command == cmpb->command && cmpa->val == cmpb->val) {
                cmpa = cmpa->next;
                cmpb = cmpb->next;
            }
            if (cmpa == nullptr && cmpb == nullptr) {
                append($$, SET, 0);
                skipped = true;
            }
        }
        if (!skipped && $1->type == $3->type && $1->type != ARR_TYPE && $1->pos == $3->pos) {
            append($$, SET, 0);
            skipped = true;
        }
        if (!skipped) {
            if (!need_modulus) {
                add_modulus();
            }
            $$ = new assembly;
            if ($1->type == ARR_TYPE) {
                append_all($$, $1->code);
                append($$, LOADI, 0);
            } else if ($1->type == ARG_TYPE) {
                append($$, LOADA, $1->pos);
            } else {
                append($$, LOAD, $1->pos);
            }
            assembly* tmp = new assembly;
            append(tmp, STORE, a);
            if ($3->type == ARR_TYPE) {
                append_all(tmp, $3->code);
                append(tmp, LOADI, 0);
            } else if ($3->type == ARG_TYPE) {
                append(tmp, LOADA, $3->pos);
            } else {
                append(tmp, LOAD, $3->pos);
            }
            append(tmp, JZERO, 5);
            append(tmp, STORE, b);
            append(tmp, GETLINE, 0);
            append(tmp, STORE, rtrn);
            append(tmp, JPROC, -3);
            append($$, JZERO, tmp->no_lines + 1);
            append_all($$, tmp);
        }
    }
;

condition:
    number EQ number {
        $$ = new assembly;
        if ($1 == $3) {
            $$->no_lines = -1;
        } else {
            $$->no_lines = -2;
        }
    }
    | identifier EQ number {
        $$ = new assembly;
        if ($3 != 0) {
            append_all($$, num_minus_ident($3, $1));
        } else if ($1->type == ARG_TYPE) {
            append($$, LOADA, $1->pos);
        } else if ($1->type == ARR_TYPE) {
            append_all($$, $1->code);
            append($$, LOADI, 0);
        } else {
            append($$, LOAD, $1->pos);
        }
        append($$, JZERO, 2);
        append_jump($$, JUMP);
    }
    | number EQ identifier {
        $$ = new assembly;
        if ($1 != 0) {
            append_all($$, num_minus_ident($1, $3));
        } else if ($3->type == ARG_TYPE) {
            append($$, LOADA, $3->pos);
        } else if ($3->type == ARR_TYPE) {
            append_all($$, $3->code);
            append($$, LOADI, 0);
        } else {
            append($$, LOAD, $3->pos);
        }
        append($$, JZERO, 2);
        append_jump($$, JUMP);
    }
    | identifier EQ identifier {
        $$ = ident_minus_ident($1, $3);
        if ($$->first->next == nullptr && $$->first->command == SET && $$->first->val == 0) {
            $$->no_lines = -1;
        } else {
            append($$, JZERO, 2);
            append_jump($$, JUMP);
        }
    }
    | number NEQ number {
        $$ = new assembly;
        if ($1 != $3) {
            $$->no_lines = -1;
        } else {
            $$->no_lines = -2;
        }
    }
    | identifier NEQ number {
        $$ = new assembly;
        if ($3 != 0) {
            append_all($$, num_minus_ident($3, $1));
        } else if ($1->type == ARG_TYPE) {
            append($$, LOADA, $1->pos);
        } else if ($1->type == ARR_TYPE) {
            append_all($$, $1->code);
            append($$, LOADI, 0);
        } else {
            append($$, LOAD, $1->pos);
        }
        append_jump($$, JZERO);
    }
    | number NEQ identifier {
        $$ = new assembly;
        if ($1 != 0) {
            append_all($$, num_minus_ident($1, $3));
        } else if ($3->type == ARG_TYPE) {
            append($$, LOADA, $3->pos);
        } else if ($3->type == ARR_TYPE) {
            append_all($$, $3->code);
            append($$, LOADI, 0);
        } else {
            append($$, LOAD, $3->pos);
        }
        append_jump($$, JZERO);
    }
    | identifier NEQ identifier {
        $$ = ident_minus_ident($1, $3);
        if ($$->first->next == nullptr && $$->first->command == SET && $$->first->val == 0) {
            $$->no_lines = -2;
        } else {
            append_jump($$, JZERO);
        }
    }
    | number GR number {
        $$ = new assembly;
        if ($1 > $3) {
            $$->no_lines = -1;
        } else {
            $$->no_lines = -2;
        }
    }
    | identifier GR number {
        $$ = new assembly;
        if ($3 != 0) {
            append_all($$, num_minus_ident($3, $1));
            append($$, JNEG, 2);
        } else if ($1->type == ARG_TYPE) {
            append($$, LOADA, $1->pos);
            append($$, JPOS, 2);
        } else if ($1->type == ARR_TYPE) {
            append_all($$, $1->code);
            append($$, LOADI, 0);
            append($$, JPOS, 2);
        } else {
            append($$, LOAD, $1->pos);
            append($$, JPOS, 2);
        }
        append_jump($$, JUMP);
    }
    | number GR identifier {
        $$ = new assembly;
        if ($1 != 0) {
            append_all($$, num_minus_ident($1, $3));
            append($$, JPOS, 2);
        } else if ($3->type == ARG_TYPE) {
            append($$, LOADA, $3->pos);
            append($$, JNEG, 2);
        } else if ($3->type == ARR_TYPE) {
            append_all($$, $3->code);
            append($$, LOADI, 0);
            append($$, JNEG, 2);
        } else {
            append($$, LOAD, $3->pos);
            append($$, JNEG, 2);
        }
        append_jump($$, JUMP);
    }
    | identifier GR identifier {
        $$ = ident_minus_ident($1, $3);
        if ($$->first->next == nullptr && $$->first->command == SET && $$->first->val == 0) {
            $$->no_lines = -2;
        } else {
            append($$, JPOS, 2);
            append_jump($$, JUMP);
        }
    }
    | number LS number {
        $$ = new assembly;
        if ($1 < $3) {
            $$->no_lines = -1;
        } else {
            $$->no_lines = -2;
        }
    }
    | identifier LS number {
        $$ = new assembly;
        if ($3 != 0) {
            append_all($$, num_minus_ident($3, $1));
            append($$, JPOS, 2);
        } else if ($1->type == ARG_TYPE) {
            append($$, LOADA, $1->pos);
            append($$, JNEG, 2);
        } else if ($1->type == ARR_TYPE) {
            append_all($$, $1->code);
            append($$, LOADI, 0);
            append($$, JNEG, 2);
        } else {
            append($$, LOAD, $1->pos);
            append($$, JNEG, 2);
        }
        append_jump($$, JUMP);
    }
    | number LS identifier {
        $$ = new assembly;
        if ($1 != 0) {
            append_all($$, num_minus_ident($1, $3));
            append($$, JNEG, 2);
        } else if ($3->type == ARG_TYPE) {
            append($$, LOADA, $3->pos);
            append($$, JPOS, 2);
        } else if ($3->type == ARR_TYPE) {
            append_all($$, $3->code);
            append($$, LOADI, 0);
            append($$, JPOS, 2);
        } else {
            append($$, LOAD, $3->pos);
            append($$, JPOS, 2);
        }
        append_jump($$, JUMP);
    }
    | identifier LS identifier {
        $$ = ident_minus_ident($1, $3);
        if ($$->first->next == nullptr && $$->first->command == SET && $$->first->val == 0) {
            $$->no_lines = -2;
        } else {
            append($$, JNEG, 2);
            append_jump($$, JUMP);
        }
    }
    | number GEQ number {
        $$ = new assembly;
        if ($1 >= $3) {
            $$->no_lines = -1;
        } else {
            $$->no_lines = -2;
        }
    }
    | identifier GEQ number {
        $$ = new assembly;
        if ($3 != 0) {
            append_all($$, num_minus_ident($3, $1));
            append_jump($$, JPOS);
        } else if ($1->type == ARG_TYPE) {
            append($$, LOADA, $1->pos);
            append_jump($$, JNEG);
        } else if ($1->type == ARR_TYPE) {
            append_all($$, $1->code);
            append($$, LOADI, 0);
            append_jump($$, JNEG);
        } else {
            append($$, LOAD, $1->pos);
            append_jump($$, JNEG);
        }
    }
    | number GEQ identifier {
        $$ = new assembly;
        if ($1 != 0) {
            append_all($$, num_minus_ident($1, $3));
            append_jump($$, JNEG);
        } else if ($3->type == ARG_TYPE) {
            append($$, LOADA, $3->pos);
            append_jump($$, JPOS);
        } else if ($3->type == ARR_TYPE) {
            append_all($$, $3->code);
            append($$, LOADI, 0);
            append_jump($$, JPOS);
        } else {
            append($$, LOAD, $3->pos);
            append_jump($$, JPOS);
        }
    }
    | identifier GEQ identifier {
        $$ = ident_minus_ident($1, $3);
        if ($$->first->next == nullptr && $$->first->command == SET && $$->first->val == 0) {
            $$->no_lines = -1;
        } else {
            append_jump($$, JNEG);
        }
    }
    | number LEQ number {
        $$ = new assembly;
        if ($1 <= $3) {
            $$->no_lines = -1;
        } else {
            $$->no_lines = -2;
        }
    }
    | identifier LEQ number {
        $$ = new assembly;
        if ($3 != 0) {
            append_all($$, num_minus_ident($3, $1));
            append_jump($$, JNEG);
        } else if ($1->type == ARG_TYPE) {
            append($$, LOADA, $1->pos);
            append_jump($$, JPOS);
        } else if ($1->type == ARR_TYPE) {
            append_all($$, $1->code);
            append($$, LOADI, 0);
            append_jump($$, JPOS);
        } else {
            append($$, LOAD, $1->pos);
            append_jump($$, JPOS);
        }
    }
    | number LEQ identifier {
        $$ = new assembly;
        if ($1 != 0) {
            append_all($$, num_minus_ident($1, $3));
            append_jump($$, JPOS);
        } else if ($3->type == ARG_TYPE) {
            append($$, LOADA, $3->pos);
            append_jump($$, JNEG);
        } else if ($3->type == ARR_TYPE) {
            append_all($$, $3->code);
            append($$, LOADI, 0);
            append_jump($$, JNEG);
        } else {
            append($$, LOAD, $3->pos);
            append_jump($$, JNEG);
        }
    }
    | identifier LEQ identifier {
        $$ = ident_minus_ident($1, $3);
        if ($$->first->next == nullptr && $$->first->command == SET && $$->first->val == 0) {
            $$->no_lines = -1;
        } else {
            append_jump($$, JPOS);
        }
    }
;

number:
    NUMBER {
        $$ = $1;
    }
    | MINUS NUMBER {
        $$ = -$2;
    }
;

identifier:
    PID {
        struct iterator* tmpi = iterators;
        while (tmpi != nullptr) {
            if (strcmp(tmpi->name, $1) == 0) {
                $$->type = VAR_TYPE;
                $$->pos = tmpi->pos;
                break;
            }
            tmpi = tmpi->next;
        }
        if (tmpi == nullptr) {
            struct var_id* tmp = var_ids;
            while (tmp != nullptr) {
                if (strcmp(tmp->name, $1) == 0) {
                    if (scope != nullptr && tmp->pos < scope->arg_end) {
                        $$->type = ARG_TYPE;
                    } else if (tmp->initialized) {
                        $$->type = VAR_TYPE;
                    } else {
                        fprintf(stderr, "Variable %s used at line %d has not been initialized\n", $1, yylineno);
                        exit(-1);
                    }
                    $$->pos = tmp->pos;
                    break;
                }
                tmp = tmp->next;
            }
            if (tmp == nullptr) {
                fprintf(stderr, "Variable %s encountered at line %d has not been declared\n", $1, yylineno);
                exit(-1);
            }
        }
    }
    | PID TOPEN number TCLOSE {
        struct array_id* tmp = array_ids;
        while (tmp != nullptr) {
            if (strcmp(tmp->name, $1) == 0) {
                if (scope != nullptr && tmp->pos < scope->arg_end) {
                    $$->type = ARR_TYPE;
                    $$->code = append(new assembly, SET, $3);
                    append($$->code, ADD, tmp->pos);
                } else {
                    $$->type = VAR_TYPE;
                    $$->pos = tmp->pos + $3;
                }
                break;
            }
            tmp = tmp->next;
        }
        if (tmp == nullptr) {
            fprintf(stderr, "Array %s encountered at line %d has not been declared\n", $1, yylineno);
            exit(-1);
        }
    }
    | PID TOPEN PID TCLOSE {
        $$->type = ARR_TYPE;
        $$->code = new assembly;
        struct array_id* arr = array_ids;
        while (arr != nullptr) {
            if (strcmp(arr->name, $1) == 0) {
                if (scope != nullptr && arr->pos < scope->arg_end) {
                    append($$->code, LOAD, arr->pos);
                } else {
                    append($$->code, SET, arr->pos);
                }
                break;
            }
            arr = arr->next;
        }
        if (arr == nullptr) {
            fprintf(stderr, "Array %s encountered at line %d has not been declared\n", $1, yylineno);
            exit(-1);
        }
        struct iterator* iter = iterators;
        while (iter != nullptr) {
            if (strcmp(iter->name, $3) == 0) {
                append($$->code, ADD, iter->pos);
                break;
            }
            iter = iter->next;
        }
        if (iter == nullptr) {
            struct var_id* var = var_ids;
            while (var != nullptr) {
                if (strcmp(var->name, $3) == 0) {
                    if (scope != nullptr && var->pos < scope->arg_end) {
                        append($$->code, ADDA, var->pos);
                    } else if (var->initialized) {
                        append($$->code, ADD, var->pos);
                    } else {
                        fprintf(stderr, "Variable %s used at line %d has not been initialized\n", $3, yylineno);
                        exit(-1);
                    }
                    break;
                }
                var = var->next;
            }
            if (var == nullptr) {
                fprintf(stderr, "Variable %s encountered at line %d has not been declared\n", $3, yylineno);
                exit(-1);
            }
        }
    }
;

sidentifier:
    PID {
        struct iterator* tmpi = iterators;
        while (tmpi != nullptr) {
            if (strcmp(tmpi->name, $1) == 0) {
                fprintf(stderr, "Trying to assign value to for loop iterator %s at line %d what is forbidden\n", $1, yylineno);
                exit(-1);
            }
            tmpi = tmpi->next;
        }
        struct var_id* tmp = var_ids;
        while (tmp != nullptr) {
            if (strcmp(tmp->name, $1) == 0) {
                if (scope != nullptr && tmp->pos < scope->arg_end) {
                    $$->type = ARG_TYPE;
                    make_out(tmp->pos);
                } else {
                    $$->type = VAR_TYPE;
                    tmp->initialized = true;
                }
                $$->pos = tmp->pos;
                break;
            }
            tmp = tmp->next;
        }
        if (tmp == nullptr) {
            fprintf(stderr, "Variable %s encountered at line %d has not been declared\n", $1, yylineno);
            exit(-1);
        }
    }
    | PID TOPEN number TCLOSE {
        struct array_id* tmp = array_ids;
        while (tmp != nullptr) {
            if (strcmp(tmp->name, $1) == 0) {
                if (scope != nullptr && tmp->pos < scope->arg_end) {
                    $$->type = ARR_TYPE;
                    $$->code = append(new assembly, SET, $3);
                    append($$->code, ADD, tmp->pos);
                } else {
                    $$->type = VAR_TYPE;
                    $$->pos = tmp->pos + $3;
                }
                break;
            }
            tmp = tmp->next;
        }
        if (tmp == nullptr) {
            fprintf(stderr, "Array %s encountered at line %d has not been declared\n", $1, yylineno);
            exit(-1);
        }
    }
    | PID TOPEN PID TCLOSE {
        $$->type = ARR_TYPE;
        $$->code = new assembly;
        struct array_id* arr = array_ids;
        while (arr != nullptr) {
            if (strcmp(arr->name, $1) == 0) {
                if (scope != nullptr && arr->pos < scope->arg_end) {
                    append($$->code, LOAD, arr->pos);
                } else {
                    append($$->code, SET, arr->pos);
                }
                break;
            }
            arr = arr->next;
        }
        if (arr == nullptr) {
            fprintf(stderr, "Array %s encountered at line %d has not been declared\n", $1, yylineno);
            exit(-1);
        }
        struct iterator* iter = iterators;
        while (iter != nullptr) {
            if (strcmp(iter->name, $3) == 0) {
                append($$->code, ADD, iter->pos);
                break;
            }
            iter = iter->next;
        }
        if (iter == nullptr) {
            struct var_id* var = var_ids;
            while (var != nullptr) {
                if (strcmp(var->name, $3) == 0) {
                    if (scope != nullptr && var->pos < scope->arg_end) {
                        append($$->code, ADDA, var->pos);
                    } else if (var->initialized) {
                        append($$->code, ADD, var->pos);
                    } else {
                        fprintf(stderr, "Variable %s used at line %d has not been initialized\n", $3, yylineno);
                        exit(-1);
                    }
                    break;
                }
                var = var->next;
            }
            if (var == nullptr) {
                fprintf(stderr, "Variable %s encountered at line %d has not been declared\n", $3, yylineno);
                exit(-1);
            }
        }
    }
;

iidentifier:
    PID {
        check_for_name_duplicate(ITER_TYPE, $1);
        iterators = new iterator{strdup($1), first_empty_memory, iterators};
        first_empty_memory += 2;
    }
;

%%

void yyerror(const char* s) {
    fprintf(stderr, "YYError: %s at line %d\n", s, yylineno);
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <input_file> <output_file>\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    yyout_name = strdup(argv[2]);

    yyparse();
    fclose(yyin);
    return 0;
}
