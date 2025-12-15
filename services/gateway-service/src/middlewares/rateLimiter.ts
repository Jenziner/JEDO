import rateLimit, { RateLimitRequestHandler } from 'express-rate-limit';
import logger from '../config/logger';

/**
 * Create rate limiter for Gateway
 * Uses IP-based rate limiting (simple & effective)
 */
export function createRateLimit(
  max: number,
  windowMs: number = 60000, // 1 minute default
  type: string = 'general'
): RateLimitRequestHandler {
  return rateLimit({
    windowMs,
    max,

    // IP-based key (Gateway doesn't have client certs)
    keyGenerator: (req) => {
      return req.ip || 'unknown';
    },

    // Custom handler
    handler: (req, res) => {
      logger.warn(
        {
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
          message: `Too many requests. Please wait and try again.`,
          code: 'RATE_LIMIT_EXCEEDED',
          limit: max,
          windowMs,
          type,
        },
      });
    },

    standardHeaders: true,
    legacyHeaders: false,
  });
}

// ============================================
// Gateway Rate Limiters
// ============================================

/**
 * Global rate limit (applied to all routes in app.ts)
 */
export const globalRateLimiter = createRateLimit(
  1000,  // 1000 requests (großzügig für Gateway)
  15 * 60 * 1000, // per 15 minutes
  'global'
);

/**
 * API rate limit (for proxied API calls)
 */
export const apiRateLimiter = createRateLimit(
  100,   // 100 requests
  60000, // per minute
  'api'
);
