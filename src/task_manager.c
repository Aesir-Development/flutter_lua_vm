#include "lua.h"
#include "lua_vm.h"
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

typedef struct {
    int count;
    Task *tasks;
} TaskArray;

static Task *task_list = NULL;
static int task_count = 0;

void resize_task_list() {
    task_count++;
    task_list = realloc(task_list, task_count * sizeof(Task));
    if (!task_list) {
        fprintf(stderr, "Out of memory!\n");
        // exit(1);
    }
}


int queue_task(int id, lua_State *co, ReturnType type) {
    fprintf(stderr, "TESTING\n");
    Print print = get_print();
    print(format("Type: %d", type));
    Task new_task = {.id=id, .co=co, .completed=0, .returntype=type};
    resize_task_list();
    task_list[task_count - 1] = new_task; // put new task at end
    return 0;
}

void remove_element(int index)
{
   int i;
   for(i = index; i < task_count - 1; i++) task_list[i] = task_list[i + 1];
}

TaskArray* vm_poll() {
    Task* tasks = malloc(sizeof(Task) * task_count);
    int count = 0;

    for (int i = 0; i < task_count; i++) {
        if (task_list[i].completed == 1) {
            tasks[count] = task_list[i];
            count++;
        }
    }

    int i = 0;
    while(i < task_count) {
        if (task_list[i].completed == 1) {
            remove_element(i);
            task_count--;
            i = 0;
        } else {
            i++;
        }
    }

    TaskArray *taskarr = malloc(sizeof(TaskArray));
    taskarr->tasks = tasks;
    taskarr->count = count;

    return taskarr;
}

int complete_task(int id) {
    Print print = get_print();

    int found = 0;
    Task *task;
    for (int i = 0; i < task_count; i++) {
        if (task_list[i].id == id) {
            // task = task_list[i];
            task = &task_list[i];
            found = 1;
        }
    }

    const char *info = format("Task ID: %d\nTask Status: %d\nTask Return Type: %d\n", task->id, task->completed, task->returntype);
    print(info);

    if (task == NULL || found == 0) {
        fprintf(stderr, "Couldn't find task with ID: %d", id);
        return 1;
    }

    print(format("Task return type: %d", task->returntype));

    switch(task->returntype) {
        case RET_INT: {
            task->i = lua_tointeger(task->co, -1);
            lua_pop(task->co, 1);
        };
        case RET_DOUBLE: {
            task->d = lua_tonumber(task->co, -1);
            lua_pop(task->co, 1);
        };
        case RET_STRING: {
            task->s = lua_tostring(task->co, -1);
            lua_pop(task->co, 1);
        };
    }

    task->completed = 1;

    return 0;
}
