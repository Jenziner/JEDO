const fabricCAService = require('../services/fabric-ca.service');
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
      const caHealth = await fabricCAService.healthCheck();

      if (caHealth.healthy) {
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
      logger.error({ err: error }, 'Readiness check failed');
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
