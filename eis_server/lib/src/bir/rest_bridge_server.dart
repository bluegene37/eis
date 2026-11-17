import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'bir_eis_schema.dart';
import 'eis_engine_service.dart';
import 'erp_connectors_service.dart';

/// Lightweight REST & ERP Webhook Bridge on port 4000 running inside Serverpod
/// so external ERPs (Xero, QuickBooks, Odoo) and HTTP clients can call `/api/*` directly.
Future<HttpServer> startRestWebhookBridge(
  EisEngineService engine, {
  int port = 4000,
}) async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  unawaited(
    server.forEach((HttpRequest request) async {
      _addCorsHeaders(request.response);
      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }
      await _handleRequest(request, engine);
    }),
  );
  return server;
}

void _addCorsHeaders(HttpResponse res) {
  res.headers.set('Access-Control-Allow-Origin', '*');
  res.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.headers.set(
    'Access-Control-Allow-Headers',
    'Origin, Content-Type, Accept, Authorization',
  );
  res.headers.contentType = ContentType.json;
}

Future<void> _sendJson(HttpResponse res, int statusCode, Object body) async {
  res.statusCode = statusCode;
  res.write(jsonEncode(body));
  await res.close();
}

Future<Map<String, dynamic>> _readJsonBody(HttpRequest req) async {
  final bodyStr = await utf8.decoder.bind(req).join();
  if (bodyStr.trim().isEmpty) return {};
  final decoded = jsonDecode(bodyStr);
  return decoded is Map<String, dynamic> ? decoded : {};
}

