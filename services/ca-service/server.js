const { createApp } = require('./src/app');
const fabricCAService = require('./src/services/fabric-ca.service');
const env = require('./src/config/environment');
const { logger } = require('./src/config/logger');

/**
 * Start CA Service
 */
async function startServer() {
  try {
    logger.info('Starting CA Service...');

    // Initialize Fabric CA Client
    logger.info('Initializing Fabric CA Client...');
    await fabricCAService.initialize();

    // Create Express App
    const app = createApp();

    // Start HTTP Server
    const server = app.listen(env.port, env.host, () => {
      logger.info({
        port: env.port,
        host: env.host,
        nodeEnv: env.nodeEnv,
        serviceName: env.serviceName,
        caUrl: env.fabricCa.caUrl,
        caName: env.fabricCa.caName,
        mspId: env.fabricCa.mspId,
      }, '✅ CA Service started successfully');
    });

    // Graceful Shutdown Handler
    const shutdown = async (signal) => {
      logger.info({ signal }, 'Received shutdown signal, closing server...');
      
      server.close(() => {
        logger.info('HTTP server closed');
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
