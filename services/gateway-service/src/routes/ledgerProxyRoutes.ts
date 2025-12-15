import { Router, Request, Response } from 'express';
import http, { IncomingHttpHeaders } from 'http';
import { serviceConfig } from '../config/services';
import logger from '../config/logger';

const router = Router();

/**
 * Proxy all /api/v1/ledger/* requests to Ledger-Service
 */
router.all('*', async (req: Request, res: Response) => {
  const ledgerServiceUrl = serviceConfig.ledgerService.url;
  const targetPath = req.originalUrl.replace('/api/v1/ledger', '');
  const targetUrl = `${ledgerServiceUrl}${targetPath}`;

  logger.info({
    method: req.method,
    originalUrl: req.originalUrl,
    targetUrl,
    body: req.body
  }, '🔄 Proxying request to Ledger-Service');

  try {
    // Build request options
    const url = new URL(targetUrl);
    
    // Clone headers and remove hop-by-hop headers
    const headers = { ...req.headers } as IncomingHttpHeaders;
    delete headers['connection'];
    delete headers['keep-alive'];
    delete headers['transfer-encoding'];
    
    const options: http.RequestOptions = {
      hostname: url.hostname,
      port: url.port || 80,
      path: url.pathname + url.search,
      method: req.method,
      headers: {
        ...headers,
        host: url.hostname,  // Override host header
      },
    };

    // Make request to Ledger-Service (HTTP)
    const proxyReq = http.request(options, (proxyRes) => {
      // Forward status code
      res.status(proxyRes.statusCode || 500);

      // Forward headers
      Object.keys(proxyRes.headers).forEach(key => {
        const value = proxyRes.headers[key];
        if (value) {
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
          error: 'ledgerService unavailable',
          message: 'Service temporarily unavailable'
        });
      }
    });

    // Handle timeouts
    proxyReq.setTimeout(serviceConfig.ledgerService.timeout, () => {
      proxyReq.destroy();
      if (!res.headersSent) {
        res.status(504).json({
          error: 'ledgerService timeout',
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
