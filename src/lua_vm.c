#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>

typedef void (*DartHttpCallback)(lua_State* L, const char* url);
typedef void (*Print)(const char* url);
static DartHttpCallback dart_callback = NULL;
static Print print = NULL;

typedef enum { TYPE_INT, TYPE_DOUBLE, TYPE_STRING } ArgType;
typedef struct {
    ArgType type;
    union {
        int i;
        double d;
        const char *s;
    };
} Variant;

void register_dart_callback(DartHttpCallback cb) {
    dart_callback = cb;
}

void register_print_function(Print pr) {
    print = pr;
}

char* format(const char *format, ...) {
    va_list args;
    va_start(args, format);

    // Determine the required size
    int size = vsnprintf(NULL, 0, format, args);
    va_end(args);

    if (size < 0) return NULL;

    char *s = malloc(size + 1);
    if (!s) return NULL;

    va_start(args, format);
    vsnprintf(s, size + 1, format, args);
    va_end(args);

    return s;
}

int vm_http_request(lua_State* L) {
    const char* url = luaL_checkstring(L, 1);

    if (dart_callback) {
        dart_callback(L, url); // Pass the coroutine to the dart function
    }

    // Yield this coroutine until response arrives
    return lua_yield(L, 0);
}

void vm_resume_http(lua_State *L, lua_State *co, char *data) {
    if (print) {
        print("Resuming HTTP coroutine");
    }

    if (!co) {
        fprintf(stderr, "Error: No coroutine waiting for HTTP response\n");
        return;
    }

    // Push response data onto the waiting coroutine's stack
    lua_pushstring(co, data);

    // Resume the coroutine with the response data
    int nresults = 0;
    int status = lua_resume(co, L, 1, &nresults);

    if (status == LUA_OK) {
        if (print) {
            print("HTTP coroutine completed successfully");
        }
        co = NULL;  // Clear the reference
    } else if (status == LUA_YIELD) {
        // Coroutine yielded again (shouldn't happen in this case)
        if (print) {
            print("HTTP coroutine yielded again");
        }
    } else {
        // Error occurred
        const char *err = lua_tostring(co, -1);
        fprintf(stderr, "Lua error in HTTP coroutine: %s\n", err);
        co = NULL;  // Clear the reference
    }
}


__attribute__((visibility("default")))
lua_State* vm_create() {
    puts("Creating VM");
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);

    // Register custom functions
    lua_register(L, "http_request", vm_http_request);

    return L;
}

__attribute__((visibility("default")))
int vm_eval(lua_State* L, const char* code) {
    int status = luaL_dostring(L, code);
    if (status != 0) {
        const char *err = lua_tostring(L, -1);
        fprintf(stderr, "Error executing eval: %s\n", err);
        lua_pop(L, 1);
    }
    return status;
}

// Execute a global Lua function by name
__attribute__((visibility("default")))
char* vm_exec_func(lua_State* L, const char* func, int argc, Variant* argv) {
    char* func_copy = strdup(func);
    if (!func_copy) return NULL;

    char* dot = strchr(func_copy, '.');

    int nargs = 0;

    if (dot) {
        *dot = '\0';
        const char* table = func_copy;
        const char* method = dot + 1;

        // Push table
        lua_getglobal(L, table);
        if (!lua_istable(L, -1)) {
            fprintf(stderr, "Table not found: %s\n", table);
            free(func_copy);
            lua_pop(L, 1);
            return NULL;
        }

        // Push method
        lua_getfield(L, -1, method);
        if (!lua_isfunction(L, -1)) {
            fprintf(stderr, "Method not found: %s.%s\n", table, method);
            free(func_copy);
            lua_pop(L, 2);
            return NULL;
        }

        // Push self as first arg
        lua_pushvalue(L, -2);
        nargs = 1;

        // Remove table (so stack = [function, self])
        lua_remove(L, -3);
    } else {
        // Case: "func" (global function)
        lua_getglobal(L, func_copy);
        if (!lua_isfunction(L, -1)) {
            fprintf(stderr, "Function not found: %s\n", func_copy);
            free(func_copy);
            lua_pop(L, 1);
            return NULL;
        }
    }

    free(func_copy);
    lua_State *co = lua_newthread(L);
    lua_xmove(L, co, nargs);



    // Push user args
    for (int i = 0; i < argc; i++) {
        Variant v = argv[i];
        switch (v.type) {
            case TYPE_INT:    lua_pushinteger(co, v.i); break;
            case TYPE_DOUBLE: lua_pushnumber(co, v.d); break;
            case TYPE_STRING: lua_pushstring(co, v.s); break;
        }
        nargs++;
    }

    if (lua_pcall(co, nargs, 1, 0) != LUA_OK) {
        fprintf(stderr, "Error calling function %s: %s\n", func, lua_tostring(co, -1));
        lua_pop(co, 1);
        return NULL;
    }

    const char* str = lua_tostring(co, -1);
    char* ret = NULL;
    if (str) {
        ret = malloc(strlen(str) + 1);
        strcpy(ret, str);
    }

    lua_pop(co, 1);
    return ret;
}
