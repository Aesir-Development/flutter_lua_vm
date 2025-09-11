#include "include/flutter_lua_vm/flutter_lua_vm_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_lua_vm_plugin.h"

void FlutterLuaVmPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_lua_vm::FlutterLuaVmPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
