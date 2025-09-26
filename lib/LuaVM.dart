import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

typedef NativeCallbackC = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef NativeCallbackDart = void Function(Pointer<void>, Pointer<Utf8>);

typedef RegisterCallbackC =
    Void Function(Pointer<NativeFunction<NativeCallbackC>>);
typedef RegisterCallbackDart =
    void Function(Pointer<NativeFunction<NativeCallbackC>>);

typedef PrintCallbackC = Void Function(Pointer<Utf8>);
typedef PrintCallbackDart = void Function(Pointer<Utf8>);

typedef RegisterPrintCallbackC =
    Void Function(Pointer<NativeFunction<PrintCallbackC>>);
typedef RegisterPrintCallbackDart =
    void Function(Pointer<NativeFunction<PrintCallbackC>>);

typedef VmCreateFunc = Pointer<Void> Function();
typedef VmEvalFunc = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef VmEval = int Function(Pointer<Void>, Pointer<Utf8>);

typedef VmResumeHttpFunc = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef VmResumeHttp = void Function(Pointer<Void>, Pointer<Utf8>);

typedef VmExecFunc =
    Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

class LuaVM {
  late DynamicLibrary _dynLib;
  static Pointer<Void> _state = Pointer.fromAddress(0);

  static DynamicLibrary getLib() {
    if (Platform.isLinux) {
      return DynamicLibrary.open("libflutter_lua_vm_plugin.so");
    } else if (Platform.isAndroid) {
      return DynamicLibrary.open("libflutter_lua_vm_plugin.so");
    } else {
      throw UnsupportedError("Only Linux supported in this test");
    }
  }

  LuaVM() {
    _dynLib = getLib();

    final registerCallback = _dynLib
        .lookupFunction<RegisterCallbackC, RegisterCallbackDart>(
          "register_dart_callback",
        );

    final cbPtr = Pointer.fromFunction<NativeCallbackC>(httpRequest);
    registerCallback(cbPtr);

    final registerPrint = _dynLib
        .lookupFunction<RegisterPrintCallbackC, RegisterPrintCallbackDart>(
          "register_print_function",
        );
    final printPtr = Pointer.fromFunction<PrintCallbackC>(print);
    registerPrint(printPtr);

    final create = _dynLib.lookupFunction<VmCreateFunc, VmCreateFunc>(
      "vm_create",
    );
    _state = create();
  }

  static void httpRequest(Pointer<void> L, Pointer<Utf8> url) {
    final stringUrl = url.toDartString();
    DynamicLibrary tmpLib = getLib();

    final resumeHttp = tmpLib
        .lookup<NativeFunction<VmResumeHttpFunc>>("vm_resume_http")
        .asFunction<VmResumeHttp>();

    final future = Dio().get(stringUrl);
    future.then(
      (value) => {
        resumeHttp(L as Pointer<Void>, value.data.toString().toNativeUtf8()),
      },
    );
  }

  static void print(Pointer<Utf8> s) {
    debugPrint(s.toDartString());
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
    final funcExec = _dynLib
        .lookup<NativeFunction<VmExecFunc>>("vm_exec_func")
        .asFunction<VmExecFunc>();
    final funcPtr = func.toNativeUtf8();
    final argsPointer = args.toNativeUtf8();
    final resultPtr = funcExec(_state, funcPtr, argsPointer);

    malloc.free(argsPointer);

    debugPrint("Test");
    if (resultPtr == nullptr) {
      debugPrint("nullptr found");
    }
    final result = resultPtr.toDartString();
    malloc.free(resultPtr);

    return result;
  }
}
