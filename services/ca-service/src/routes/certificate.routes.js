const express = require('express');
const certificateController = require('../controllers/certificate.controller');
const { validate } = require('../middleware/validation.middleware');
const {
  registerUserSchema,
  enrollUserSchema,
  revokeUserSchema,
} = require('../validators/certificate.validator');

const router = express.Router();

/**
 * POST /certificates/register
 * Register a new user (Gens or Human)
 */
router.post(
  '/register',
  validate(registerUserSchema),
  certificateController.register.bind(certificateController)
);

/**
 * POST /certificates/enroll
 * Enroll a user (obtain certificate)
 */
router.post(
  '/enroll',
  validate(enrollUserSchema),
  certificateController.enroll.bind(certificateController)
);

/**
 * POST /certificates/reenroll
 * Re-enroll an existing user
 */
router.post(
  '/reenroll',
  certificateController.reenroll.bind(certificateController)
);

/**
 * POST /certificates/revoke
 * Revoke a user certificate
 */
router.post(
  '/revoke',
  validate(revokeUserSchema),
  certificateController.revoke.bind(certificateController)
);

/**
 * GET /certificates/:username
 * Get certificate information
 */
router.get(
  '/:username',
  certificateController.getCertificate.bind(certificateController)
);

module.exports = router;
