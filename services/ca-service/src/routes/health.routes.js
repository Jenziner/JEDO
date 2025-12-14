const express = require('express');
const healthController = require('../controllers/health.controller');

const router = express.Router();

/**
 * GET /health
 * Basic health check
 */
router.get('/', healthController.healthCheck.bind(healthController));  // ← GEÄNDERT!

/**
 * GET /health/ready
 * Readiness probe
 */
router.get('/ready', healthController.readinessCheck.bind(healthController));

/**
 * GET /health/live
 * Liveness probe
 */
router.get('/live', healthController.livenessCheck.bind(healthController));

module.exports = router;
