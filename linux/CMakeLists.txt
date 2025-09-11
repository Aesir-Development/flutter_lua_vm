cmake_minimum_required(VERSION 3.10)
project(flutter_lua_vm LANGUAGES C CXX)

set(PLUGIN_NAME "flutter_lua_vm_plugin")

# Plugin sources
list(APPEND PLUGIN_SOURCES
  "flutter_lua_vm_plugin.cc"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/lua_vm.c"
)

# All Lua C sources
file(GLOB LUA_SOURCES
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/third_party/lua/*.c"
)

# Create your plugin library
add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
  ${LUA_SOURCES}
)

# Treat Lua sources as C
set_source_files_properties(${LUA_SOURCES} PROPERTIES LANGUAGE C)

# Ensure C symbols from lua_vm.c are exported
set_source_files_properties(${CMAKE_CURRENT_SOURCE_DIR}/../src/lua_vm.c
    PROPERTIES COMPILE_FLAGS "-fvisibility=default"
)

# Include paths
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/../src"
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/third_party/lua"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/third_party"
  "${CMAKE_SOURCE_DIR}/lib/includes"
)

# Link libraries
target_link_libraries(${PLUGIN_NAME} PRIVATE
    flutter
    PkgConfig::GTK
)

set(flutter_lua_vm_bundled_libraries
  $<TARGET_FILE:${PLUGIN_NAME}>
  PARENT_SCOPE
)
