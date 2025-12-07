import express, { Application } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';

import { env } from './config/environment';
import { requestLogger } from './middlewares/requestLogger';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler';
import healthRoutes from './routes/healthRoutes';
import walletRoutes from './routes/walletRoutes';
import proxyRoutes from './routes/proxyRoutes';

export const createApp = (): Application => {
  const app: Application = express();

  // Security Middleware
  app.use(helmet());
  app.use(
    cors({
      origin: env.corsOrigin,
      credentials: true,
    })
  );

  // Rate Limiting
  const limiter = rateLimit({
    windowMs: env.rateLimitWindowMs,
    max: env.rateLimitMaxRequests,
    message: 'Too many requests from this IP, please try again later',
    standardHeaders: true,
    legacyHeaders: false,
  });
  app.use(limiter);

  // Body Parser
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Request Logging
  app.use(requestLogger);

  // Routes
  app.use('/', healthRoutes);
  app.use('/api/v1/wallets', walletRoutes);
  app.use('/api/v1/proxy', proxyRoutes);

  // Error Handlers
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};
