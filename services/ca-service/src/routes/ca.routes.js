const express = require('express');
const router = express.Router();
const env = require('../config/environment');
const { logger } = require('../config/logger');

/**
 * GET /ca/info
 * Get CA information (static)
 */
router.get('/info', (req, res) => {
  logger.info('Fetching CA info');
  
  res.json({
    success: true,
    data: {
      caName: env.fabricCa.caName,
      caUrl: env.fabricCa.caUrl,
      mspId: env.fabricCa.mspId,
      tlsEnabled: env.fabricCa.tlsVerify,
      status: 'connected',
      hierarchy: {
        orbis: env.fabricCa.orbisName,
        regnum: env.fabricCa.regnumName,
        ager: env.fabricCa.agerName
      }
    }
  });
});

module.exports = router;
