#ifndef TASK_MANAGER
#define TASK_MANAGER

#include "lua.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>

typedef enum { RET_INT, RET_DOUBLE, RET_STRING } ReturnType;

typedef struct {
    int id;
    lua_State *co;
    int completed;
    ReturnType returntype;
    union {
        int i;
        double d;
        const char *s;
    };
} Task;

int queue_task(int id, lua_State *co, ReturnType type);
int complete_task(int id);
#endif
