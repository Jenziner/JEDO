const dotenv = require('dotenv');
const path = require('path');

// Load .env file
dotenv.config({ path: path.resolve(process.cwd(), '.env') });

/**
 * Get required environment variable
 */
const getEnv = (key) => {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Environment variable ${key} is required but not set`);
  }
  return value;
};

/**
 * Get environment variable with default
 */
const getEnvWithDefault = (key, defaultValue) => {
  return process.env[key] || defaultValue;
};

/**
 * Get number from environment variable
 */
const getEnvNumber = (key, defaultValue) => {
  const value = process.env[key];
  if (!value && defaultValue !== undefined) return defaultValue;
  const parsed = parseInt(value, 10);
  if (isNaN(parsed)) {
    throw new Error(`Environment variable ${key} must be a number, got: ${value}`);
  }
  return parsed;
};

/**
 * Get boolean from environment variable
 */
const getEnvBoolean = (key, defaultValue) => {
  const value = process.env[key];
  if (!value && defaultValue !== undefined) return defaultValue;
  const lower = value.toLowerCase();
  if (lower !== 'true' && lower !== 'false') {
    throw new Error(`Environment variable ${key} must be 'true' or 'false', got: ${value}`);
  }
  return lower === 'true';
};

module.exports = {
  // Server Configuration
  nodeEnv: getEnvWithDefault('NODE_ENV', 'development'),
  port: getEnvNumber('PORT', 3001),
  host: getEnvWithDefault('HOST', '0.0.0.0'),
  serviceName: getEnvWithDefault('SERVICE_NAME', 'ca-service'),

  // Logging
  logLevel: getEnvWithDefault('LOG_LEVEL', 'info'),
  logPretty: getEnvBoolean('LOG_PRETTY', true),

  // Security
  requireClientCert: getEnvBoolean('REQUIRE_CLIENT_CERT', false),
  rateLimitWindowMs: getEnvNumber('RATE_LIMIT_WINDOW_MS', 900000), // 15 min
  rateLimitMaxRequests: getEnvNumber('RATE_LIMIT_MAX_REQUESTS', 100),

  // CORS
  corsOrigin: getEnvWithDefault('CORS_ORIGIN', '*'),

  // Hyperledger Fabric CA
  fabricCa: {
    // Ager CA Configuration
    caName: getEnv('FABRIC_CA_NAME'),
    caUrl: getEnv('FABRIC_CA_URL'),
    caAdminUser: getEnv('FABRIC_CA_ADMIN_USER'),
    caAdminPass: getEnv('FABRIC_CA_ADMIN_PASS'),
    mspId: getEnv('FABRIC_MSP_ID'),
    
    // TLS Configuration
    tlsCertPath: getEnv('FABRIC_CA_TLS_CERT_PATH'),
    tlsVerify: getEnvBoolean('FABRIC_CA_TLS_VERIFY', true),
    
    // Idemix Configuration
    idemixCurve: getEnvWithDefault('FABRIC_CA_IDEMIX_CURVE', 'gurvy.Bn254'),
    
    // Certificate Hierarchy
    orbisName: getEnv('FABRIC_ORBIS_NAME'),
    regnumName: getEnv('FABRIC_REGNUM_NAME'),
    agerName: getEnv('FABRIC_AGER_NAME'),
  },

  // Paths
  cryptoPath: getEnvWithDefault('CRYPTO_PATH', '/app/infrastructure'),
  
  // Helper functions
  isProduction: () => process.env.NODE_ENV === 'production',
  isDevelopment: () => process.env.NODE_ENV === 'development',
  isTest: () => process.env.NODE_ENV === 'test',
};