Future<void> _handleRequest(HttpRequest req, EisEngineService engine) async {
  final path = req.uri.path;
  final q = req.uri.queryParameters;

  try {
    if (req.method == 'GET' && path == '/api/health') {
      return await _sendJson(req.response, 200, {
        'status': 'ok',
        'service': 'EIS Pure-Dart Serverpod & BIR CAS Middleware',
        'schemaVersion': 'v2.01',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    }

    if (req.method == 'GET' && path == '/api/dashboard/summary') {
      return await _sendJson(
        req.response,
        200,
        engine.getDashboardSummary(q['taxpayerId']),
      );
    }

    if (req.method == 'POST' && path == '/api/gateway/config') {
      final body = await _readJsonBody(req);
      final updated = engine.setGatewayConfig(
        mode: body['mode']?.toString(),
        simulateOutage:
            body['simulateOutage'] is bool ? body['simulateOutage'] as bool : null,
      );
      return await _sendJson(req.response, 200, updated.toJson());
    }

    if (req.method == 'GET' && path == '/api/taxpayers') {
      final safe = engine
          .getTaxpayers()
          .map((tp) => tp.toJson(includePrivate: false))
          .toList();
      return await _sendJson(req.response, 200, safe);
    }

    if (req.method == 'POST' && path == '/api/taxpayers') {
      final body = await _readJsonBody(req);
      final created = engine.registerTaxpayer(
        workspaceId: body['workspaceId']?.toString() ?? 'WS-PH-DEFAULT',
        tin: body['tin']?.toString() ?? '',
        taxType: body['taxType']?.toString() ?? 'VAT',
        registeredName: body['registeredName']?.toString() ?? '',
        businessName: body['businessName']?.toString() ?? '',
        email: body['email']?.toString() ?? '',
        eisCertId: body['eisCertId']?.toString(),
        pttNumber: body['pttNumber']?.toString(),
        headOfficeAddress: BirAddress.fromJson(
          (body['headOfficeAddress'] as Map<String, dynamic>?) ?? const {},
        ),
      );
      return await _sendJson(
        req.response,
        201,
        created.toJson(includePrivate: false),
      );
    }

    if (req.method == 'POST' &&
        path.startsWith('/api/taxpayers/') &&
        path.endsWith('/rotate-keys')) {
      final id = path.split('/')[3];
      final tp = engine.rotateTaxpayerKeys(id);
      return await _sendJson(req.response, 200, {
        'id': tp.id,
        'keyId': tp.keyId,
        'publicKeyPem': tp.publicKeyJson,
      });
    }

    if (req.method == 'POST' &&
        path.startsWith('/api/taxpayers/') &&
        path.endsWith('/branches')) {
      final id = path.split('/')[3];
      final body = await _readJsonBody(req);
      final branch = engine.addBranch(
        id,
        branchCd: body['branchCd']?.toString() ?? '0001',
        branchName: body['branchName']?.toString() ?? 'Branch',
        address: BirAddress.fromJson(
          (body['address'] as Map<String, dynamic>?) ?? const {},
        ),
        invoicePrefix: body['invoicePrefix']?.toString(),
      );
      return await _sendJson(req.response, 201, branch.toJson());
    }

    if (req.method == 'GET' && path == '/api/invoices') {
      final list = engine
          .getInvoices(q['taxpayerId'])
          .map((i) => i.toJson())
          .toList();
      return await _sendJson(req.response, 200, list);
    }

    if (req.method == 'POST' && path == '/api/invoices') {
      final body = await _readJsonBody(req);
      final record = await engine.ingestAndTransmitInvoice(
        CanonicalIngestInput.fromJson(body),
        forceInvalidPayload: body['forceInvalidPayload'] == true,
      );
      return await _sendJson(
        req.response,
        record.status == 'REJECTED' ? 422 : 201,
        record.toJson(),
      );
    }

    if (req.method == 'POST' && path == '/api/invoices/retry-queue') {
      return await _sendJson(req.response, 200, await engine.processRetryQueue());
    }

    if (req.method == 'POST' &&
        path.startsWith('/api/invoices/') &&
        path.endsWith('/credit-memo')) {
      final id = path.split('/')[3];
      final body = await _readJsonBody(req);
      final cm = await engine.issueCreditMemo(
        id,
        reason: body['reason']?.toString() ?? 'Sales Return / Price Adjustment',
      );
      return await _sendJson(req.response, 201, cm.toJson());
    }

    if (req.method == 'POST' && path == '/api/connectors/xero') {
      final body = await _readJsonBody(req);
      final rec = await engine.ingestFromXero(
        body,
        taxpayerId: q['taxpayerId'],
      );
      return await _sendJson(req.response, 201, rec.toJson());
    }

    if (req.method == 'POST' && path == '/api/connectors/quickbooks') {
      final body = await _readJsonBody(req);
      final rec = await engine.ingestFromQuickBooks(
        body,
        taxpayerId: q['taxpayerId'],
      );
      return await _sendJson(req.response, 201, rec.toJson());
    }

    if (req.method == 'POST' && path == '/api/connectors/odoo') {
      final body = await _readJsonBody(req);
      final rec = await engine.ingestFromOdoo(
        body,
        taxpayerId: q['taxpayerId'],
      );
      return await _sendJson(req.response, 201, rec.toJson());
    }

    if (req.method == 'POST' && path == '/api/connectors/csv') {
      final body = await _readJsonBody(req);
      final recs = await engine.ingestFromCsvBatch(
        body['csv']?.toString() ?? '',
        taxpayerId: body['taxpayerId']?.toString(),
      );
      return await _sendJson(req.response, 201, {
        'importedCount': recs.length,
        'records': recs.map((r) => r.toJson()).toList(),
      });
    }

    if (req.method == 'GET' && path == '/api/cas/books') {
      return await _sendJson(
        req.response,
        200,
        engine.getCasBooks(
          taxpayerId: q['taxpayerId'],
          bookType: (q['bookType'] ?? 'ALL').toUpperCase(),
        ),
      );
    }

    if (req.method == 'GET' && path == '/api/statutory/slsp') {
      final kind = q['kind'] == 'PURCHASES' ? 'PURCHASES' : 'SALES';
      final period = q['period'] ?? '202611';
      return await _sendJson(
        req.response,
        200,
        engine.generateSlsp(q['taxpayerId'], kind, period: period),
      );
    }

    if (req.method == 'GET' && path == '/api/statutory/withholding') {
      final kind = q['kind'] == 'QAP' ? 'QAP' : 'SAWT';
      final period = q['period'] ?? '202612';
      return await _sendJson(
        req.response,
        200,
        engine.generateWithholdingDat(q['taxpayerId'], kind, period: period),
      );
    }

    if (req.method == 'GET' && path.startsWith('/api/statutory/form2307/')) {
      final invoiceId = path.split('/').last;
      return await _sendJson(
        req.response,
        200,
        engine.generateForm2307ForInvoice(invoiceId),
      );
    }

    if (req.method == 'GET' && path == '/api/audit-trail') {
      return await _sendJson(req.response, 200, {
        'verification': engine.auditTrail.verifyIntegrity(),
        'entries': engine.auditTrail
            .getEntries()
            .reversed
            .map((e) => e.toJson())
            .toList(),
      });
    }

    return await _sendJson(req.response, 404, {'error': 'Route not found: $path'});
  } catch (e) {
    return await _sendJson(req.response, 400, {'error': e.toString()});
  }
}
