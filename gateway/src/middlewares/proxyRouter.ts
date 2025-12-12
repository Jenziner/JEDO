import { createProxyMiddleware, RequestHandler } from 'http-proxy-middleware';
import { Request } from 'express';
import { IncomingMessage, ServerResponse } from 'http';
import { serviceConfig, ServiceName } from '../config/services';
import { logger } from '../config/logger';
import { Socket } from 'net';


const createServiceProxy = (serviceName: ServiceName, _pathPrefix: string): RequestHandler => {
  const config = serviceConfig[serviceName];
  
  return createProxyMiddleware({
    target: config.url,
    changeOrigin: true,
    timeout: config.timeout,
    pathRewrite: serviceName === 'ledgerService'
      ? { '^/api/v1/ledger': '' }
      : serviceName === 'caService'
      ? { '^/api/v1/ca': '' }
      : undefined,
    on: {
      error: (err: Error, _req: IncomingMessage, res: ServerResponse | Socket) => {
        logger.error({ err, serviceName }, 'Proxy Error');
        
        if ('writeHead' in res && typeof res.writeHead === 'function') {
          if (!res.headersSent) {
            res.writeHead(502, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ 
              error: `${serviceName} unavailable`,
              message: 'Service temporarily unavailable'
            }));
          }
        }
      },
      
      proxyReq: (proxyReq, req: IncomingMessage) => {
        const expressReq = req as unknown as Request;
        const correlationId = (expressReq as any).id;
        
        if (correlationId) {
          proxyReq.setHeader('x-correlation-id', correlationId);
        }
        
        logger.debug({
          method: expressReq.method,
          path: expressReq.originalUrl,
          target: `${config.url}${proxyReq.path}`,
          serviceName
        }, 'Proxying request');
      },
      
      proxyRes: (proxyRes, req: IncomingMessage) => {
        const expressReq = req as unknown as Request;
        
        logger.debug({
          status: proxyRes.statusCode,
          path: expressReq.originalUrl,
          serviceName
        }, 'Received proxy response');
      }
    }
  });
};


export const caServiceProxy = createServiceProxy('caService', '/ca');
export const ledgerServiceProxy = createServiceProxy('ledgerService', '/ledger');
export const recoveryServiceProxy = createServiceProxy('recoveryService', '/recovery');
export const votingServiceProxy = createServiceProxy('votingService', '/voting');
