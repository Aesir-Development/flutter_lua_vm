#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>


typedef char* (*DartHttpCallback)(const char* url);
static DartHttpCallback dart_callback = NULL;

void register_dart_callback(DartHttpCallback cb) {
    dart_callback = cb;
}

// Perform HTTP request (this is a placeholder, actual implementation needed)
// For example, using libcurl or another HTTP library
int vm_http_request(lua_State* L) {
    const char* url = luaL_checkstring(L, 1);

    if (dart_callback != NULL) {
        char *res = dart_callback(url);
        puts(res);
    }

    char buffer[256];
    buffer[0] = '\0';

    strcat(buffer, "HTTP response from: ");
    strcat(buffer, url);

    lua_pushstring(L, buffer);
    return 1;
}

__attribute__((visibility("default")))
lua_State* vm_create() {
    lua_State *L = luaL_newstate();
    luaL_openlibs(L);

    // Regiser custom functions
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
    char* token = strtok((char*)args, ",");
    while (token != NULL) {
        arg[arg_count++] = token;
        token = strtok(NULL, ",");
    }

    lua_getglobal(L, func);
    for (int i = 0; i < arg_count; i++) {
        lua_pushstring(L, arg[i]);
    }
    lua_call(L, arg_count, 1);
    int stack = lua_gettop(L);
    if (stack <= 0) {
        puts("Stack is empty");
    }

    const char * str = lua_tostring(L, -1);
    // puts(str);
    lua_pop(L, 1);
    char *result = malloc(strlen(str) + 1);
    strcpy(result, str);

    return result;
}
