import express, { Application } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { env } from './config/environment';
import { requestLogger } from './middlewares/requestLogger';
import { errorHandler, notFoundHandler } from './middlewares/errorHandler';
import healthRoutes from './routes/healthRoutes';
import { extractClientIdentity } from './middlewares/fabricProxy';

// NEW: Service Proxies
import { 
  caServiceProxy, 
  ledgerServiceProxy, 
  recoveryServiceProxy, 
  votingServiceProxy 
} from './middlewares/proxyRouter';

// LEGACY Routes (TODO: Remove in Epic 4)
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

  // Global Rate Limiting
  const globalLimiter = rateLimit({
    windowMs: env.rateLimitWindowMs,
    max: env.rateLimitMaxRequests,
    message: 'Too many requests from this IP, please try again later',
    standardHeaders: true,
    legacyHeaders: false,
  });
  app.use(globalLimiter);

  // Body Parser
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Request Logging
  app.use(requestLogger);

  // ===== ROUTES (ORDER MATTERS!) =====

  // NEW: Service Proxies (to backend microservices)
  app.use('/api/v1/ca', caServiceProxy);
  app.use('/api/v1/ledger', ledgerServiceProxy);
  app.use('/api/v1/recovery', recoveryServiceProxy);
  app.use('/api/v1/voting', votingServiceProxy);

  // Health Routes (less specific, after API routes)
  app.use(healthRoutes);

  // Error Handlers (MUST be last!)
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};
