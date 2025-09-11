import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lua_vm/flutter_lua_vm.dart';
import 'package:flutter_lua_vm/flutter_lua_vm_platform_interface.dart';
import 'package:flutter_lua_vm/flutter_lua_vm_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterLuaVmPlatform
    with MockPlatformInterfaceMixin
    implements FlutterLuaVmPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterLuaVmPlatform initialPlatform = FlutterLuaVmPlatform.instance;

  test('$MethodChannelFlutterLuaVm is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterLuaVm>());
  });

  test('getPlatformVersion', () async {
    FlutterLuaVm flutterLuaVmPlugin = FlutterLuaVm();
    MockFlutterLuaVmPlatform fakePlatform = MockFlutterLuaVmPlatform();
    FlutterLuaVmPlatform.instance = fakePlatform;

    expect(await flutterLuaVmPlugin.getPlatformVersion(), '42');
  });
}
