const { logger } = require('../config/logger');

/**
 * Validate request body against Joi schema
 */
const validate = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.body, {
      abortEarly: false,
      stripUnknown: true,
    });

    if (error) {
      const errors = error.details.map(detail => ({
        field: detail.path.join('.'),
        message: detail.message,
      }));

      logger.warn({ errors }, 'Validation failed');

      return res.status(400).json({
        success: false,
        error: 'Validation error',
        details: errors,
      });
    }

    // Replace req.body with validated/sanitized value
    req.body = value;
    next();
  };
};

module.exports = { validate };
