const express = require('express');
const healthController = require('../controllers/health.controller');

const router = express.Router();

/**
 * GET /health
 * Basic health check
 */
router.get('/health', healthController.healthCheck.bind(healthController));

/**
 * GET /health/ready
 * Readiness probe
 */
router.get('/health/ready', healthController.readinessCheck.bind(healthController));

/**
 * GET /health/live
 * Liveness probe
 */
router.get('/health/live', healthController.livenessCheck.bind(healthController));

module.exports = router;
