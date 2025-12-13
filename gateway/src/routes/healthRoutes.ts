import { Router, Request, Response } from 'express';
import { serviceConfig } from '../config/services';
import logger from '../config/logger';

const router = Router();

interface HealthResponse {
  success: boolean;
  data: {
    status: string;
    timestamp: string;
    uptime: number;
    environment: string;
    version: string;
    services?: {
      name: string;
      status: 'up' | 'down';
    }[];
  };
}

/**
 * GET /health
 * Liveness probe - is the Gateway running?
 */
router.get('/health', (_req: Request, res: Response<HealthResponse>) => {
  try {
    const healthcheck: HealthResponse = {
      success: true,
      data: {
        status: 'Healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
        version: '1.0.0',
      },
    };

    res.status(200).json(healthcheck);
  } catch (error) {
    res.status(500).json({
      success: false,
      data: {
        status: 'ERROR',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
        version: '1.0.0',
      },
    });
  }
});

/**
 * GET /ready
 * Readiness probe - are backend services reachable?
 */
router.get('/ready', async (_req: Request, res: Response) => {
  try {
    // Check backend services
    const serviceChecks = await Promise.allSettled([
      checkServiceHealth('ledgerService'),
      checkServiceHealth('caService'),
    ]);

    const results = [
      { name: 'ledger', status: serviceChecks[0].status === 'fulfilled' && serviceChecks[0].value ? 'up' : 'down' },
      { name: 'ca', status: serviceChecks[1].status === 'fulfilled' && serviceChecks[1].value ? 'up' : 'down' },
    ];

    const allReady = results.every((r) => r.status === 'up');

    if (!allReady) {
      logger.warn({ services: results }, 'Gateway not ready');
      return res.status(503).json({
        success: false,
        data: {
          status: 'Not Ready',
          message: 'Backend services unavailable',
          timestamp: new Date().toISOString(),
          uptime: process.uptime(),
          environment: process.env.NODE_ENV || 'development',
          version: '1.0.0',
          services: results,
        },
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        status: 'Ready',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
        version: '1.0.0',
        services: results,
      },
    });
  } catch (error) {
    logger.error({ err: error }, 'Readiness check failed');
    return res.status(503).json({
      success: false,
      data: {
        status: 'Not Ready',
        message: 'Readiness check failed',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
        version: '1.0.0',
      },
    });
  }
});

/**
 * GET /live
 * Simple liveness check
 */
router.get('/live', (_req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    data: {
      status: 'Alive',
      timestamp: new Date().toISOString(),
    },
  });
});

/**
 * Helper: Check if backend service is healthy
 */
async function checkServiceHealth(
  serviceName: keyof typeof serviceConfig
): Promise<boolean> {
  const config = serviceConfig[serviceName];
  const healthUrl = `${config.url}${config.healthPath}`;

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3000); // 3s timeout

    const response = await fetch(healthUrl, {
      method: 'GET',
      signal: controller.signal,
      headers: { 'User-Agent': 'jedo-gateway-health' },
    });

    clearTimeout(timeoutId);
    return response.ok;
  } catch (error) {
    logger.debug({ service: serviceName, error }, 'Service health check failed');
    return false;
  }
}

export default router;
