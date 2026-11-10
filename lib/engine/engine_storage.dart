import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';

import '../models/converter_display.dart';
import '../core/app_preferences.dart';
import '../models/province.dart';
import 'engine_config.dart';
import 'map_engine/map_engine_generated.dart';

part 'engine_storage/paths.part.dart';
part 'engine_storage/cache_io.part.dart';
part 'engine_storage/props_io.part.dart';
part 'engine_storage/converters_io.part.dart';
part 'engine_storage/workspace_io.part.dart';
part 'engine_storage/import_io.part.dart';

class ConverterEntryPoint {
  final String script;
  final String rootPath;
  const ConverterEntryPoint({required this.script, required this.rootPath});
}

abstract class _EngineStorageBase {
  MapEngineConfig get config;
}

class EngineStorageManager extends _EngineStorageBase
    with 
      _PathsIO, 
      _CacheIO, 
      _PropsIO, 
      _ConvertersIO, 
      _WorkspaceIO,
      _ImportIO {
        
  @override
  final MapEngineConfig config;

  EngineStorageManager({required this.config});
}