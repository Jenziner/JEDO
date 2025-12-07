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

    // Connect to Fabric Gateway
    await fabricProxyService.initialize();

    // Start Express Server
    const app = createApp();

    const server = app.listen(env.port, env.host, () => {
      logger.info(
        {
          port: env.port,
          host: env.host,
          environment: env.nodeEnv,
          fabricNetwork: env.fabric.networkName,
          fabricChannel: env.fabric.channelName,
          fabricChaincode: env.fabric.chaincodeName,
        },
        '🚀 JEDO Gateway Server started successfully'
      );
      logger.info(`📡 Health check available at http://${env.host}:${env.port}/health`);
    });

    // Graceful Shutdown
    process.on('SIGTERM', async () => {
      await fabricProxyService.disconnect();
      gracefulShutdown(server, 'SIGTERM');
    });

    process.on('SIGINT', async () => {
      await fabricProxyService.disconnect();
      gracefulShutdown(server, 'SIGINT');
    });

    // Unhandled Rejections
    process.on('unhandledRejection', (reason: Error) => {
      logger.error({ err: reason }, 'Unhandled Rejection');
      throw reason;
    });

    // Uncaught Exceptions
    process.on('uncaughtException', async (error: Error) => {
      logger.error({ err: error }, 'Uncaught Exception');
      await fabricProxyService.disconnect();
      process.exit(1);
    });
  } catch (error) {
    logger.error({ err: error }, 'Failed to start server');
    process.exit(1);
  }
};

void startServer();
