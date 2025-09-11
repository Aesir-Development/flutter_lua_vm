cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "flutter_lua_vm")
project(${PROJECT_NAME} LANGUAGES C CXX)

# Plugin name
set(PLUGIN_NAME "flutter_lua_vm_plugin")  # Match this to your open call

# Plugin sources
list(APPEND PLUGIN_SOURCES
  ${CMAKE_CURRENT_SOURCE_DIR}/../src/lua_vm.c
)

# Lua sources
file(GLOB LUA_SOURCES
  ${CMAKE_CURRENT_SOURCE_DIR}/../src/third_party/lua/*.c
)

# Create shared library
add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
  ${LUA_SOURCES}
)

# Treat Lua sources as C
set_source_files_properties(${LUA_SOURCES} PROPERTIES LANGUAGE C)

# Export symbols from lua_vm.c
set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/../src/lua_vm.c
    PROPERTIES COMPILE_FLAGS "-fvisibility=default"
)

# Include directories
target_include_directories(${PLUGIN_NAME} PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/../src
  ${CMAKE_CURRENT_SOURCE_DIR}/../src/third_party/lua
)
