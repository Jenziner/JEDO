import { Server } from 'http';

import logger from '../config/logger';

export const gracefulShutdown = (server: Server, signal: string): void => {
  logger.info(`${signal} signal received: closing HTTP server gracefully`);

  server.close((err) => {
    if (err) {
      logger.error({ err }, 'Error during server shutdown');
      process.exit(1);
    }

    logger.info('HTTP server closed successfully');

    // Hier später: Fabric Gateway-Verbindungen schließen
    // await gateway.close();

    process.exit(0);
  });

  // Force shutdown after 30 seconds
  setTimeout(() => {
    logger.error('Forcing shutdown after timeout');
    process.exit(1);
  }, 30000);
};
