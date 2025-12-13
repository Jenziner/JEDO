const certificateService = require('../services/certificate.service');
const { logger } = require('../config/logger');

class CertificateController {
  
  /**
   * POST /certificates/register
   * Register a new user (Gens or Human)
   */
  async register(req, res, next) {
    try {
      const { username, secret, role, affiliation, attrs } = req.body;
      
      // Extract requester certificate from mTLS (if enabled)
      const requesterCert = req.client?.certificate || null;

      const result = await certificateService.registerUser(
        { username, secret, role, affiliation, attrs },
        requesterCert
      );

      logger.info({ username, role }, 'User registered via API');

      res.status(201).json({
        success: true,
        data: result,
      });

    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /certificates/enroll
   * Enroll a user (obtain certificate)
   */
  async enroll(req, res, next) {
    try {
      const { username, secret, role, csrOptions } = req.body;

      const result = await certificateService.enrollUser({
        username,
        secret,
        role,
        csrOptions,
      });

      logger.info({ username, role }, 'User enrolled via API');

      res.status(200).json({
        success: true,
        data: result,
      });

    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /certificates/reenroll
   * Re-enroll an existing user
   */
  async reenroll(req, res, next) {
    try {
      const { username } = req.body;

      const result = await certificateService.reenrollUser(username);

      logger.info({ username }, 'User re-enrolled via API');

      res.status(200).json({
        success: true,
        data: result,
      });

    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /certificates/revoke
   * Revoke a user certificate
   */
  async revoke(req, res, next) {
    try {
      const { username, reason } = req.body;
      
      const requesterCert = req.client?.certificate || null;

      const result = await certificateService.revokeUser(
        username,
        reason,
        requesterCert
      );

      logger.info({ username, reason }, 'User revoked via API');

      res.status(200).json({
        success: true,
        data: result,
      });

    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /certificates/:username
   * Get certificate information
   */
  async getCertificate(req, res, next) {
    try {
      const { username } = req.params;

      const result = await certificateService.getCertificateInfo(username);

      res.status(200).json({
        success: true,
        data: result,
      });

    } catch (error) {
      next(error);
    }
  }
}

module.exports = new CertificateController();
