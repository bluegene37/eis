import crypto from 'node:crypto';
import { CompactSign, compactVerify, importPKCS8, importSPKI } from 'jose';

export interface GeneratedTaxpayerCryptoBundle {
  keyId: string;
  publicKeyPem: string;
  privateKeyPem: string;
  aesKeyHex: string;
}

export interface AesGcmEnvelope {
  algorithm: 'AES-256-GCM';
  ivHex: string;
  authTagHex: string;
  ciphertextBase64: string;
  sha256Digest: string;
}

/**
 * Generates an RSA-2048 signing keypair (for RFC 7515 JWS RS256) and a 256-bit AES key
 * for a Taxpayer TIN / EIS Certificate registration.
 */
export function generateTaxpayerCryptoBundle(tin: string, eisCertId: string): GeneratedTaxpayerCryptoBundle {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
    modulusLength: 2048,
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });
  const aesKeyHex = crypto.randomBytes(32).toString('hex'); // 256 bits
  const keyId = `bir-${tin}-${eisCertId}`.toLowerCase();

  return {
    keyId,
    publicKeyPem: publicKey,
    privateKeyPem: privateKey,
    aesKeyHex,
  };
}

/**
 * Signs a canonical BIR EIS v2.01 JSON object into an RFC 7515 JWS Compact token (RS256).
 */
export async function signBirPayloadJws(
  payload: unknown,
  privateKeyPem: string,
  keyId: string,
): Promise<string> {
  const privateKey = await importPKCS8(privateKeyPem, 'RS256');
  const encoded = new TextEncoder().encode(JSON.stringify(payload));
  return new CompactSign(encoded)
    .setProtectedHeader({ alg: 'RS256', typ: 'BIR-EIS+jwt', kid: keyId })
    .sign(privateKey);
}

/**
 * Verifies an RFC 7515 JWS Compact token against a Taxpayer's public key PEM.
 */
export async function verifyBirPayloadJws<T = unknown>(
  jwsToken: string,
  publicKeyPem: string,
): Promise<{ valid: boolean; payload?: T; thumbprint: string; error?: string }> {
  const thumbprint = crypto.createHash('sha256').update(jwsToken).digest('hex').slice(0, 16);
  try {
    const publicKey = await importSPKI(publicKeyPem, 'RS256');
    const { payload } = await compactVerify(jwsToken, publicKey);
    const parsed = JSON.parse(new TextDecoder().decode(payload)) as T;
    return { valid: true, payload: parsed, thumbprint };
  } catch (err) {
    return {
      valid: false,
      thumbprint,
      error: err instanceof Error ? err.message : 'Invalid JWS signature',
    };
  }
}

/**
 * Encrypts a signed JWS token using AES-256-GCM before transmission to BIR EIS.
 */
export function encryptJwsWithAes256(jwsToken: string, aesKeyHex: string): AesGcmEnvelope {
  const key = Buffer.from(aesKeyHex, 'hex');
  if (key.length !== 32) {
    throw new Error('AES-256 key must be 32 bytes (64 hex characters).');
  }
  const iv = crypto.randomBytes(12); // 96-bit GCM nonce
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([cipher.update(jwsToken, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  const sha256Digest = crypto.createHash('sha256').update(jwsToken).digest('hex');

  return {
    algorithm: 'AES-256-GCM',
    ivHex: iv.toString('hex'),
    authTagHex: authTag.toString('hex'),
    ciphertextBase64: ciphertext.toString('base64'),
    sha256Digest,
  };
}

/**
 * Decrypts an AES-256-GCM envelope back into the original JWS token.
 */
export function decryptAes256Envelope(envelope: AesGcmEnvelope, aesKeyHex: string): string {
  const key = Buffer.from(aesKeyHex, 'hex');
  const iv = Buffer.from(envelope.ivHex, 'hex');
  const authTag = Buffer.from(envelope.authTagHex, 'hex');
  const ciphertext = Buffer.from(envelope.ciphertextBase64, 'base64');

  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(authTag);
  const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  return decrypted.toString('utf8');
}
