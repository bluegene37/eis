import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as std_crypto;
import 'package:pointycastle/export.dart';
import 'bir_eis_schema.dart';

class GeneratedTaxpayerCryptoBundle {
  final String keyId;
  final String publicKeyJson;
  final String privateKeyJson;
  final String aesKeyHex;

  const GeneratedTaxpayerCryptoBundle({
    required this.keyId,
    required this.publicKeyJson,
    required this.privateKeyJson,
    required this.aesKeyHex,
  });
}

FortunaRandom _secureRandom() {
  final secureRandom = FortunaRandom();
  final random = Random.secure();
  final seeds = List<int>.generate(32, (_) => random.nextInt(256));
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
  return secureRandom;
}

String _encodeRsaPublicKey(RSAPublicKey key) => jsonEncode({
      'kty': 'RSA',
      'n': key.modulus!.toRadixString(16),
      'e': key.exponent!.toRadixString(16),
    });

RSAPublicKey _decodeRsaPublicKey(String encoded) {
  final map = jsonDecode(encoded) as Map<String, dynamic>;
  return RSAPublicKey(
    BigInt.parse(map['n'] as String, radix: 16),
    BigInt.parse(map['e'] as String, radix: 16),
  );
}

String _encodeRsaPrivateKey(RSAPrivateKey key) => jsonEncode({
      'kty': 'RSA',
      'n': key.modulus!.toRadixString(16),
      'd': key.privateExponent!.toRadixString(16),
      'p': key.p!.toRadixString(16),
      'q': key.q!.toRadixString(16),
    });

RSAPrivateKey _decodeRsaPrivateKey(String encoded) {
  final map = jsonDecode(encoded) as Map<String, dynamic>;
  return RSAPrivateKey(
    BigInt.parse(map['n'] as String, radix: 16),
    BigInt.parse(map['d'] as String, radix: 16),
    BigInt.parse(map['p'] as String, radix: 16),
    BigInt.parse(map['q'] as String, radix: 16),
  );
}

String _base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List _decodeBase64Url(String input) {
  final normalized = base64Url.normalize(input);
  return base64Url.decode(normalized);
}

String _bytesToHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

/// Generates an RSA-2048 signing keypair (for RFC 7515 JWS RS256) and a 256-bit AES key.
GeneratedTaxpayerCryptoBundle generateTaxpayerCryptoBundle(
  String tin,
  String eisCertId,
) {
  final keyGen = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        _secureRandom(),
      ),
    );
  final pair = keyGen.generateKeyPair();
  final pub = pair.publicKey;
  final priv = pair.privateKey;

  final rng = Random.secure();
  final aesBytes = Uint8List.fromList(
    List<int>.generate(32, (_) => rng.nextInt(256)),
  );

  return GeneratedTaxpayerCryptoBundle(
    keyId: 'bir-$tin-$eisCertId'.toLowerCase(),
    publicKeyJson: _encodeRsaPublicKey(pub),
    privateKeyJson: _encodeRsaPrivateKey(priv),
    aesKeyHex: _bytesToHex(aesBytes),
  );
}

/// Signs a JSON-serializable payload using RFC 7515 JWS Compact (RS256).
String signBirPayloadJws(
  Object payload,
  String privateKeyJson,
  String keyId,
) {
  final header = _base64UrlNoPad(
    utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'BIR-EIS+jwt', 'kid': keyId})),
  );
  final body = _base64UrlNoPad(utf8.encode(jsonEncode(payload)));
  final signingInput = '$header.$body';

  final privKey = _decodeRsaPrivateKey(privateKeyJson);
  final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
  signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privKey));
  final sig = signer.generateSignature(
    Uint8List.fromList(utf8.encode(signingInput)),
  );

  return '$signingInput.${_base64UrlNoPad(sig.bytes)}';
}

/// Verifies an RFC 7515 JWS Compact token against a Taxpayer's RSA-2048 public key.
({
  bool valid,
  Map<String, dynamic>? payload,
  String thumbprint,
  String? error,
}) verifyBirPayloadJws(String jwsToken, String publicKeyJson) {
  final thumbprint = std_crypto.sha256
      .convert(utf8.encode(jwsToken))
      .toString()
      .substring(0, 16);
  try {
    final parts = jwsToken.split('.');
    if (parts.length != 3) {
      return (
        valid: false,
        payload: null,
        thumbprint: thumbprint,
        error: 'Malformed JWS compact token',
      );
    }
    final signingInput = Uint8List.fromList(utf8.encode('${parts[0]}.${parts[1]}'));
    final signatureBytes = _decodeBase64Url(parts[2]);
    final pubKey = _decodeRsaPublicKey(publicKeyJson);

    final verifier = RSASigner(SHA256Digest(), '0609608648016503040201');
    verifier.init(false, PublicKeyParameter<RSAPublicKey>(pubKey));
    final ok = verifier.verifySignature(
      signingInput,
      RSASignature(signatureBytes),
    );
    if (!ok) {
      return (
        valid: false,
        payload: null,
        thumbprint: thumbprint,
        error: 'RSA-SHA256 signature verification failed',
      );
    }

    final decodedJson =
        jsonDecode(utf8.decode(_decodeBase64Url(parts[1]))) as Map<String, dynamic>;
    return (
      valid: true,
      payload: decodedJson,
      thumbprint: thumbprint,
      error: null,
    );
  } catch (e) {
    return (
      valid: false,
      payload: null,
      thumbprint: thumbprint,
      error: e.toString(),
    );
  }
}

/// Encrypts a signed JWS token with AES-256-GCM before BIR EIS transmission.
AesGcmEnvelope encryptJwsWithAes256(String jwsToken, String aesKeyHex) {
  final keyBytes = _hexToBytes(aesKeyHex);
  if (keyBytes.length != 32) {
    throw ArgumentError('AES-256 key must be 32 bytes (64 hex chars).');
  }
  final rng = Random.secure();
  final iv = Uint8List.fromList(List<int>.generate(12, (_) => rng.nextInt(256)));
  final plaintext = Uint8List.fromList(utf8.encode(jwsToken));

  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(KeyParameter(keyBytes), 128, iv, Uint8List(0)),
    );
  final out = cipher.process(plaintext);
  // PointyCastle GCM appends 16-byte authentication tag at the end
  final ciphertext = out.sublist(0, out.length - 16);
  final authTag = out.sublist(out.length - 16);
  final digest = std_crypto.sha256.convert(utf8.encode(jwsToken)).toString();

  return AesGcmEnvelope(
    algorithm: 'AES-256-GCM',
    ivHex: _bytesToHex(iv),
    authTagHex: _bytesToHex(authTag),
    ciphertextBase64: base64.encode(ciphertext),
    sha256Digest: digest,
  );
}

/// Decrypts an AES-256-GCM envelope back into the original JWS token.
String decryptAes256Envelope(AesGcmEnvelope envelope, String aesKeyHex) {
  final keyBytes = _hexToBytes(aesKeyHex);
  final iv = _hexToBytes(envelope.ivHex);
  final authTag = _hexToBytes(envelope.authTagHex);
  final ciphertext = base64.decode(envelope.ciphertextBase64);
  final combined = Uint8List.fromList([...ciphertext, ...authTag]);

  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      false,
      AEADParameters(KeyParameter(keyBytes), 128, iv, Uint8List(0)),
    );
  final decrypted = cipher.process(combined);
  return utf8.decode(decrypted);
}
