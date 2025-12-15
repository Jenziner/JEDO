// src/controllers/certificate.controller.js

const certificateService = require('../services/certificate.service');
const { logger } = require('../config/logger');

// Fixed attributes that are set automatically by Fabric CA
const FIXED_ATTRIBUTES = [
  'hf.EnrollmentID',
  'hf.Type', 
  'hf.Affiliation'
];

class CertificateController {
  async registerCertificate(req, res, next) {
    try {
      const { username, secret, role, affiliation, attrs = {} } = req.body;
      
      logger.debug('Registration validation passed');
      
      // Filter out fixed hf.* attributes (set automatically by Fabric CA)
      const cleanAttrs = Object.entries(attrs)
        .filter(([key]) => !FIXED_ATTRIBUTES.includes(key))
        .reduce((obj, [key, value]) => {
          obj[key] = value;
          return obj;
        }, {});
      
      logger.info('Registering with filtered attributes', {
        username,
        role,
        originalAttrs: Object.keys(attrs),
        filteredAttrs: Object.keys(cleanAttrs)
      });
      
      const result = await certificateService.registerUser(
        username,
        secret,
        role,
        affiliation,
        cleanAttrs
      );
      
      res.status(200).json({
        success: true,
        message: 'User registered successfully',
        data: result
      });
    } catch (error) {
      logger.error('Registration request failed', { 
        error: error.message 
      });
      next(error);
    }
  }

  async enrollCertificate(req, res, next) {
    try {
      const { 
        username, 
        secret, 
        enrollmentType = 'x509', 
        idemixCurve = 'gurvy.Bn254',
        role,
        gensName
      } = req.body;
      
      logger.info('Enrollment request', { username, enrollmentType, role, gensName });
      
      if (role === 'human' && !gensName) {
        logger.error('Human enrollment requires gensName parameter', { username });
        return res.status(400).json({
          success: false,
          error: 'Human enrollment requires "gensName" parameter'
        });
      }
        
      const enrollmentData = {
        username,
        secret,
        enrollmentType,
        idemixCurve,
        gensName,
        role
      };
      
      logger.info('Enrollment data prepared', { 
        username, 
        enrollmentType, 
        gensName, 
        role 
      });
      
      const result = await certificateService.enrollUser(enrollmentData);
      
      res.status(200).json({
        success: true,
        message: 'User enrolled successfully',
        data: result
      });
      
    } catch (error) {
      logger.error('Enrollment request failed', { 
        error: error.message,
        stack: error.stack 
      });
      next(error);
    }
  }

  async revokeCertificate(req, res, next) {
    try {
      // TODO: Implement certificate revocation
      res.status(501).json({
        success: false,
        message: 'Certificate revocation not implemented yet'
      });
    } catch (error) {
      next(error);
    }
  }

  async getCertificateInfo(req, res, next) {
    try {
      // TODO: Implement certificate info retrieval
      res.status(501).json({
        success: false,
        message: 'Certificate info retrieval not implemented yet'
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new CertificateController();
