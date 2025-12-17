import { Router, Request, Response } from 'express';
import https from 'https';
import { IncomingHttpHeaders } from 'http';
import { serviceConfig } from '../config/services';
import logger from '../config/logger';

const router = Router();

// TLS Agent for CA-Service communication
const caAgent = new https.Agent({
  rejectUnauthorized: false  // Dev: accept self-signed certs
});

/**
 * CORS Preflight Handler - MUSS vor router.all() kommen!
 */
router.options('*', (req: Request, res: Response) => {
  logger.debug({
    path: req.path,
    origin: req.headers.origin
  }, 'CORS Preflight for CA-Service');
  
  res.sendStatus(204); // CORS-Header bereits von app.ts gesetzt
});

/**
 * Proxy all /api/v1/ca/* requests to CA-Service
 */
router.all('*', async (req: Request, res: Response) => {
  const caServiceUrl = serviceConfig.caService.url;
  const targetPath = req.originalUrl.replace('/api/v1/ca', '');
  const targetUrl = `${caServiceUrl}${targetPath}`;

  logger.info({
    method: req.method,
    originalUrl: req.originalUrl,
    targetUrl,
    body: req.body
  }, '🔄 Proxying request to CA-Service');

  try {
    // Build request options
    const url = new URL(targetUrl);
    
    // Clone headers and remove hop-by-hop headers
    const headers = { ...req.headers } as IncomingHttpHeaders;
    delete headers['connection'];
    delete headers['keep-alive'];
    delete headers['transfer-encoding'];
    
    const options: https.RequestOptions = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname + url.search,
      method: req.method,
      headers: {
        ...headers,
        host: url.hostname,  // Override host header
      },
      agent: caAgent,
    };

    // Make request to CA-Service
    const proxyReq = https.request(options, (proxyRes) => {
      // Forward status code
      res.status(proxyRes.statusCode || 500);

      // Forward headers
      Object.keys(proxyRes.headers).forEach(key => {
        const value = proxyRes.headers[key];
        const lowerKey = key.toLowerCase();
        if (value && !lowerKey.startsWith('access-control-')) {
          res.setHeader(key, value);
        }
      });

      // Stream response
      proxyRes.pipe(res);

      proxyRes.on('end', () => {
        logger.info({
          method: req.method,
          targetUrl,
          statusCode: proxyRes.statusCode
        }, '✅ Proxy request completed');
      });
    });

    // Handle proxy errors
    proxyReq.on('error', (error) => {
      logger.error({
        method: req.method,
        targetUrl,
        error: error.message
      }, '❌ Proxy request failed');

      if (!res.headersSent) {
        res.status(502).json({
          error: 'caService unavailable',
          message: 'Service temporarily unavailable'
        });
      }
    });

    // Handle timeouts
    proxyReq.setTimeout(serviceConfig.caService.timeout, () => {
      proxyReq.destroy();
      if (!res.headersSent) {
        res.status(504).json({
          error: 'caService timeout',
          message: 'Service request timeout'
        });
      }
    });

    // Forward request body (if exists)
    if (req.body && Object.keys(req.body).length > 0) {
      const bodyData = JSON.stringify(req.body);
      proxyReq.setHeader('Content-Length', Buffer.byteLength(bodyData));
      proxyReq.write(bodyData);
    }

    proxyReq.end();

  } catch (error: any) {
    logger.error({
      method: req.method,
      targetUrl,
      error: error.message
    }, '❌ Proxy setup failed');

    res.status(500).json({
      error: 'Internal proxy error',
      message: error.message
    });
  }
});

export default router;
