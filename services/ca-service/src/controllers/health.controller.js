const certificateService = require('../services/certificate.service');
const { logger } = require('../config/logger');

class HealthController {
  
  /**
   * GET /health
   * Basic health check
   */
  async healthCheck(req, res) {
    res.status(200).json({
      status: 'healthy',
      service: 'ca-service',
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * GET /health/ready
   * Readiness probe (checks CA connectivity)
   */
  async readinessCheck(req, res) {
    try {
      // Check if certificate service is initialized
      const caConnected = !!certificateService.caClient;
      const registrarLoaded = !!certificateService.adminIdentity;
      
      let caReachable = false;
      let caInfo = null;
      
      // Test CA connection
      if (caConnected) {
        try {
          caInfo = await certificateService.caClient.getCaInfo();
          caReachable = true;
        } catch (err) {
          logger.warn('CA not reachable', { error: err.message });
        }
      }
      
      const healthy = caConnected && registrarLoaded && caReachable;
      
      const caHealth = {
        healthy,
        connected: caConnected,
        registrarLoaded,
        reachable: caReachable,
        caName: caInfo?.CAName || null
      };

      if (healthy) {
        res.status(200).json({
          status: 'ready',
          service: 'ca-service',
          ca: caHealth,
          timestamp: new Date().toISOString(),
        });
      } else {
        res.status(503).json({
          status: 'not ready',
          service: 'ca-service',
          ca: caHealth,
          timestamp: new Date().toISOString(),
        });
      }

    } catch (error) {
      logger.error('Readiness check failed', { error: error.message });
      res.status(503).json({
        status: 'not ready',
        service: 'ca-service',
        error: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  }

  /**
   * GET /health/live
   * Liveness probe
   */
  async livenessCheck(req, res) {
    res.status(200).json({
      status: 'alive',
      service: 'ca-service',
      timestamp: new Date().toISOString(),
    });
  }
}

module.exports = new HealthController();
