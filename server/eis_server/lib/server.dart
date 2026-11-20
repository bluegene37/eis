import 'dart:io';
import 'package:serverpod/serverpod.dart';

import 'src/bir/eis_runtime.dart';
import 'src/bir/rest_bridge_server.dart';
import 'src/generated/protocol.dart';
import 'src/generated/endpoints.dart';

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  // Initialize Serverpod and connect it with your generated code.
  final pod = Serverpod(args, Protocol(), Endpoints());

  // Gene - Nov, 17, 2026: Initialize Philippine BIR EIS & CAS runtime + REST/Webhook bridge on port 4000.
  // Original start-only line preserved:
  // await pod.start();
  final engine = await EisRuntime.getEngine();
  final restPort = int.tryParse(Platform.environment['EIS_REST_PORT'] ?? '4000') ?? 4000;
  await startRestWebhookBridge(engine, port: restPort);

  // Start the server.
  await pod.start();
}
