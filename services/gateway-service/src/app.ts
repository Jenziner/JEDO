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

  // ===== SECURITY MIDDLEWARE =====
  
  // Helmet mit angepasster CSP für CORS-Kompatibilität
  app.use(helmet({
    crossOriginResourcePolicy: { policy: "cross-origin" },
  }));

  // CORS Configuration mit Dynamic Origin Reflection
  app.use(
    cors({
      origin: (origin, callback) => {
        // Allow requests with no origin (mobile apps, curl, Postman)
        if (!origin) return callback(null, true);
        
        // Development: Erlaube alle Origins (reflektiere die Origin zurück)
        if (env.nodeEnv === 'development' || env.corsOrigin === '*') {
          return callback(null, origin);
        }
        
        // Production: Whitelist prüfen
        const allowedOrigins = env.corsOrigin.split(',').map(o => o.trim());
        if (allowedOrigins.includes(origin)) {
          return callback(null, origin);
        }
        
        // Origin nicht erlaubt
        callback(new Error('Not allowed by CORS'));
      },
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      credentials: true,
      maxAge: 86400,
      preflightContinue: false,
      optionsSuccessStatus: 204
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
