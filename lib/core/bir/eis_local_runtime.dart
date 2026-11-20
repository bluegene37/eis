// Gene - Nov, 20, 2026: Local embedded singleton runtime for standalone Flutter BIR EIS/CAS execution.

import 'package:flutter/foundation.dart';
import 'eis_engine_service.dart';
import 'persistence/eis_store_persistence.dart';

/// Shared runtime holder for the embedded pure-Dart BIR EIS v2.01 & CAS engine.
class EisLocalRuntime {
  static EisEngineService? _instance;
  static Future<void>? _initFuture;

  static Future<EisEngineService> getEngine({String? persistPath}) async {
    if (_instance != null) return _instance!;
    _initFuture ??= () async {
      try {
        final storePath =
            persistPath ?? (kIsWeb ? null : await resolveDefaultStorePath());
        final engine = EisEngineService(persistPath: storePath);
        await engine.seedDefaultDemoDataIfEmpty();
        _instance = engine;
      } catch (_) {
        _initFuture = null;
        rethrow;
      }
    }();
    await _initFuture;
    return _instance!;
  }

  /// Allows tests to inject a clean in-memory or custom engine instance.
  static void setEngineForTesting(EisEngineService engine) {
    _instance = engine;
    _initFuture = Future.value();
  }

  /// Resets the singleton runtime between tests.
  static void resetForTesting() {
    _instance = null;
    _initFuture = null;
  }
}
