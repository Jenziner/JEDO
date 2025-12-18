const express = require('express');
const router = express.Router();
const certificateController = require('../controllers/certificate.controller');
const { requireAuthentication, requireRole } = require('../middleware/auth.middleware');
const { validateRegistration, validateEnrollment } = require('../middleware/validation.middleware');

/**
 * POST /certificates/register/gens
 * Register Gens identity with affiliation creation
 * 
 * Auth: Certificate in Body (Ager)
 * Authorization: ager, admin
 */
router.post('/register/gens',
  requireAuthentication,
  requireRole('ager', 'admin'),
  validateRegistration,
  certificateController.registerGens
);

/**
 * POST /certificates/register/human
 * Register Human identity under Gens affiliation
 * 
 * Auth: Certificate in Body (Gens)
 * Authorization: gens, admin
 */
router.post('/register/human',
  requireAuthentication,
  requireRole('gens', 'admin'),
  validateRegistration,
  certificateController.registerHuman
);

/**
 * POST /certificates/enroll
 * Enroll user and issue certificate
 * 
 * Auth: None (uses username + secret)
 */
router.post('/enroll',
  validateEnrollment,
  certificateController.enrollCertificate
);

module.exports = router;
