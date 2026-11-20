/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _is;
import '../endpoints/eis_endpoint.dart' as _i6oenk0g;
import '../greetings/greeting_endpoint.dart' as _il624ik7;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    initializeOwnEndpoints(server);
  }

  @override
  void initializeOwnEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'eis': _i6oenk0g.EisEndpoint()
        ..initialize(
          server,
          'eis',
          null,
        ),
      'greeting': _il624ik7.GreetingEndpoint()
        ..initialize(
          server,
          'greeting',
          null,
        ),
    };
    connectors['eis'] = _is.EndpointConnector(
      name: 'eis',
      endpoint: endpoints['eis']!,
      methodConnectors: {
        'getDashboardSummary': _is.MethodConnector(
          name: 'getDashboardSummary',
          params: {
            'taxpayerId': _is.ParameterDescription(
              name: 'taxpayerId',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i6oenk0g.EisEndpoint)
                  .getDashboardSummary(
                    session,
                    taxpayerId: params['taxpayerId'],
                  ),
        ),
        'updateGatewayConfig': _is.MethodConnector(
          name: 'updateGatewayConfig',
          params: {
            'mode': _is.ParameterDescription(
              name: 'mode',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'simulateOutage': _is.ParameterDescription(
              name: 'simulateOutage',
              type: _is.getType<bool?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i6oenk0g.EisEndpoint)
                  .updateGatewayConfig(
                    session,
                    mode: params['mode'],
                    simulateOutage: params['simulateOutage'],
                  ),
        ),
        'getTaxpayers': _is.MethodConnector(
          name: 'getTaxpayers',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i6oenk0g.EisEndpoint)
                  .getTaxpayers(session),
        ),
        'registerTaxpayer': _is.MethodConnector(
          name: 'registerTaxpayer',
          params: {
            'bodyJson': _is.ParameterDescription(
              name: 'bodyJson',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i6oenk0g.EisEndpoint).registerTaxpayer(
                    session,
                    params['bodyJson'],
                  ),
        ),
        'rotateTaxpayerKeys': _is.MethodConnector(
          name: 'rotateTaxpayerKeys',
          params: {
            'taxpayerId': _is.ParameterDescription(
              name: 'taxpayerId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i6oenk0g.EisEndpoint)
                  .rotateTaxpayerKeys(
                    session,
                    params['taxpayerId'],
                  ),
        ),
        'getInvoices': _is.MethodConnector(
          name: 'getInvoices',
          params: {
            'taxpayerId': _is.ParameterDescription(
              name: 'taxpayerId',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i6oenk0g.EisEndpoint).getInvoices(
                    session,
                    taxpayerId: params['taxpayerId'],
                  ),
        ),
        'createInvoice': _is.MethodConnector(
          name: 'createInvoice',
          params: {
            'payloadJson': _is.ParameterDescription(
              name: 'payloadJson',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i6oenk0g.EisEndpoint).createInvoice(
                    session,
                    params['payloadJson'],
                  ),
        ),
        'processRetryQueue': _is.MethodConnector(
          name: 'processRetryQueue',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i6oenk0g.EisEndpoint)
                  .processRetryQueue(session),
        ),
        'issueCreditMemo': _is.MethodConnector(
          name: 'issueCreditMemo',
          params: {
            'invoiceId': _is.ParameterDescription(
              name: 'invoiceId',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'reason': _is.ParameterDescription(
              name: 'reason',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i6oenk0g.EisEndpoint).issueCreditMemo(
                    session,
                    params['invoiceId'],
                    reason: params['reason'],
                  ),
        ),
        'syncConnector': _is.MethodConnector(
          name: 'syncConnector',
          params: {
            'connector': _is.ParameterDescription(
              name: 'connector',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'payloadJson': _is.ParameterDescription(
              name: 'payloadJson',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'taxpayerId': _is.ParameterDescription(
              name: 'taxpayerId',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i6oenk0g.EisEndpoint).syncConnector(
                    session,
                    params['connector'],
                    params['payloadJson'],
                    taxpayerId: params['taxpayerId'],
                  ),
        ),
        'importCsvBatch': _is.MethodConnector(
          name: 'importCsvBatch',
          params: {
            'csvText': _is.ParameterDescription(
              name: 'csvText',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'taxpayerId': _is.ParameterDescription(
              name: 'taxpayerId',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i6oenk0g.EisEndpoint).importCsvBatch(
                    session,
                    params['csvText'],
                    taxpayerId: params['taxpayerId'],
                  ),
        ),
        'getCasBooks': _is.MethodConnector(
          name: 'getCasBooks',
          params: {
            'taxpayerId': _is.ParameterDescription(
              name: 'taxpayerId',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'bookType': _is.ParameterDescription(
              name: 'bookType',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i6oenk0g.EisEndpoint).getCasBooks(
                    session,
                    taxpayerId: params['taxpayerId'],
                    bookType: params['bookType'],
                  ),
        ),
        'generateSlsp': _is.MethodConnector(
          name: 'generateSlsp',
          params: {
            'taxpayerId': _is.ParameterDescription(
              name: 'taxpayerId',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'kind': _is.ParameterDescription(
              name: 'kind',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'period': _is.ParameterDescription(
              name: 'period',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i6oenk0g.EisEndpoint).generateSlsp(
                    session,
                    taxpayerId: params['taxpayerId'],
                    kind: params['kind'],
                    period: params['period'],
                  ),
        ),
        'generateWithholdingDat': _is.MethodConnector(
          name: 'generateWithholdingDat',
          params: {
            'taxpayerId': _is.ParameterDescription(
              name: 'taxpayerId',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'kind': _is.ParameterDescription(
              name: 'kind',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'period': _is.ParameterDescription(
              name: 'period',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i6oenk0g.EisEndpoint)
                  .generateWithholdingDat(
                    session,
                    taxpayerId: params['taxpayerId'],
                    kind: params['kind'],
                    period: params['period'],
                  ),
        ),
        'generateForm2307': _is.MethodConnector(
          name: 'generateForm2307',
          params: {
            'invoiceId': _is.ParameterDescription(
              name: 'invoiceId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i6oenk0g.EisEndpoint).generateForm2307(
                    session,
                    params['invoiceId'],
                  ),
        ),
        'getAuditTrail': _is.MethodConnector(
          name: 'getAuditTrail',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i6oenk0g.EisEndpoint)
                  .getAuditTrail(session),
        ),
      },
    );
    connectors['greeting'] = _is.EndpointConnector(
      name: 'greeting',
      endpoint: endpoints['greeting']!,
      methodConnectors: {
        'hello': _is.MethodConnector(
          name: 'hello',
          params: {
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['greeting'] as _il624ik7.GreetingEndpoint).hello(
                    session,
                    params['name'],
                  ),
        ),
      },
    );
  }
}
