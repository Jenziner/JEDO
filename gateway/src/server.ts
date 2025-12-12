import { createApp } from './app';
import { env } from './config/environment';
import { validateFabricConfig } from './config/fabric';
import logger from './config/logger';
import { gracefulShutdown } from './utils/shutdown';
import { fabricProxyService } from './services/fabricProxyService';

const startServer = async (): Promise<void> => {
  try {
    // Validate Fabric Configuration
    validateFabricConfig();

    // Connect to Fabric Gateway (skip if Fabric not available)
    const skipFabric = process.env.SKIP_FABRIC_VALIDATION === 'true';
    
    if (!skipFabric) {
      await fabricProxyService.initialize();
      logger.info('✅ Fabric Gateway connected');
    } else {
      logger.warn('⚠️  Running in proxy-only mode (no Fabric connection). Legacy wallet/proxy routes will fail.');
    }

    // Start Express Server
    const app = createApp();

    const server = app.listen(env.port, env.host, () => {
      logger.info(
        {
          port: env.port,
          host: env.host,
          environment: env.nodeEnv,
          fabricEnabled: !skipFabric,
          fabricNetwork: skipFabric ? 'N/A' : env.fabric.networkName,
          fabricChannel: skipFabric ? 'N/A' : env.fabric.channelName,
          fabricChaincode: skipFabric ? 'N/A' : env.fabric.chaincodeName,
        },
        '�� JEDO Gateway Server started successfully'
      );
      logger.info(`📡 Health check: http://${env.host}:${env.port}/health`);
      logger.info(`�� Service proxies: http://${env.host}:${env.port}/api/v1/{ca|ledger|recovery|voting}`);
    });

    // Graceful Shutdown
    const shutdown = async (signal: string) => {
      if (!skipFabric) {
        await fabricProxyService.disconnect();
      }
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
      if (!skipFabric) {
        await fabricProxyService.disconnect();
      }
      process.exit(1);
    });
  } catch (error) {
    logger.error({ err: error }, 'Failed to start server');
    process.exit(1);
  }
};

void startServer();
