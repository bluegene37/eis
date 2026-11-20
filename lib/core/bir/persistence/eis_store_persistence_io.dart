// Gene - Nov, 20, 2026: Native dart:io file persistence and application support path resolver.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'eis_store_persistence.dart';

class _FileEisStorePersistence implements EisStorePersistence {
  final String path;

  _FileEisStorePersistence(this.path);

  @override
  String? readSync() {
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  }

  @override
  void writeSync(String jsonContent) {
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    file.writeAsStringSync(jsonContent);
  }
}

EisStorePersistence? createFilePersistence(String? path) {
  if (path == null || path.isEmpty) return null;
  return _FileEisStorePersistence(path);
}

Future<String?> resolveDefaultStorePath() async {
  try {
    final dir = await getApplicationSupportDirectory();
    // return '${dir.path}${Platform.pathSeparator}eis_v2_store.json';
    // Gene - Nov, 20, 2026: Renamed local persistence filename from eis_v2_store.json to eis_store.json.
    return '${dir.path}${Platform.pathSeparator}eis_store.json';
  } catch (_) {
    // Fallback to in-memory engine when platform channels are unavailable (e.g., widget/unit tests).
    return null;
  }
}
