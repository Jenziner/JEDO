import { fabricProxyService } from './services/fabricProxyService';

import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });

import express from 'express';
import helmet from 'helmet';
import cors from 'cors';

import logger from './config/logger';
import { requestLogger } from './middlewares/requestLogger';
import { errorHandler } from './middlewares/errorHandler';

// Routes
import walletRoutes from './routes/walletRoutes';
import proxyRoutes from './routes/proxyRoutes';

const PORT = parseInt(process.env.PORT || '3002', 10);
const HOST = process.env.HOST || '0.0.0.0';

const createApp = () => {
  const app = express();

  // Security Middleware
  app.use(helmet());
  app.use(cors({
    origin: process.env.CORS_ORIGIN || 'http://localhost:3000',
    credentials: true,
  }));

  // Body Parser
  app.use(express.json({ limit: process.env.MAX_REQUEST_SIZE || '10mb' }));

  // Request Logging
  app.use(requestLogger);

  // Health Endpoint
  app.get('/health', (req, res) => {
    res.json({
      service: 'ledger-service',
      status: 'OK',
      timestamp: new Date().toISOString(),
      fabric: {
        network: process.env.FABRIC_NETWORK_NAME,
        channel: process.env.FABRIC_CHANNEL_NAME,
        chaincode: process.env.FABRIC_CHAINCODE_NAME,
      },
    });
  });

  // API Routes
  app.use('/api/v1/wallets', walletRoutes);
  app.use('/api/v1/proxy', proxyRoutes);

  // Error Handler (muss als letztes kommen)
  app.use(errorHandler);

  return app;
};

const start = async () => {
  try {
    // WICHTIG: Fabric-Proxy initialisieren
    await fabricProxyService.initialize();

    const app = createApp();

    app.listen(PORT, HOST, () => {
      logger.info(
        {
          port: PORT,
          host: HOST,
          environment: process.env.NODE_ENV,
          fabricNetwork: process.env.FABRIC_NETWORK_NAME,
          fabricChannel: process.env.FABRIC_CHANNEL_NAME,
          fabricChaincode: process.env.FABRIC_CHAINCODE_NAME,
        },
        '🚀 Ledger Service started',
      );
    });
  } catch (err) {
    logger.error({ err }, 'Failed to start ledger-service');
    process.exit(1);
  }
};

start();
