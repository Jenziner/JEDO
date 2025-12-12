import rateLimit, { RateLimitRequestHandler } from 'express-rate-limit';
import { FabricProxyRequest } from './fabricProxy';
import { getCertIdentifier } from '../utils/certIdentifier';
import logger from '../config/logger';

/**
 * Create rate limiter with cert-based key generation
 * 
 * @param max - Maximum requests per window
 * @param type - Operation type for logging (e.g., 'financial-write')
 * @returns Express rate limit middleware
 */
export function createCertRateLimit(
  max: number,
  type: string
): RateLimitRequestHandler {
  return rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max,

    // Generate key per certificate + operation type
    keyGenerator: (req) => {
      const identifier = getCertIdentifier(req as FabricProxyRequest);
      return `${type}:${identifier}`;
    },

    // Custom handler for better error messages
    handler: (req, res) => {
      const identifier = getCertIdentifier(req as FabricProxyRequest);
      
      logger.warn(
        {
          identifier,
          ip: req.ip,
          path: req.path,
          method: req.method,
          type,
          limit: max,
        },
        'Rate limit exceeded'
      );

      res.status(429).json({
        success: false,
        error: {
          message: `Too many ${type.replace('-', ' ')} operations. Please wait and try again.`,
          code: 'RATE_LIMIT_EXCEEDED',
          limit: max,
          windowMs: 60000,
          type,
        },
      });
    },

    // RFC 6585 standard headers
    standardHeaders: true,
    legacyHeaders: false,

    // Skip successful requests from counting (optional)
    skipSuccessfulRequests: false,

    // Skip failed requests from counting (optional)
    skipFailedRequests: false,
  });
}

// ============================================
// Predefined rate limiters for common operations
// ============================================

/**
 * Financial write operations (transfers)
 * Very strict: 5 requests per minute
 */
export const financialWriteLimit = createCertRateLimit(5, 'financial-write');

/**
 * Wallet creation
 * Strict: 3 requests per minute (rarely needed)
 */
export const walletCreateLimit = createCertRateLimit(1, 'wallet-create');

/**
 * Balance queries
 * Generous: 100 requests per minute
 */
export const balanceReadLimit = createCertRateLimit(10, 'balance-read');

/**
 * History queries
 * Moderate: 50 requests per minute (returns more data)
 */
export const historyReadLimit = createCertRateLimit(10, 'history-read');

/**
 * Wallet detail queries
 * Generous: 100 requests per minute
 */
export const walletReadLimit = createCertRateLimit(10, 'wallet-read');

/**
 * Admin operations (low-level proxy)
 * Very strict: 5 requests per minute
 */
export const adminProxyLimit = createCertRateLimit(2, 'admin-proxy');

/**
 * Generic query operations (proxy evaluate)
 * Moderate: 50 requests per minute
 */
export const queryProxyLimit = createCertRateLimit(20, 'query-proxy');
