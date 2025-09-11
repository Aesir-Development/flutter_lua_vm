import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_lua_vm_platform_interface.dart';

/// An implementation of [FlutterLuaVmPlatform] that uses method channels.
class MethodChannelFlutterLuaVm extends FlutterLuaVmPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_lua_vm');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
