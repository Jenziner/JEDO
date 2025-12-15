require('dotenv').config({ path: '/app/.env' });

const http = require('http');
const https = require('https');
const fs = require('fs');
const { createApp } = require('./src/app');
const certificateService = require('./src/services/certificate.service');
const env = require('./src/config/environment');
const { logger } = require('./src/config/logger');

/**
 * Create HTTP or HTTPS Server based on TLS configuration
 */
function createServer(app) {
  // TLS disabled → HTTP
  if (!env.tls.enabled) {
    logger.warn('TLS is disabled - creating HTTP server');
    return http.createServer(app);
  }

  // TLS enabled → HTTPS
  try {
    logger.info('Loading TLS certificates...');
    
    const tlsOptions = {
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
      requireClientCert: env.security.requireClientCert
    }, '✅ TLS certificates loaded successfully');

    return https.createServer(tlsOptions, app);

  } catch (error) {
    logger.error({ err: error }, '❌ Failed to load TLS certificates');
    throw error;
  }
}

/**
 * Start CA Service
 */
async function startServer() {
  try {
    logger.info('Starting CA Service...');

    // Initialize certificate service
    await certificateService.initialize();
    logger.info('Certificate service initialized');

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
        caUrl: env.fabricCa.caUrl,
        caName: env.fabricCa.caName,
        mspId: env.fabricCa.mspId,
        tlsEnabled: env.tls.enabled
      }, `✅ CA Service started successfully on ${protocol.toUpperCase()}`);
    });

    // Graceful Shutdown Handler
    const shutdown = async (signal) => {
      logger.info({ signal }, 'Received shutdown signal, closing server...');
      
      server.close(() => {
        logger.info('Server closed');
        process.exit(0);
      });

      // Force shutdown after 10 seconds
      setTimeout(() => {
        logger.error('Forced shutdown after timeout');
        process.exit(1);
      }, 10000);
    };

    // Handle shutdown signals
    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));

    // Handle uncaught errors
    process.on('uncaughtException', (error) => {
      logger.error({ err: error }, 'Uncaught exception');
      process.exit(1);
    });

    process.on('unhandledRejection', (reason, promise) => {
      logger.error({ reason, promise }, 'Unhandled rejection');
      process.exit(1);
    });

  } catch (error) {
    logger.error({ err: error }, 'Failed to start CA Service');
    process.exit(1);
  }
}

// Start the server
startServer();
