const { logger } = require('../config/logger');

/**
 * Global Error Handler
 */
const errorHandler = (err, req, res, next) => {
  logger.error({
    err,
    method: req.method,
    path: req.path,
    body: req.body,
  }, 'Request error');

  // Default error response
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  res.status(statusCode).json({
    success: false,
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
};

/**
 * 404 Not Found Handler
 */
const notFoundHandler = (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found',
    path: req.path,
  });
};

module.exports = {
  errorHandler,
  notFoundHandler,
};
