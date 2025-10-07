#ifndef LUA_VM
#define LUA_VM

#include "lua.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>

typedef void (*Print)(const char* url);
Print get_print(void);
char* format(const char *format, ...);

#endif
