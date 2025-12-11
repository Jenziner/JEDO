import { createProxyMiddleware, RequestHandler } from 'http-proxy-middleware';
import { Request, Response } from 'express';
import { serviceConfig, ServiceName } from '../config/services';
import { logger } from '../config/logger';

const createServiceProxy = (serviceName: ServiceName, _pathPrefix: string): RequestHandler => {
  const config = serviceConfig[serviceName];
  
  return createProxyMiddleware({
    target: config.url,
    changeOrigin: true,
    timeout: config.timeout,
    
    on: {
      error: (err: Error, _req: Request, res: Response) => {
        logger.error(`${serviceName} Proxy Error`, { error: err.message });
        if (!res.headersSent) {
          res.status(502).json({ 
            error: `${serviceName} unavailable`,
            message: 'Service temporarily unavailable'
          });
        }
      },
      
      proxyReq: (proxyReq, req: Request) => {
        const correlationId = (req as any).id;
        if (correlationId) {
          proxyReq.setHeader('x-correlation-id', correlationId);
        }
        logger.debug(`Proxying to ${serviceName}`, {
          method: req.method,
          path: req.originalUrl,
          target: `${config.url}${proxyReq.path}`
        });
      },
      
      proxyRes: (proxyRes, req: Request) => {
        logger.debug(`Response from ${serviceName}`, {
          status: proxyRes.statusCode,
          path: req.originalUrl
        });
      }
    }
  });
};

export const caServiceProxy = createServiceProxy('caService', '/ca');
export const ledgerServiceProxy = createServiceProxy('ledgerService', '/ledger');
export const recoveryServiceProxy = createServiceProxy('recoveryService', '/recovery');
export const votingServiceProxy = createServiceProxy('votingService', '/voting');
