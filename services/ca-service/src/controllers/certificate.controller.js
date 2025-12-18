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
  /**
   * Register Gens identity
   * POST /certificates/register/gens
   */
  async registerGens(req, res, next) {
    try {
      const { username, secret, affiliation, role = 'gens' } = req.body;
      
      // Validation
      if (!username || !secret || !affiliation) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: username, secret, affiliation'
        });
      }
      
      logger.info('Gens registration request', { 
        username, 
        affiliation,
        requestedBy: req.user?.subject || 'unknown'
      });
      
      const result = await certificateService.registerGens({
        username,
        secret,
        affiliation,
        role
      });
      
      res.status(200).json({
        success: true,
        message: 'Gens registered successfully',
        data: {
          username: result.username,
          affiliation
        }
      });
      
    } catch (error) {
      logger.error('Gens registration failed', { 
        error: error.message,
        stack: error.stack 
      });
      next(error);
    }
  }

  /**
   * Register Human identity
   * POST /certificates/register/human
   */
  async registerHuman(req, res, next) {
    try {
      const { 
        username, 
        secret, 
        affiliation, 
        gensUsername, 
        gensPassword,
        role = 'human' 
      } = req.body;
      
      // Validation
      if (!username || !secret || !affiliation || !gensUsername || !gensPassword) {
        return res.status(400).json({
          success: false,
          error: 'Missing required fields: username, secret, affiliation, gensUsername, gensPassword'
        });
      }
      
      logger.info('Human registration request', { 
        username, 
        affiliation,
        registrar: gensUsername,
        requestedBy: req.user?.subject || 'unknown'
      });
      
      const result = await certificateService.registerHuman({
        username,
        secret,
        affiliation,
        gensUsername,
        gensPassword,
        role
      });
      
      res.status(200).json({
        success: true,
        message: 'Human registered successfully',
        data: {
          username: result.username,
          affiliation
        }
      });
      
    } catch (error) {
      logger.error('Human registration failed', { 
        error: error.message,
        stack: error.stack 
      });
      next(error);
    }
  }

  /**
   * Enroll user and issue certificate
   * POST /certificates/enroll
   */
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
