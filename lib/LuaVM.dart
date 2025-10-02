import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

final class Variant extends Struct {
  @Int32()
  external int type;

  external VariantUnion value;
}

final class VariantUnion extends Union {
  @Int32()
  external int i;

  @Double()
  external double d;

  external Pointer<Utf8> s;
}

class VariantType {
  static const int intType = 0;
  static const int doubleType = 1;
  static const int stringType = 2;
}

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

typedef VmResumeHttpFunc =
    Void Function(Pointer<Void>, Pointer<Void>, Pointer<Utf8>);
typedef VmResumeHttp =
    void Function(Pointer<Void>, Pointer<Void>, Pointer<Utf8>);

typedef VmExecC =
    Pointer<Utf8> Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Int32 argc,
      Pointer<Variant> argv,
    );
typedef VmExecFunc =
    Pointer<Utf8> Function(
      Pointer<Void>,
      Pointer<Utf8>,
      int argc,
      Pointer<Variant> argv,
    );

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

  static void httpRequest(Pointer<void> co, Pointer<Utf8> url) {
    final stringUrl = url.toDartString();
    DynamicLibrary tmpLib = getLib();

    final resumeHttp = tmpLib
        .lookup<NativeFunction<VmResumeHttpFunc>>("vm_resume_http")
        .asFunction<VmResumeHttp>();

    final future = Dio().get(stringUrl);
    future.then(
      (value) => {
        resumeHttp(
          _state,
          co as Pointer<Void>,
          value.data.toString().toNativeUtf8(),
        ),
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

  String exec(String func, List<Pointer<Variant>> args) {
    final funcExec = _dynLib
        .lookup<NativeFunction<VmExecC>>("vm_exec_func")
        .asFunction<VmExecFunc>();
    final funcPtr = func.toNativeUtf8();
    final argv = calloc<Variant>(args.length);

    for (int i = 0; i < args.length; i++) {
      argv[i] = args[i].ref;
      calloc.free(args[i]);
    }

    final resultPtr = funcExec(_state, funcPtr, args.length, argv);

    if (resultPtr == nullptr) {
      debugPrint("nullptr found");
      calloc.free(funcPtr);
      calloc.free(argv);
      return "";
    }
    final result = resultPtr.toDartString();
    malloc.free(resultPtr);
    calloc.free(funcPtr);
    calloc.free(argv);

    return result;
  }

  Pointer<Variant> intArg(int i) {
    final ptr = calloc<Variant>();
    ptr.ref.type = VariantType.intType;
    ptr.ref.value.i = i;
    return ptr;
  }

  Pointer<Variant> doubleArg(double d) {
    final ptr = calloc<Variant>();
    ptr.ref.type = VariantType.doubleType;
    ptr.ref.value.d = d;
    return ptr;
  }

  Pointer<Variant> stringArg(String s) {
    final ptr = calloc<Variant>();
    ptr.ref.type = VariantType.stringType;
    ptr.ref.value.s = s.toNativeUtf8();
    return ptr;
  }
}
