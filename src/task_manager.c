#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>

typedef enum { TYPE_INT, TYPE_DOUBLE, TYPE_STRING } ReturnType;

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



static Task *task_list = NULL;
static int task_count = 0;

void resize_task_list() {
    task_count++;
    task_list = realloc(task_list, task_count * sizeof(Task));
    if (!task_list) {
        fprintf(stderr, "Out of memory!\n");
        exit(1);
    }
}


int queue_task(int id, lua_State *co, ReturnType type) {

    Task new_task = {id, co, 0, type};
    resize_task_list();
    task_list[task_count - 1] = new_task; // put new task at end
    // ...
    return 0;
}

void remove_element(int index)
{
   int i;
   for(i = index; i < task_count - 1; i++) task_list[i] = task_list[i + 1];
}

Task* vm_poll() {
    Task* tasks = malloc(sizeof(Task) * task_count);
    int count = 0;

    for (int i = 0; i < task_count - 1; i++) {
        if (task_list[i].completed == 1) {
            tasks[count] = task_list[i];
            count++;
        }
    }

    int i = 0;
    while(i < task_count) {
        if (task_list[i].completed == 1) {
            remove_element(i);
            i = 0;
        } else {
            i++;
        }
    }

    return tasks;
}

int complete_task(int id) {
    Task *task;
    for (int i = 0; i < task_count - 1; i++) {
        if (task_list[i].id == id) {
            // task = task_list[i];
            task = &task_list[i];
        }
    }

    if (task == NULL) {
        fprintf(stderr, "Couldn't find task with ID: %d", id);
        return 1;
    }

    switch(task->returntype) {
        case TYPE_INT: {
            task->i = lua_tointeger(task->co, -1);
            lua_pop(task->co, 1);
        };
        case TYPE_DOUBLE: {
            task->d = lua_tonumber(task->co, -1);
            lua_pop(task->co, 1);
        };
        case TYPE_STRING: {
            task->s = lua_tostring(task->co, -1);
            lua_pop(task->co, 1);
        };
    }

    task->completed = 1;

    return 0;
}
