import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';

import 'package:dio/dio.dart';

typedef NativeCallbackC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef NativeCallbackDart = Pointer<Utf8> Function(Pointer<Utf8>);


typedef RegisterCallbackC = Void Function(Pointer<NativeFunction<NativeCallbackC>>);
typedef RegisterCallbackDart = void Function(Pointer<NativeFunction<NativeCallbackC>>);



typedef VmCreateFunc = Pointer<Void> Function();
typedef VmEvalFunc = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef VmEval = int Function(Pointer<Void>, Pointer<Utf8>);

typedef VmExecFunc =
    Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

class LuaVM {
  late DynamicLibrary _dynLib;
  late Pointer<Void> _state;

  LuaVM() {
    if (Platform.isLinux) {
      _dynLib = DynamicLibrary.open("libflutter_lua_vm_plugin.so");
    } else if (Platform.isAndroid) {
      _dynLib = DynamicLibrary.open("libflutter_lua_vm_plugin.so");
    } else {
      throw UnsupportedError("Only Linux supported in this test");
    }

    final registerCallback = _dynLib.lookupFunction<RegisterCallbackC, RegisterCallbackDart>("register_dart_callback");

    final cbPtr = Pointer.fromFunction<NativeCallbackC>(httpRequest);
    registerCallback(cbPtr);

    final create = _dynLib.lookupFunction<VmCreateFunc, VmCreateFunc>(
      "vm_create",
    );
    _state = create();
  }

  static Pointer<Utf8> httpRequest(Pointer<Utf8> url) {
    final stringUrl = url.toDartString();

    Response response;
    Dio().get(stringUrl).then((value) => {
      // response = value
    });
    // print(response.statusCode);

    return "Yippii".toNativeUtf8();
  }

  int eval(String code) {
    final eval = _dynLib
        .lookup<NativeFunction<VmEvalFunc>>("vm_eval")
        .asFunction<VmEval>();
    final codePtr = code.toNativeUtf8();
    final result = eval(_state, codePtr);
    malloc.free(codePtr);

    return result;
  }

  String exec(String func, String args) {
    final exec = _dynLib
        .lookup<NativeFunction<VmExecFunc>>("vm_exec_func")
        .asFunction<VmExecFunc>();
    final funcPtr = func.toNativeUtf8();
    final argsPointer = args.toNativeUtf8();
    final resultPtr = exec(_state, funcPtr, argsPointer);

    malloc.free(argsPointer);

    final result = resultPtr.toDartString();
    malloc.free(resultPtr);

    return result;
  }
}
