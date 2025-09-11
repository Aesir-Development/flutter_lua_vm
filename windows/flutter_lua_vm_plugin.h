#ifndef FLUTTER_PLUGIN_FLUTTER_LUA_VM_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_LUA_VM_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_lua_vm {

class FlutterLuaVmPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterLuaVmPlugin();

  virtual ~FlutterLuaVmPlugin();

  // Disallow copy and assign.
  FlutterLuaVmPlugin(const FlutterLuaVmPlugin&) = delete;
  FlutterLuaVmPlugin& operator=(const FlutterLuaVmPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_lua_vm

#endif  // FLUTTER_PLUGIN_FLUTTER_LUA_VM_PLUGIN_H_
