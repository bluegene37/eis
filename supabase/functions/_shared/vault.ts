// Gene - Nov, 24, 2026: Native WebCrypto RSA-2048 JWS (RS256), AES-256-GCM BIR envelope,
// and envelope-encrypted taxpayer secret vault helpers.

export interface GeneratedTaxpayerCryptoBundle {
  keyId: string;
  publicKeyJson: string;
  privateKeyJson: string;
  aesKeyHex: string;
}

export interface AesGcmEnvelope {
  algorithm: string;
  ivHex: string;
  authTagHex: string;
  ciphertextBase64: string;
  sha256Digest: string;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function hexToBytes(hex: string): Uint8Array {
  const clean = hex.trim();
  if (clean.length % 2 !== 0 || !/^[0-9a-fA-F]+$/.test(clean)) {
    throw new Error('Invalid hex string.');
  }
  const out = new Uint8Array(clean.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

function base64ToBytes(b64: string): Uint8Array {
  const binary = atob(b64);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

function base64UrlNoPad(bytes: Uint8Array): string {
  return bytesToBase64(bytes)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function decodeBase64Url(input: string): Uint8Array {
  const padLen = (4 - (input.length % 4)) % 4;
  const normalized = input.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat(padLen);
  return base64ToBytes(normalized);
}

async function sha256Bytes(bytes: Uint8Array): Promise<Uint8Array> {
  const copy = new Uint8Array(bytes);
  const digest = await crypto.subtle.digest('SHA-256', copy.buffer);
  return new Uint8Array(digest);
}

export async function sha256HexString(text: string): Promise<string> {
  const digest = await sha256Bytes(new TextEncoder().encode(text));
  return bytesToHex(digest);
}

async function getVaultMasterCryptoKey(
  usages: KeyUsage[],
): Promise<CryptoKey> {
  const rawHex = Deno.env.get('EIS_VAULT_MASTER_KEY')?.trim() ?? '';
  let keyBytes: Uint8Array;

  if (rawHex.length > 0) {
    if (!/^[0-9a-fA-F]{64}$/.test(rawHex)) {
      throw new Error(
        'EIS_VAULT_MASTER_KEY must be a 64-character hex-encoded 256-bit key.',
      );
    }
    keyBytes = hexToBytes(rawHex);
  } else if (Deno.env.get('EIS_ALLOW_DEV_VAULT_FALLBACK') === 'true') {
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')?.trim() ?? '';
    if (!serviceKey) {
      throw new Error(
        'Cannot derive local dev vault key without SUPABASE_SERVICE_ROLE_KEY.',
      );
    }
    keyBytes = await sha256Bytes(
      new TextEncoder().encode(`${serviceKey}:eis-local-dev-vault`),
    );
  } else {
    throw new Error(
      'EIS_VAULT_MASTER_KEY is required when EIS_ALLOW_DEV_VAULT_FALLBACK is not true.',
    );
  }

  return await crypto.subtle.importKey(
    'raw',
    new Uint8Array(keyBytes).buffer,
    { name: 'AES-GCM', length: 256 },
    false,
    usages,
  );
}

export async function encryptVaultSecret(plaintext: string): Promise<string> {
  const key = await getVaultMasterCryptoKey(['encrypt']);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encoded = new TextEncoder().encode(plaintext);
  const cipherBuffer = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: iv.buffer, tagLength: 128 },
    key,
    encoded.buffer,
  );
  return `v1:${bytesToHex(iv)}:${bytesToBase64(new Uint8Array(cipherBuffer))}`;
}

export async function decryptVaultSecret(packed: string): Promise<string> {
  const parts = packed.split(':');
  if (parts.length !== 3 || parts[0] !== 'v1') {
    throw new Error('Malformed encrypted vault secret envelope.');
  }
  const key = await getVaultMasterCryptoKey(['decrypt']);
  const iv = hexToBytes(parts[1]);
  const cipherBytes = base64ToBytes(parts[2]);
  const plainBuffer = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: new Uint8Array(iv).buffer, tagLength: 128 },
    key,
    new Uint8Array(cipherBytes).buffer,
  );
  return new TextDecoder().decode(plainBuffer);
}

export async function generateTaxpayerCryptoBundle(
  tin: string,
  eisCertId: string,
): Promise<GeneratedTaxpayerCryptoBundle> {
  const keyPair = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  );

  const pubJwk = await crypto.subtle.exportKey('jwk', keyPair.publicKey);
  const privJwk = await crypto.subtle.exportKey('jwk', keyPair.privateKey);
  const aesBytes = crypto.getRandomValues(new Uint8Array(32));

  return {
    keyId: `bir-${tin}-${eisCertId}`.toLowerCase(),
    publicKeyJson: JSON.stringify(pubJwk),
    privateKeyJson: JSON.stringify(privJwk),
    aesKeyHex: bytesToHex(aesBytes),
  };
}

