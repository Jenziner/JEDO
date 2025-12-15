const { logger } = require('../config/logger');
const { parsePemCertificate, isCertificateValid } = require('../utils/certificate.helper');

/**
 * Authentication Middleware
 * Supports: Certificate in Body (for Mobile/Web)
 */
function requireAuthentication(req, res, next) {
  try {
    // STRATEGY 1: Certificate in Body (Mobile/Web App)
    const { certificate, privateKey } = req.body;
    
    if (certificate) {
      // Parse certificate
      const cert = parsePemCertificate(certificate, privateKey);
      
      // Validate expiry
      if (!isCertificateValid(cert)) {
        return res.status(401).json({
          success: false,
          error: 'Certificate expired',
          message: `Certificate expired on ${cert.validTo}`
        });
      }
      
      // Validate role exists
      if (!cert.role) {
        return res.status(403).json({
          success: false,
          error: 'Invalid certificate',
          message: 'Could not determine role from certificate'
        });
      }
      
      // Attach to request
      req.clientCert = cert;
      
      logger.info('Authenticated via certificate in body', { 
        cn: cert.subject.CN, 
        role: cert.role 
      });
      
      // Remove sensitive data from body (avoid logging)
      delete req.body.certificate;
      delete req.body.privateKey;
      
      return next();
    }
    
    // STRATEGY 2: Dev Mode (bypass for testing)
    if (process.env.NODE_ENV === 'dev' && !certificate) {
      logger.warn('Dev mode: Bypassing authentication');
      req.clientCert = {
        role: 'admin',
        subject: { CN: 'dev-admin', O: 'admin' }
      };
      return next();
    }
    
    // No authentication provided
    return res.status(401).json({
      success: false,
      error: 'Authentication required',
      message: 'Provide certificate in request body'
    });
    
  } catch (error) {
    logger.error('Authentication failed', { error: error.message });
    return res.status(401).json({
      success: false,
      error: 'Authentication failed',
      message: error.message
    });
  }
}

/**
 * Role-based Authorization Middleware
 */
function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.clientCert) {
      return res.status(401).json({
        success: false,
        error: 'No authentication found'
      });
    }
    
    const userRole = req.clientCert.role;
    
    if (!userRole) {
      return res.status(403).json({
        success: false,
        error: 'Role not found in certificate'
      });
    }
    
    // Check if user role is allowed
    if (!allowedRoles.includes(userRole)) {
      logger.warn('Authorization failed', {
        required: allowedRoles,
        actual: userRole,
        cn: req.clientCert.subject.CN
      });
      
      return res.status(403).json({
        success: false,
        error: 'Insufficient permissions',
        message: `Required role: ${allowedRoles.join(' or ')}, your role: ${userRole}`
      });
    }
    
    logger.debug('Authorization successful', {
      cn: req.clientCert.subject.CN,
      role: userRole
    });
    
    next();
  };
}

module.exports = {
  requireAuthentication,
  requireRole,
};
