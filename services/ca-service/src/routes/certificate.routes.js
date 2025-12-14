const express = require('express');
const router = express.Router();
const certificateController = require('../controllers/certificate.controller');
const { requireAuthentication, requireRole } = require('../middleware/auth.middleware');
const { validateRegistration, validateEnrollment } = require('../middleware/validation.middleware');


/**
 * POST /certificates/register
 * Register new user
 * 
 * Auth: Certificate in Body
 * Authorization: ager → gens, gens → human
 */
router.post('/register',
  requireAuthentication,
  requireRole('ager', 'gens', 'admin'),
  validateRegistration,
  certificateController.registerCertificate
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
