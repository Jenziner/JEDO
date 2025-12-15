import express, { Application } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { env } from './config/environment';
import { requestLogger } from './middlewares/requestLogger';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler';
import { globalRateLimiter } from './middlewares/rateLimiter';
import healthRoutes from './routes/healthRoutes';
import caProxyRoutes from './routes/caProxyRoutes';
import ledgerProxyRoutes from './routes/ledgerProxyRoutes';

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

  // Global Rate Limiting
  app.use(globalRateLimiter);

  // Body Parser
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Request Logging
  app.use(requestLogger);

  // ===== ROUTES (ORDER MATTERS!) =====
  // Service Proxies (to backend microservices)
  app.use('/api/v1/ca', caProxyRoutes);
  app.use('/api/v1/ledger', ledgerProxyRoutes);
//  app.use('/api/v1/recovery', recoveryProxyRoutes);
//  app.use('/api/v1/voting', votingProxyRoutes);

  // Health Routes (less specific, after API routes)
  app.use(healthRoutes);

  // Error Handlers (MUST be last!)
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};
