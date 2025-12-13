import * as crypto from 'crypto';
import { FabricProxyRequest } from '../middlewares/fabricProxy';

/**
 * Generate unique identifier from client certificate
 * Uses SHA256 hash for anonymity
 * 
 * @param req - Request with fabricIdentity
 * @returns Unique identifier string (e.g., "cert:a1b2c3d4e5f67890")
 */
export function getCertIdentifier(req: FabricProxyRequest): string {
  if (!req.fabricIdentity?.certificate) {
    // Fallback to IP if no cert present
    return `ip:${req.ip || 'unknown'}`;
  }

  // SHA256 hash of certificate (first 16 chars for brevity)
  const certHash = crypto
    .createHash('sha256')
    .update(req.fabricIdentity.certificate)
    .digest('hex')
    .substring(0, 16);

  return `cert:${certHash}`;
}
