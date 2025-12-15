import http from 'http';
import https from 'https';
import fs from 'fs';
import type { Application } from 'express'; // ✅ Import Type
import { createApp } from './app';
import { env } from './config/environment';
import logger from './config/logger';
import { gracefulShutdown } from './utils/shutdown';

/**
 * Create HTTP or HTTPS Server based on TLS configuration
 */
function createServer(app: Application): http.Server | https.Server {
  // TLS disabled → HTTP
  if (!env.tls.enabled) {
    logger.warn('TLS is disabled - creating HTTP server');
    return http.createServer(app);
  }

  // TLS enabled → HTTPS
  try {
    logger.info('Loading TLS certificates...');
    
    const tlsOptions: https.ServerOptions = {
      cert: fs.readFileSync(env.tls.certPath),
      key: fs.readFileSync(env.tls.keyPath),
      ca: fs.readFileSync(env.tls.caPath),
      requestCert: env.requireClientCert,
      rejectUnauthorized: false,
    };

    logger.info({
      certPath: env.tls.certPath,
      keyPath: env.tls.keyPath,
      caPath: env.tls.caPath,
      requireClientCert: env.requireClientCert
    }, '✅ TLS certificates loaded successfully');

    return https.createServer(tlsOptions, app);

  } catch (error) {
    logger.error({ err: error }, '❌ Failed to load TLS certificates');
    throw error;
  }
}

const startServer = async (): Promise<void> => {
  try {
    // Create Express App
    const app = createApp();

    // Create Server (HTTP or HTTPS)
    const server = createServer(app);

    // Start Server
    server.listen(env.port, env.host, () => {
      const protocol = env.tls.enabled ? 'https' : 'http';
      
      logger.info({
        protocol,
        port: env.port,
        host: env.host,
        url: `${protocol}://${env.serviceName}:${env.port}`,
        nodeEnv: env.nodeEnv,
        serviceName: env.serviceName,
        tlsEnabled: env.tls.enabled
      }, `✅ Gateway Service started successfully on ${protocol.toUpperCase()}`);
      
      logger.info(`📡 Health check: ${protocol}://${env.host}:${env.port}/health`);
      logger.info(`🔄 Service proxies: ${protocol}://${env.host}:${env.port}/api/v1/{ca|ledger|recovery|voting}`);
    });

    // Graceful Shutdown
    const shutdown = async (signal: string) => {
      gracefulShutdown(server, signal);
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));

    // Unhandled Rejections
    process.on('unhandledRejection', (reason: Error) => {
      logger.error({ err: reason }, 'Unhandled Rejection');
      throw reason;
    });

    // Uncaught Exceptions
    process.on('uncaughtException', async (error: Error) => {
      logger.error({ err: error }, 'Uncaught Exception');
      process.exit(1);
    });
  } catch (error) {
    logger.error({ err: error }, 'Failed to start server');
    process.exit(1);
  }
};

void startServer();
