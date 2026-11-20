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
import 'dart:async' as _ida;
import 'package:eis_client/src/protocol/greetings/greeting.dart' as _ikwcg3p2;
import 'package:http/http.dart' as _i85jenna;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'protocol.dart' as _il2as5qe;

/// Serverpod RPC Endpoint exposing Philippine BIR EIS v2.01 & CAS operations
/// via generated `client.eis.*` methods.
/// {@category Endpoint}
class EndpointEis extends _isc.EndpointRef {
  EndpointEis(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'eis';

  _ida.Future<String> getDashboardSummary({String? taxpayerId}) =>
      caller.callServerEndpoint<String>(
        'eis',
        'getDashboardSummary',
        {'taxpayerId': taxpayerId},
      );

  _ida.Future<String> updateGatewayConfig({
    String? mode,
    bool? simulateOutage,
  }) => caller.callServerEndpoint<String>(
    'eis',
    'updateGatewayConfig',
    {
      'mode': mode,
      'simulateOutage': simulateOutage,
    },
  );

  _ida.Future<String> getTaxpayers() => caller.callServerEndpoint<String>(
    'eis',
    'getTaxpayers',
    {},
  );

  _ida.Future<String> registerTaxpayer(String bodyJson) =>
      caller.callServerEndpoint<String>(
        'eis',
        'registerTaxpayer',
        {'bodyJson': bodyJson},
      );

  _ida.Future<String> rotateTaxpayerKeys(String taxpayerId) =>
      caller.callServerEndpoint<String>(
        'eis',
        'rotateTaxpayerKeys',
        {'taxpayerId': taxpayerId},
      );

  _ida.Future<String> getInvoices({String? taxpayerId}) =>
      caller.callServerEndpoint<String>(
        'eis',
        'getInvoices',
        {'taxpayerId': taxpayerId},
      );

  _ida.Future<String> createInvoice(String payloadJson) =>
      caller.callServerEndpoint<String>(
        'eis',
        'createInvoice',
        {'payloadJson': payloadJson},
      );

  _ida.Future<String> processRetryQueue() => caller.callServerEndpoint<String>(
    'eis',
    'processRetryQueue',
    {},
  );

  _ida.Future<String> issueCreditMemo(
    String invoiceId, {
    required String reason,
  }) => caller.callServerEndpoint<String>(
    'eis',
    'issueCreditMemo',
    {
      'invoiceId': invoiceId,
      'reason': reason,
    },
  );

  _ida.Future<String> syncConnector(
    String connector,
    String payloadJson, {
    String? taxpayerId,
  }) => caller.callServerEndpoint<String>(
    'eis',
    'syncConnector',
    {
      'connector': connector,
      'payloadJson': payloadJson,
      'taxpayerId': taxpayerId,
    },
  );

  _ida.Future<int> importCsvBatch(
    String csvText, {
    String? taxpayerId,
  }) => caller.callServerEndpoint<int>(
    'eis',
    'importCsvBatch',
    {
      'csvText': csvText,
      'taxpayerId': taxpayerId,
    },
  );

  _ida.Future<String> getCasBooks({
    String? taxpayerId,
    required String bookType,
  }) => caller.callServerEndpoint<String>(
    'eis',
    'getCasBooks',
    {
      'taxpayerId': taxpayerId,
      'bookType': bookType,
    },
  );

  _ida.Future<String> generateSlsp({
    String? taxpayerId,
    required String kind,
    required String period,
  }) => caller.callServerEndpoint<String>(
    'eis',
    'generateSlsp',
    {
      'taxpayerId': taxpayerId,
      'kind': kind,
      'period': period,
    },
  );

  _ida.Future<String> generateWithholdingDat({
    String? taxpayerId,
    required String kind,
    required String period,
  }) => caller.callServerEndpoint<String>(
    'eis',
    'generateWithholdingDat',
    {
      'taxpayerId': taxpayerId,
      'kind': kind,
      'period': period,
    },
  );

  _ida.Future<String> generateForm2307(String invoiceId) =>
      caller.callServerEndpoint<String>(
        'eis',
        'generateForm2307',
        {'invoiceId': invoiceId},
      );

  _ida.Future<String> getAuditTrail() => caller.callServerEndpoint<String>(
    'eis',
    'getAuditTrail',
    {},
  );
}

/// This is an example endpoint that returns a greeting message through
/// its [hello] method.
/// {@category Endpoint}
class EndpointGreeting extends _isc.EndpointRef {
  EndpointGreeting(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'greeting';

  /// Returns a personalized greeting message: "Hello {name}".
  _ida.Future<_ikwcg3p2.Greeting> hello(String name) =>
      caller.callServerEndpoint<_ikwcg3p2.Greeting>(
        'greeting',
        'hello',
        {'name': name},
      );
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _isc.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    eis = EndpointEis(this);
    greeting = EndpointGreeting(this);
  }

  late final EndpointEis eis;

  late final EndpointGreeting greeting;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'eis': eis,
    'greeting': greeting,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {};
}
