import 'dart:io';
import 'eis_engine_service.dart';

/// Shared runtime holder for the EIS Engine across Serverpod RPC endpoints and REST webhooks.
class EisRuntime {
  static EisEngineService? _instance;
  static Future<void>? _initFuture;

  static Future<EisEngineService> getEngine({String? persistPath}) async {
    if (_instance != null) return _instance!;
    _initFuture ??= () async {
      final storePath = persistPath ??
          '${Directory.current.path}${Platform.pathSeparator}data${Platform.pathSeparator}eis_store.json';
      final engine = EisEngineService(persistPath: storePath);
      await engine.seedDefaultDemoDataIfEmpty();
      _instance = engine;
    }();
    await _initFuture;
    return _instance!;
  }

  /// Allows tests to inject a clean in-memory engine.
  static void setEngineForTesting(EisEngineService engine) {
    _instance = engine;
    _initFuture = Future.value();
  }
}
