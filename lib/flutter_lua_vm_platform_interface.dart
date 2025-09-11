import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_lua_vm_method_channel.dart';

abstract class FlutterLuaVmPlatform extends PlatformInterface {
  /// Constructs a FlutterLuaVmPlatform.
  FlutterLuaVmPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterLuaVmPlatform _instance = MethodChannelFlutterLuaVm();

  /// The default instance of [FlutterLuaVmPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterLuaVm].
  static FlutterLuaVmPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterLuaVmPlatform] when
  /// they register themselves.
  static set instance(FlutterLuaVmPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