export async function signBirPayloadJws(
  payload: unknown,
  privateKeyJson: string,
  keyId: string,
): Promise<string> {
  const header = base64UrlNoPad(
    new TextEncoder().encode(
      JSON.stringify({ alg: 'RS256', typ: 'BIR-EIS+jwt', kid: keyId }),
    ),
  );
  const body = base64UrlNoPad(
    new TextEncoder().encode(JSON.stringify(payload)),
  );
  const signingInput = `${header}.${body}`;

  const privJwk = JSON.parse(privateKeyJson) as JsonWebKey;
  const privKey = await crypto.subtle.importKey(
    'jwk',
    privJwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const sigBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privKey,
    new TextEncoder().encode(signingInput).buffer,
  );

  return `${signingInput}.${base64UrlNoPad(new Uint8Array(sigBuffer))}`;
}

export async function verifyBirPayloadJws(
  jwsToken: string,
  publicKeyJson: string,
): Promise<{
  valid: boolean;
  payload: Record<string, unknown> | null;
  thumbprint: string;
  error: string | null;
}> {
  const thumbprint = await sha256HexString(jwsToken);
  const parts = jwsToken.split('.');
  if (parts.length !== 3) {
    return {
      valid: false,
      payload: null,
      thumbprint,
      error: 'Malformed JWS Compact serialization (expected 3 segments).',
    };
  }

  try {
    const headerJson = JSON.parse(
      new TextDecoder().decode(decodeBase64Url(parts[0])),
    ) as Record<string, unknown>;
    if (headerJson['alg'] !== 'RS256') {
      return {
        valid: false,
        payload: null,
        thumbprint,
        error: `Unsupported JWS alg: ${headerJson['alg']}`,
      };
    }

    const pubJwk = JSON.parse(publicKeyJson) as JsonWebKey;
    const pubKey = await crypto.subtle.importKey(
      'jwk',
      pubJwk,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['verify'],
    );

    const signingInput = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
    const sigBytes = decodeBase64Url(parts[2]);
    const valid = await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      pubKey,
      new Uint8Array(sigBytes).buffer,
      new Uint8Array(signingInput).buffer,
    );

    if (!valid) {
      return {
        valid: false,
        payload: null,
        thumbprint,
        error: 'RSA-2048 RS256 JWS signature verification failed.',
      };
    }

    const payload = JSON.parse(
      new TextDecoder().decode(decodeBase64Url(parts[1])),
    ) as Record<string, unknown>;
    return { valid: true, payload, thumbprint, error: null };
  } catch (err) {
    return {
      valid: false,
      payload: null,
      thumbprint,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

export async function encryptJwsWithAes256(
  jwsToken: string,
  aesKeyHex: string,
): Promise<AesGcmEnvelope> {
  const keyBytes = hexToBytes(aesKeyHex);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const plainBytes = new TextEncoder().encode(jwsToken);

  const key = await crypto.subtle.importKey(
    'raw',
    new Uint8Array(keyBytes).buffer,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt'],
  );

  const combined = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv: iv.buffer, tagLength: 128 },
      key,
      plainBytes.buffer,
    ),
  );

  const tagLen = 16;
  const ciphertext = combined.subarray(0, combined.length - tagLen);
  const authTag = combined.subarray(combined.length - tagLen);

  return {
    algorithm: 'AES-256-GCM',
    ivHex: bytesToHex(iv),
    authTagHex: bytesToHex(authTag),
    ciphertextBase64: bytesToBase64(ciphertext),
    sha256Digest: await sha256HexString(jwsToken),
  };
}

export async function decryptAes256Envelope(
  envelope: AesGcmEnvelope,
  aesKeyHex: string,
): Promise<string> {
  const keyBytes = hexToBytes(aesKeyHex);
  const iv = hexToBytes(envelope.ivHex);
  const ciphertext = base64ToBytes(envelope.ciphertextBase64);
  const authTag = hexToBytes(envelope.authTagHex);

  const combined = new Uint8Array(ciphertext.length + authTag.length);
  combined.set(ciphertext, 0);
  combined.set(authTag, ciphertext.length);

  const key = await crypto.subtle.importKey(
    'raw',
    new Uint8Array(keyBytes).buffer,
    { name: 'AES-GCM', length: 256 },
    false,
    ['decrypt'],
  );

  const plainBuffer = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: new Uint8Array(iv).buffer, tagLength: 128 },
    key,
    combined.buffer,
  );
  const jws = new TextDecoder().decode(plainBuffer);
  const digest = await sha256HexString(jws);
  if (digest !== envelope.sha256Digest) {
    throw new Error('SEC001: AES-256-GCM payload SHA-256 digest mismatch.');
  }
  return jws;
}
