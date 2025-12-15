import https from 'https';
import fs from 'fs';
import { env } from '../config/environment';
import { Router, Request, Response } from 'express';
import { serviceConfig } from '../config/services';
import logger from '../config/logger';

const router = Router();

// TLS Agent for service-to-service communication
// TODO: Use CA cert verification in production
const serviceAgent = new https.Agent({
  ca: env.tls.enabled && env.tls.caPath 
    ? fs.readFileSync(env.tls.caPath) 
    : undefined,
  rejectUnauthorized: process.env.NODE_ENV === 'production'  // ✅ Strict in prod
});

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
      checkServiceHealth('caService'),
      checkServiceHealth('ledgerService'),
    ]);

    const results = [
      { name: 'ca', status: serviceChecks[0].status === 'fulfilled' && serviceChecks[0].value ? 'up' : 'down' },
      { name: 'ledger', status: serviceChecks[0].status === 'fulfilled' && serviceChecks[0].value ? 'up' : 'down' },
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

  logger.info({ service: serviceName, url: healthUrl }, '🔍 Checking service health...');

  return new Promise((resolve) => {
    const timeout = setTimeout(() => {
      logger.warn({ service: serviceName }, 'Health check timeout');
      resolve(false);
    }, 5000);

    https.get(healthUrl, { agent: serviceAgent }, (res) => {  // ✅ serviceAgent
      clearTimeout(timeout);
      
      logger.info({ 
        service: serviceName, 
        status: res.statusCode 
      }, '✅ Service health response');
      
      resolve(res.statusCode === 200);
    }).on('error', (error) => {
      clearTimeout(timeout);
      
      logger.error({ 
        service: serviceName, 
        error: error.message 
      }, '❌ Service health check failed');
      
      resolve(false);
    });
  });
}

export default router;
