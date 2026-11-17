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
import 'package:serverpod/serverpod.dart' as _i1;
import '../endpoints/eis_endpoint.dart' as _i2;
import '../greetings/greeting_endpoint.dart' as _i3;

class Endpoints extends _i1.EndpointDispatch {
  @override
  void initializeEndpoints(_i1.Server server) {
    var endpoints = <String, _i1.Endpoint>{
      'eis': _i2.EisEndpoint()
        ..initialize(
          server,
          'eis',
          null,
        ),
      'greeting': _i3.GreetingEndpoint()
        ..initialize(
          server,
          'greeting',
          null,
        ),
    };
    connectors['eis'] = _i1.EndpointConnector(
      name: 'eis',
      endpoint: endpoints['eis']!,
      methodConnectors: {
        'getDashboardSummary': _i1.MethodConnector(
          name: 'getDashboardSummary',
          params: {
            'taxpayerId': _i1.ParameterDescription(
              name: 'taxpayerId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i2.EisEndpoint).getDashboardSummary(
                    session,
                    taxpayerId: params['taxpayerId'],
                  ),
        ),
        'updateGatewayConfig': _i1.MethodConnector(
          name: 'updateGatewayConfig',
          params: {
            'mode': _i1.ParameterDescription(
              name: 'mode',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'simulateOutage': _i1.ParameterDescription(
              name: 'simulateOutage',
              type: _i1.getType<bool?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i2.EisEndpoint).updateGatewayConfig(
                    session,
                    mode: params['mode'],
                    simulateOutage: params['simulateOutage'],
                  ),
        ),
        'getTaxpayers': _i1.MethodConnector(
          name: 'getTaxpayers',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i2.EisEndpoint).getTaxpayers(session),
        ),
        'registerTaxpayer': _i1.MethodConnector(
          name: 'registerTaxpayer',
          params: {
            'bodyJson': _i1.ParameterDescription(
              name: 'bodyJson',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i2.EisEndpoint).registerTaxpayer(
                session,
                params['bodyJson'],
              ),
        ),
        'rotateTaxpayerKeys': _i1.MethodConnector(
          name: 'rotateTaxpayerKeys',
          params: {
            'taxpayerId': _i1.ParameterDescription(
              name: 'taxpayerId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i2.EisEndpoint).rotateTaxpayerKeys(
                    session,
                    params['taxpayerId'],
                  ),
        ),
        'getInvoices': _i1.MethodConnector(
          name: 'getInvoices',
          params: {
            'taxpayerId': _i1.ParameterDescription(
              name: 'taxpayerId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i2.EisEndpoint).getInvoices(
                session,
                taxpayerId: params['taxpayerId'],
              ),
        ),
        'createInvoice': _i1.MethodConnector(
          name: 'createInvoice',
          params: {
            'payloadJson': _i1.ParameterDescription(
              name: 'payloadJson',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i2.EisEndpoint).createInvoice(
                session,
                params['payloadJson'],
              ),
        ),
        'processRetryQueue': _i1.MethodConnector(
          name: 'processRetryQueue',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i2.EisEndpoint)
                  .processRetryQueue(session),
        ),
        'issueCreditMemo': _i1.MethodConnector(
          name: 'issueCreditMemo',
          params: {
            'invoiceId': _i1.ParameterDescription(
              name: 'invoiceId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'reason': _i1.ParameterDescription(
              name: 'reason',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i2.EisEndpoint).issueCreditMemo(
                session,
                params['invoiceId'],
                reason: params['reason'],
              ),
        ),
        'syncConnector': _i1.MethodConnector(
          name: 'syncConnector',
          params: {
            'connector': _i1.ParameterDescription(
              name: 'connector',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'payloadJson': _i1.ParameterDescription(
              name: 'payloadJson',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'taxpayerId': _i1.ParameterDescription(
              name: 'taxpayerId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i2.EisEndpoint).syncConnector(
                session,
                params['connector'],
                params['payloadJson'],
                taxpayerId: params['taxpayerId'],
              ),
        ),
        'importCsvBatch': _i1.MethodConnector(
          name: 'importCsvBatch',
          params: {
            'csvText': _i1.ParameterDescription(
              name: 'csvText',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'taxpayerId': _i1.ParameterDescription(
              name: 'taxpayerId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i2.EisEndpoint).importCsvBatch(
                session,
                params['csvText'],
                taxpayerId: params['taxpayerId'],
              ),
        ),
        'getCasBooks': _i1.MethodConnector(
          name: 'getCasBooks',
          params: {
            'taxpayerId': _i1.ParameterDescription(
              name: 'taxpayerId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'bookType': _i1.ParameterDescription(
              name: 'bookType',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i2.EisEndpoint).getCasBooks(
                session,
                taxpayerId: params['taxpayerId'],
                bookType: params['bookType'],
              ),
        ),
        'generateSlsp': _i1.MethodConnector(
          name: 'generateSlsp',
          params: {
            'taxpayerId': _i1.ParameterDescription(
              name: 'taxpayerId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'kind': _i1.ParameterDescription(
              name: 'kind',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'period': _i1.ParameterDescription(
              name: 'period',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i2.EisEndpoint).generateSlsp(
                session,
                taxpayerId: params['taxpayerId'],
                kind: params['kind'],
                period: params['period'],
              ),
        ),
        'generateWithholdingDat': _i1.MethodConnector(
          name: 'generateWithholdingDat',
          params: {
            'taxpayerId': _i1.ParameterDescription(
              name: 'taxpayerId',
              type: _i1.getType<String?>(),
              nullable: true,
            ),
            'kind': _i1.ParameterDescription(
              name: 'kind',
              type: _i1.getType<String>(),
              nullable: false,
            ),
            'period': _i1.ParameterDescription(
              name: 'period',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i2.EisEndpoint).generateWithholdingDat(
                    session,
                    taxpayerId: params['taxpayerId'],
                    kind: params['kind'],
                    period: params['period'],
                  ),
        ),
        'generateForm2307': _i1.MethodConnector(
          name: 'generateForm2307',
          params: {
            'invoiceId': _i1.ParameterDescription(
              name: 'invoiceId',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['eis'] as _i2.EisEndpoint).generateForm2307(
                session,
                params['invoiceId'],
              ),
        ),
        'getAuditTrail': _i1.MethodConnector(
          name: 'getAuditTrail',
          params: {},
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['eis'] as _i2.EisEndpoint).getAuditTrail(session),
        ),
      },
    );
    connectors['greeting'] = _i1.EndpointConnector(
      name: 'greeting',
      endpoint: endpoints['greeting']!,
      methodConnectors: {
        'hello': _i1.MethodConnector(
          name: 'hello',
          params: {
            'name': _i1.ParameterDescription(
              name: 'name',
              type: _i1.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _i1.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['greeting'] as _i3.GreetingEndpoint).hello(
                session,
                params['name'],
              ),
        ),
      },
    );
  }
}
