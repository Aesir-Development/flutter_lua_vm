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
int coroRef = 0;

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


// This is the actual coroutine function that will be executed
static int http_coroutine_func(lua_State* L) {
    const char* url = lua_tostring(L, 1);  // Get URL from coroutine stack

    // Make the HTTP call via Dart callback
    if (dart_callback) {
        dart_callback(L, url);
    }

    // Yield and wait for response
    lua_yield(L, 0);

    // When resumed, the response will be on top of stack
    // Return it as the result of this coroutine function
    return 1;  // Return 1 value (the HTTP response)
}
int vm_http_request(lua_State* L) {
    const char* url = luaL_checkstring(L, 1);

    // Check if we're in the main thread
    if (lua_pushthread(L)) {
        // We're in main thread, need to create coroutine
        lua_pop(L, 1); // remove boolean result from stack

        // Create new coroutine
        lua_State* co = lua_newthread(L);

        // Save reference so it isn't GC'd
        coroRef = luaL_ref(L, LUA_REGISTRYINDEX);

        // Push the coroutine function and URL onto coroutine stack
        lua_pushcfunction(co, http_coroutine_func);
        lua_pushstring(co, url);

        // Start coroutine
        int nresults = 0;
        int status = lua_resume(co, L, 1, &nresults);

        if (status == LUA_YIELD) {
            return 0; // yielded successfully, will be resumed later
        } else if (status != LUA_OK) {
            fprintf(stderr, "Lua status: %d\n", status);
            fprintf(stderr, "Lua error: %s\n", lua_tostring(co, -1));
            luaL_unref(L, LUA_REGISTRYINDEX, coroRef);
            return luaL_error(L, "HTTP request failed");
        }
        return 0;
    } else {
        // We're already in a coroutine - just make the call directly
        lua_pop(L, 1); // remove boolean result

        // Store reference to current coroutine
        lua_pushthread(L);
        coroRef = luaL_ref(L, LUA_REGISTRYINDEX);

        // Make HTTP call
        if (dart_callback) {
            dart_callback(L, url);
        }

        return lua_yield(L, 0);
    }
}

void vm_resume_http(lua_State *L, char *data) {
    print("Resuming HTTP coroutine\n");

    // Get coroutine from registry
    lua_rawgeti(L, LUA_REGISTRYINDEX, coroRef);
    lua_State* coro = lua_tothread(L, -1);
    lua_pop(L, 1);

    if (!coro) {
        fprintf(stderr, "Error: Could not retrieve coroutine\n");
        return;
    }

    // Push response data onto coroutine stack
    lua_pushstring(coro, data);

    // Resume coroutine with the response data
    int nresults = 0;
    int status = lua_resume(coro, L, 1, &nresults);

    if (status == LUA_OK) {
        // Coroutine finished successfully
        fprintf(stdout, "Coroutine completed successfully with %d results\n", nresults);

        // The coroutine should have returned the HTTP response
        // In a real implementation, you'd need to somehow get this value
        // back to the original Lua context that called http_request

        luaL_unref(L, LUA_REGISTRYINDEX, coroRef);
        coroRef = 0;
    } else if (status == LUA_YIELD) {
        // Coroutine yielded again (shouldn't happen in this simple case)
        fprintf(stdout, "Coroutine yielded again\n");
    } else {
        // Error occurred
        const char *err = lua_tostring(coro, -1);
        fprintf(stderr, "Lua error on resume: %s\n", err);
        luaL_unref(L, LUA_REGISTRYINDEX, coroRef);
        coroRef = 0;
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
    return luaL_dostring(L, code);
}

// Execute a global Lua function by name
__attribute__((visibility("default")))
char* vm_exec_func(lua_State* L, const char* func, const char* args) {
    const char *arg[256];
    int arg_count = 0;

    char* args_copy = malloc(strlen(args) + 1);
    strcpy(args_copy, args);

    char* token = strtok(args_copy, ",");
    while (token != NULL && arg_count < 256) {
        arg[arg_count++] = token;
        token = strtok(NULL, ",");
    }

    lua_getglobal(L, func);
    if (lua_isnil(L, -1)) {
        free(args_copy);
        lua_pop(L, 1);
        return NULL;
    }

    for (int i = 0; i < arg_count; i++) {
        lua_pushstring(L, arg[i]);
    }

    int result = lua_pcall(L, arg_count, 1, 0);
    if (result != LUA_OK) {
        fprintf(stderr, "Error calling function %s: %s\n", func, lua_tostring(L, -1));
        lua_pop(L, 1);
        free(args_copy);
        return NULL;
    }

    const char* str = lua_tostring(L, -1);
    char *return_value = NULL;
    if (str) {
        return_value = malloc(strlen(str) + 1);
        strcpy(return_value, str);
    }

    lua_pop(L, 1);
    free(args_copy);

    return return_value;
}
