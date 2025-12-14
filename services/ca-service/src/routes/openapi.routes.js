const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');

/**
 * GET /openapi.json
 * Serve OpenAPI specification
 */
router.get('/openapi.json', (req, res) => {
  try {
    const openapiPath = path.join(__dirname, '..', '..', 'docs', 'swagger.json');
    const openapi = JSON.parse(fs.readFileSync(openapiPath, 'utf8'));
    res.json(openapi);
  } catch (error) {
    res.status(404).json({
      success: false,
      error: 'OpenAPI specification not found'
    });
  }
});

module.exports = router;
