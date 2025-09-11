import 'flutter_lua_vm_platform_interface.dart';

class FlutterLuaVm {
  Future<String?> getPlatformVersion() {
    return FlutterLuaVmPlatform.instance.getPlatformVersion();
  }
}
