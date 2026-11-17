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
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:async' as _i2;
import 'package:eis_client/src/protocol/greetings/greeting.dart' as _i3;
import 'protocol.dart' as _i4;

/// Serverpod RPC Endpoint exposing Philippine BIR EIS v2.01 & CAS operations
/// via generated `client.eis.*` methods.
/// {@category Endpoint}
class EndpointEis extends _i1.EndpointRef {
  EndpointEis(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'eis';

  _i2.Future<String> getDashboardSummary({String? taxpayerId}) =>
      caller.callServerEndpoint<String>(
        'eis',
        'getDashboardSummary',
        {'taxpayerId': taxpayerId},
      );

  _i2.Future<String> updateGatewayConfig({
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

  _i2.Future<String> getTaxpayers() => caller.callServerEndpoint<String>(
    'eis',
    'getTaxpayers',
    {},
  );

  _i2.Future<String> registerTaxpayer(String bodyJson) =>
      caller.callServerEndpoint<String>(
        'eis',
        'registerTaxpayer',
        {'bodyJson': bodyJson},
      );

  _i2.Future<String> rotateTaxpayerKeys(String taxpayerId) =>
      caller.callServerEndpoint<String>(
        'eis',
        'rotateTaxpayerKeys',
        {'taxpayerId': taxpayerId},
      );

  _i2.Future<String> getInvoices({String? taxpayerId}) =>
      caller.callServerEndpoint<String>(
        'eis',
        'getInvoices',
        {'taxpayerId': taxpayerId},
      );

  _i2.Future<String> createInvoice(String payloadJson) =>
      caller.callServerEndpoint<String>(
        'eis',
        'createInvoice',
        {'payloadJson': payloadJson},
      );

  _i2.Future<String> processRetryQueue() => caller.callServerEndpoint<String>(
    'eis',
    'processRetryQueue',
    {},
  );

  _i2.Future<String> issueCreditMemo(
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

  _i2.Future<String> syncConnector(
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

  _i2.Future<int> importCsvBatch(
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

  _i2.Future<String> getCasBooks({
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

  _i2.Future<String> generateSlsp({
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

  _i2.Future<String> generateWithholdingDat({
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

  _i2.Future<String> generateForm2307(String invoiceId) =>
      caller.callServerEndpoint<String>(
        'eis',
        'generateForm2307',
        {'invoiceId': invoiceId},
      );

  _i2.Future<String> getAuditTrail() => caller.callServerEndpoint<String>(
    'eis',
    'getAuditTrail',
    {},
  );
}

/// This is an example endpoint that returns a greeting message through
/// its [hello] method.
/// {@category Endpoint}
class EndpointGreeting extends _i1.EndpointRef {
  EndpointGreeting(_i1.EndpointCaller caller) : super(caller);

  @override
  String get name => 'greeting';

  /// Returns a personalized greeting message: "Hello {name}".
  _i2.Future<_i3.Greeting> hello(String name) =>
      caller.callServerEndpoint<_i3.Greeting>(
        'greeting',
        'hello',
        {'name': name},
      );
}

class Client extends _i1.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    @Deprecated(
      'Use authKeyProvider instead. This will be removed in future releases.',
    )
    super.authenticationKeyManager,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _i1.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_i1.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
  }) : super(
         host,
         _i4.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
       ) {
    eis = EndpointEis(this);
    greeting = EndpointGreeting(this);
  }

  late final EndpointEis eis;

  late final EndpointGreeting greeting;

  @override
  Map<String, _i1.EndpointRef> get endpointRefLookup => {
    'eis': eis,
    'greeting': greeting,
  };

  @override
  Map<String, _i1.ModuleEndpointCaller> get moduleLookup => {};
}
