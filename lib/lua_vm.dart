import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_lua_vm/lua_task_handler.dart';

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

typedef HTMLSelectorC = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef RegisterHTMLSelectorC =
    Void Function(Pointer<NativeFunction<HTMLSelectorC>>);
typedef RegisterHTMLSelectorDart =
    void Function(Pointer<NativeFunction<HTMLSelectorC>>);

typedef VmCreateFunc = Pointer<Void> Function();
typedef VmEvalFunc = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef VmEval = int Function(Pointer<Void>, Pointer<Utf8>);

typedef VmResumeHttpFunc =
    Void Function(Pointer<Void>, Pointer<Void>, Pointer<Utf8>);
typedef VmResumeHttp =
    void Function(Pointer<Void>, Pointer<Void>, Pointer<Utf8>);

typedef VmPoll = Pointer<TaskArray> Function();

typedef VmExecC =
    Pointer<Utf8> Function(
      Pointer<Void>,
      Int32 id,
      Pointer<Utf8>,
      Int32 argc,
      Pointer<Variant> argv,
    );
typedef VmExecFunc =
    Pointer<Utf8> Function(
      Pointer<Void>,
      int id,
      Pointer<Utf8>,
      int argc,
      Pointer<Variant> argv,
    );

class LuaVM {
  late DynamicLibrary _dynLib;
  static Pointer<Void> _state = Pointer.fromAddress(0);
  static LuaTaskHandler taskHandler = LuaTaskHandler();

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

    final registerSelector = _dynLib
        .lookupFunction<RegisterHTMLSelectorC, RegisterHTMLSelectorDart>(
          "register_selector_function",
        );
    final selectorPtr = Pointer.fromFunction<HTMLSelectorC>(htmlSelector);
    registerSelector(selectorPtr);

    final create = _dynLib.lookupFunction<VmCreateFunc, VmCreateFunc>(
      "vm_create",
    );

    _state = create();

    final poll = _dynLib.lookupFunction<VmPoll, VmPoll>("vm_poll");
    taskHandler.poll(poll);
  }

  static void httpRequest(Pointer<void> co, Pointer<Utf8> url) {
    final stringUrl = url.toDartString();
    DynamicLibrary tmpLib = getLib();

    final resumeHttp = tmpLib
        .lookup<NativeFunction<VmResumeHttpFunc>>("vm_resume_http")
        .asFunction<VmResumeHttp>();

    final future = Dio().get(
      stringUrl,
      options: Options(
        responseType: ResponseType.plain,
      ), // Want to make sure it doesn't parse JSON before we pass it to Lua
    );
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

  static Pointer<Utf8> htmlSelector(
    Pointer<Utf8> htmlPtr,
    Pointer<Utf8> selectorPtr,
  ) {
    var html = htmlPtr.toDartString();
    var selector = selectorPtr.toDartString();

    var dom = parse(html);
    var element = dom.querySelector(selector);

    if (element == null) {
      return "".toNativeUtf8();
    } else if (!element.hasContent()) {
      return "".toNativeUtf8();
    }

    var content = element.innerHtml;

    return content.toNativeUtf8();
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

  Future<String> exec(String func, List<Pointer<Variant>> args) async {
    final funcExec = _dynLib
        .lookup<NativeFunction<VmExecC>>("vm_exec_func")
        .asFunction<VmExecFunc>();
    final funcPtr = func.toNativeUtf8();
    final argv = calloc<Variant>(args.length);

    for (int i = 0; i < args.length; i++) {
      argv[i] = args[i].ref;
      calloc.free(args[i]);
    }

    int id = taskHandler.getUniqueID();

    final resultPtr = funcExec(_state, id, funcPtr, args.length, argv);

    if (resultPtr == nullptr) {
      debugPrint("nullptr found");
      calloc.free(funcPtr);
      calloc.free(argv);

      var res = taskHandler.getResult(id);
      while (res == null) {
        await Future.delayed(Duration(milliseconds: 125));
        res = taskHandler.getResult(id);
      }

      return res;
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
