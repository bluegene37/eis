// Gene - Nov, 20, 2026: Web-safe persistence abstraction for embedded BIR EIS/CAS local storage.

export 'eis_store_persistence_stub.dart'
    if (dart.library.io) 'eis_store_persistence_io.dart';

abstract class EisStorePersistence {
  String? readSync();
  void writeSync(String jsonContent);
}
