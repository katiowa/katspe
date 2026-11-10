// ignore_for_file: avoid_print

import 'package:lua_dardo_plus/lua.dart';

/// Separa uma string gigantesca muito mais rápido do que o Lua faria sozinho.
/// Uso no Lua: local partes = EngineAPI.split(texto, ",")
int _engineApiSplit(LuaState ls) {
  final str = ls.checkString(1);
  final delim = ls.checkString(2);
  
  if (str == null || delim == null) {
    ls.pushNil();
    return 1;
  }
  
  final parts = str.split(delim);
  ls.newTable();
  for (int i = 0; i < parts.length; i++) {
    ls.pushString(parts[i].trim());
    ls.rawSetI(-2, i + 1);
  }
  return 1; // Retorna 1 valor (a tabela)
}

/// Gera uma cor baseada no ID da província usando Hash Bitwise.
/// Uso no Lua: local cor = EngineAPI.random_color(id)
int _engineApiRandomColor(LuaState ls) {
  final id = ls.checkInteger(1) ?? 0;
  final hash = (id * 2654435761) & 0xFFFFFFFF;
  final r = (hash >> 16) & 0xFF;
  final g = (hash >> 8) & 0xFF;
  final b = hash & 0xFF;
  final colorValue = 0xFF000000 | (r << 16) | (g << 8) | b;
  
  ls.pushInteger(colorValue);
  return 1;
}

/// Permite que o criador do mod escreva no console do Dart para encontrar erros.
/// Uso no Lua: EngineAPI.log("Deu ruim na linha 5!")
int _engineApiLog(LuaState ls) {
  final msg = ls.toStr(1);
  print("[LUA MODDING] $msg");
  return 0;
}

/// Registra a tabela "EngineAPI" globalmente dentro da VM Lua.
void registerEngineApi(LuaState ls) {
  ls.newTable(); // Cria a tabela EngineAPI
  
  ls.pushDartFunction(_engineApiSplit);
  ls.setField(-2, "split");
  
  ls.pushDartFunction(_engineApiRandomColor);
  ls.setField(-2, "random_color");

  ls.pushDartFunction(_engineApiLog);
  ls.setField(-2, "log");
  
  ls.setGlobal("EngineAPI"); // Salva globalmente
}
