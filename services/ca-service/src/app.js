const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const env = require('./config/environment');
const { requestLogger } = require('./middleware/request-logger.middleware');
const { errorHandler, notFoundHandler } = require('./middleware/error.middleware');

// Routes
const certificateRoutes = require('./routes/certificate.routes');
const healthRoutes = require('./routes/health.routes');

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
  app.use('/certificates', certificateRoutes);
  app.use(healthRoutes);

  // ===== ERROR HANDLERS (MUST BE LAST!) =====
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};

module.exports = { createApp };
