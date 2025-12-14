const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const env = require('./config/environment');
const { logger } = require('./config/logger');
const { requestLogger } = require('./middleware/request-logger.middleware');
const { errorHandler, notFoundHandler } = require('./middleware/error.middleware');

// Routes
const certificateRoutes = require('./routes/certificate.routes');
const healthRoutes = require('./routes/health.routes');
const caRoutes = require('./routes/ca.routes');
const openapiRoutes = require('./routes/openapi.routes');

/**
 * Create Express Application
 */
const createApp = () => {
  const app = express();

  // ===== SECURITY MIDDLEWARE =====
  app.use(helmet());
  
  app.use(cors({
    origin: env.corsOrigin,
    credentials: true,
  }));

  // ===== RATE LIMITING =====
  const limiter = rateLimit({
    windowMs: env.rateLimitWindowMs,
    max: env.rateLimitMaxRequests,
    message: {
      success: false,
      error: 'Too many requests from this IP, please try again later',
    },
    standardHeaders: true,
    legacyHeaders: false,
  });
  app.use(limiter);

  // ===== BODY PARSER =====
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // ===== REQUEST LOGGING =====
  app.use(requestLogger);

  // ===== ROUTES =====
  app.use('/health', healthRoutes);
  app.use('/certificates', certificateRoutes);
  app.use('/ca', caRoutes);
  
  // ===== OPENAPI SPEC =====
  app.get('/openapi.json', (req, res) => {
    try {
      const openapi = require('../docs/openapi.json');
      res.json(openapi);
    } catch (error) {
      logger.error('Failed to load OpenAPI spec', { error: error.message });
      res.status(500).json({
        success: false,
        error: 'OpenAPI specification not available'
      });
    }
  });

  app.get('/openapi', (req, res) => {
    res.redirect('/openapi.json');
  });

  // ===== API DOCUMENTATION (Swagger UI) =====
  if (env.nodeEnv !== 'production') {
    try {
      const swaggerUi = require('swagger-ui-express');
      const swaggerDocument = require('../docs/openapi.json');
      
      app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument, {
        customSiteTitle: "JEDO CA Service API",
        customCss: '.swagger-ui .topbar { display: none }'
      }));
      
      logger.info('Swagger UI enabled at /api-docs');
    } catch (error) {
      logger.warn('Swagger UI not available', { error: error.message });
    }
  }

  // ===== ERROR HANDLERS (MUST BE LAST!) =====
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};

/**
 * Create Server (HTTP or HTTPS with mTLS)
 */
const createServer = () => {
  const app = createApp();
  
  // Check if TLS is enabled
  if (!env.tls.enabled) {
    logger.warn('TLS is disabled - using HTTP only (not recommended for production)');
    return http.createServer(app);
  }
  
  // Check if TLS files exist
  if (!fs.existsSync(env.tls.keyPath)) {
    logger.error('TLS key not found', { path: env.tls.keyPath });
    throw new Error(`TLS key not found: ${env.tls.keyPath}`);
  }
  
  if (!fs.existsSync(env.tls.certPath)) {
    logger.error('TLS certificate not found', { path: env.tls.certPath });
    throw new Error(`TLS certificate not found: ${env.tls.certPath}`);
  }
  
  if (!fs.existsSync(env.tls.caPath)) {
    logger.error('TLS CA certificate not found', { path: env.tls.caPath });
    throw new Error(`TLS CA certificate not found: ${env.tls.caPath}`);
  }
  
  // Load TLS certificates
  const tlsOptions = {
    key: fs.readFileSync(env.tls.keyPath),
    cert: fs.readFileSync(env.tls.certPath),
    ca: fs.readFileSync(env.tls.caPath),
    
    // Enable client certificate authentication (mTLS)
    requestCert: env.security.requireClientCert,
    rejectUnauthorized: false, // We handle validation in middleware
  };
  
  logger.info('Creating HTTPS server with mTLS', {
    certPath: env.tls.certPath,
    keyPath: env.tls.keyPath,
    caPath: env.tls.caPath
  });
  
  return https.createServer(tlsOptions, app);
};

module.exports = { createApp, createServer };
