const { logger } = require('../config/logger');

/**
 * Validate Registration Request
 */
function validateRegistration(req, res, next) {
  const { username, secret, role, affiliation } = req.body;
  
  // Required fields
  if (!username || !secret || !role || !affiliation) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      message: 'Required fields: username, secret, role, affiliation'
    });
  }
  
  // Validate username format
  if (username.length < 3 || username.length > 255) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      message: 'Username must be between 3 and 255 characters'
    });
  }
  
  // Validate secret strength
  if (secret.length < 8) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      message: 'Secret must be at least 8 characters'
    });
  }
  
  // Validate role
  const validRoles = ['gens', 'human'];
  if (!validRoles.includes(role)) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      message: `Role must be one of: ${validRoles.join(', ')}`
    });
  }
  
  // Validate affiliation format
  if (!affiliation.match(/^[a-z0-9.]+$/)) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      message: 'Affiliation must contain only lowercase letters, numbers and dots'
    });
  }
  
  logger.debug('Registration validation passed', { username, role });
  next();
}

/**
 * Validate Enrollment Request
 */
function validateEnrollment(req, res, next) {
  const { username, secret } = req.body;
  
  // Required fields
  if (!username || !secret) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      message: 'Required fields: username, secret'
    });
  }
  
  // Validate username
  if (username.length < 3 || username.length > 255) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      message: 'Username must be between 3 and 255 characters'
    });
  }
  
  // Validate secret
  if (secret.length < 8) {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      message: 'Secret must be at least 8 characters'
    });
  }
  
  logger.debug('Enrollment validation passed', { username });
  next();
}

module.exports = {
  validateRegistration,
  validateEnrollment
};
