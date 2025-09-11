import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lua_vm/LuaVM.dart';

void main() {
  test('LuaVM eval test', () {
    LuaVM lvm = LuaVM();
    String luaCode = """
    url = "https://www.runoob.com"
    response = http_request(url)
    """;
    int success = lvm.eval(luaCode);

    lvm.eval("print(response)");
    print('$success');
  });
}
