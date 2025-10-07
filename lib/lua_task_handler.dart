import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_lua_vm/lua_vm.dart';

@protected
final class Task extends Struct {
  @Int32()
  external int id;

  external Pointer<Void> co; // lua_State* is opaque, use Pointer<Void>

  @Int32()
  external int completed;

  @Int32()
  external int returntype; // Use ReturnType.values[returntype] in Dart

  external ReturnUnion value;
}

@protected
final class ReturnUnion extends Union {
  @Int32()
  external int i;

  @Double()
  external double d;

  external Pointer<Utf8> s;
}

final class TaskArray extends Struct {
  @Int32()
  external int count;
  external Pointer<Task> tasks;
}

enum ReturnType { RET_INT, RET_DOUBLE, RET_STRING }

@protected
class LuaTaskHandler {
  List<Task> tasks = [];

  // MS between ticks
  int tickRate = 125;

  int getUniqueID() {
    if (tasks.isEmpty) {
      return 0;
    }

    int id = tasks[tasks.length - 1].id + 1;
    return id;
  }

  Future<void> poll(VmPoll vmPoll) async {
    debugPrint("Started polling");
    while (true) {
      await Future.delayed(Duration(milliseconds: tickRate));

      var ptr = vmPoll();
      var count = ptr.ref.count;
      for (var i = 0; i < count; i++) {
        tasks.add(ptr.ref.tasks[i]);
        debugPrint("Added task: ${tasks[i].id}");
      }
    }
  }

  String? getResult(int id) {
    if (tasks.isEmpty) return null;
    for (var task in tasks) {
      if (task.id != id) continue;
      if (task.completed == 0) continue;

      return task.value.s.toDartString();
    }

    return null;
  }
}
