import { createApp } from './app';
import { env } from './config/environment';
import logger from './config/logger';
import { gracefulShutdown } from './utils/shutdown';

const startServer = async (): Promise<void> => {
  try {
    // Start Express Server
    const app = createApp();

    const server = app.listen(env.port, env.host, () => {
      logger.info(
        {
          port: env.port,
          host: env.host,
          environment: env.nodeEnv,
        },
        '�� JEDO Gateway Server started successfully'
      );
      logger.info(`📡 Health check: http://${env.host}:${env.port}/health`);
      logger.info(`�� Service proxies: http://${env.host}:${env.port}/api/v1/{ca|ledger|recovery|voting}`);
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
