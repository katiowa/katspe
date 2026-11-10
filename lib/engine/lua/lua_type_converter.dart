import 'dart:typed_data';
import 'package:lua_dardo_plus/lua.dart';

/// Converte um valor do topo (ou índice específico) da pilha Lua para Dart.
dynamic luaValueToDart(LuaState ls, int index) {
  final type = ls.type(index);
  
  if (type == LuaType.luaNumber) {
    if (ls.isInteger(index)) return ls.toInteger(index);
    return ls.toNumber(index);
  } else if (type == LuaType.luaString) {
    return ls.toStr(index);
  } else if (type == LuaType.luaBoolean) {
    return ls.toBoolean(index);
  } else if (type == LuaType.luaTable) {
    final list = <dynamic>[];
    // Só é populado se/quando descobrirmos que a tabela NÃO é um array
    // puro — evita, para o caso comum (arrays x/y de cada província,
    // possivelmente dezenas de milhares deles num mapa do AoH2), montar
    // um `Map<String,dynamic>` inteiro em paralelo à `list` só para
    // jogá-lo fora no final porque o resultado virou lista.
    Map<String, dynamic>? map;
    bool isList = true;
    int expectedIndex = 1;

    // Prepara para iterar a tabela no topo da pilha
    ls.pushNil();
    while (ls.next(index < 0 ? index - 1 : index)) {
      final keyType = ls.type(-2);
      dynamic key;
      
      if (keyType == LuaType.luaNumber && ls.isInteger(-2)) {
        key = ls.toInteger(-2);
      } else if (keyType == LuaType.luaString) {
        key = ls.toStr(-2);
      }

      // Converte o valor recursivamente
      final val = luaValueToDart(ls, -1);

      // Descobre se é um array (chaves sequenciais 1, 2, 3...) ou um Map
      if (isList && key is int && key == expectedIndex) {
        list.add(val);
        expectedIndex++;
      } else {
        if (isList) {
          // Primeira vez que a tabela se revela "não-array": materializa
          // o Map agora, preenchendo com o que já foi acumulado em
          // `list` (chaves 1..N), e continua como Map dali em diante.
          isList = false;
          map = <String, dynamic>{
            for (int i = 0; i < list.length; i++) '${i + 1}': list[i],
          };
        }
        if (key != null) map![key.toString()] = val;
      }

      ls.pop(1); // Remove o valor, mantém a chave para o próximo ls.next()
    }

    if (isList) {
      if (list.isEmpty) return <String, dynamic>{};

      // OTIMIZAÇÃO DE TRANSFERÊNCIA DE ISOLATE (Zero-Copy):
      // Verifica se a lista gerada é puramente numérica.
      // Se for, convertemos para TypedData (Int32List ou Float64List).
      // Quando o Dart envia TypedData via SendPort para a Main Isolate, 
      // ele não faz um "Deep Copy" objeto por objeto (que alocaria gigabytes 
      // e derrubaria o GC), mas sim um memcpy de bloco bruto.
      bool allInts = true;
      bool allDoubles = true;

      for (int i = 0; i < list.length; i++) {
        final item = list[i];
        if (item is! int) allInts = false;
        if (item is! double) allDoubles = false;
        if (!allInts && !allDoubles) break;
      }

      if (allInts) return Int32List.fromList(list.cast<int>());
      if (allDoubles) return Float64List.fromList(list.cast<double>());

      return list;
    }
    return map!;
  }
  return null;
}

/// Pega um objeto Dart e empurra para a pilha Lua
void dartToLuaValue(LuaState ls, dynamic value) {
  if (value == null) {
    ls.pushNil();
  } else if (value is int) {
    ls.pushInteger(value);
  } else if (value is double) {
    ls.pushNumber(value);
  } else if (value is bool) {
    ls.pushBoolean(value);
  } else if (value is String) {
    ls.pushString(value);
  } else if (value is List) {
    ls.newTable();
    for (int i = 0; i < value.length; i++) {
      dartToLuaValue(ls, value[i]);
      ls.rawSetI(-2, i + 1); // Lua Arrays começam em 1
    }
  } else if (value is Map) {
    ls.newTable();
    for (final entry in value.entries) {
      ls.pushString(entry.key.toString());
      dartToLuaValue(ls, entry.value);
      ls.setTable(-3);
    }
  }
}