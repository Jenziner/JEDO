import dotenv from 'dotenv';

// Load .env.local for development
if (process.env.NODE_ENV !== 'production') {
  dotenv.config({ path: '.env.local' });
}

/**
 * Get environment variable or throw error
 */
function getEnv(key: string, defaultValue?: string): string {
  const value = process.env[key] || defaultValue;
  if (value === undefined) {
    throw new Error(`Environment variable ${key} is required but not set`);
  }
  return value;
}

/**
 * Get optional environment variable
 */
function getEnvOptional(key: string, defaultValue?: string): string | undefined {
  return process.env[key] || defaultValue;
}

/**
 * Centralized environment configuration
 */
export const env = {
  // Service Config
  nodeEnv: getEnv('NODE_ENV', 'development'),
  port: parseInt(getEnv('PORT', '3002')),
  host: getEnv('HOST', '0.0.0.0'),
  serviceName: getEnv('SERVICE_NAME', 'ledger-service'),

  // Logging
  logLevel: getEnv('LOG_LEVEL', 'info'),
  logPretty: getEnv('LOG_PRETTY', 'true') === 'true',

  // Security
  requireClientCert: getEnv('REQUIRE_CLIENT_CERT', 'false') === 'true',
  corsOrigin: getEnv('CORS_ORIGIN', 'http://localhost:3000'),
  maxRequestSize: getEnv('MAX_REQUEST_SIZE', '10mb'),

  // Rate Limiting
  rateLimitWindowMs: parseInt(getEnv('RATE_LIMIT_WINDOW_MS', '60000')),
  rateLimitMaxRequests: parseInt(getEnv('RATE_LIMIT_MAX_REQUESTS', '100')),

  // Hyperledger Fabric
  fabric: {
    networkName: getEnv('FABRIC_NETWORK_NAME', 'jedo-network'),
    channelName: getEnv('FABRIC_CHANNEL_NAME'),
    chaincodeName: getEnv('FABRIC_CHAINCODE_NAME'),
    mspId: getEnv('FABRIC_MSP_ID'),
    peerEndpoint: getEnv('FABRIC_PEER_ENDPOINT'),
    peerHostAlias: getEnv('FABRIC_PEER_HOST_ALIAS'),
    peerTlsCert: getEnv('FABRIC_PEER_TLS_CERT'),
    peerTlsRootCert: getEnv('FABRIC_PEER_TLS_ROOT_CERT'),
    gatewayCert: getEnvOptional('FABRIC_GATEWAY_CERT'),
    gatewayKey: getEnvOptional('FABRIC_GATEWAY_KEY'),
    skipValidation: getEnv('SKIP_FABRIC_VALIDATION', 'false') === 'true',
  },
};

// Validate Fabric config on startup (unless skipped)
if (!env.fabric.skipValidation) {
  const requiredFabricVars = [
    'FABRIC_CHANNEL_NAME',
    'FABRIC_CHAINCODE_NAME',
    'FABRIC_MSP_ID',
    'FABRIC_PEER_ENDPOINT',
    'FABRIC_PEER_HOST_ALIAS',
    'FABRIC_PEER_TLS_CERT',
    'FABRIC_PEER_TLS_ROOT_CERT',
  ];

  const missingVars = requiredFabricVars.filter(
    (varName) => !process.env[varName]
  );

  if (missingVars.length > 0) {
    throw new Error(
      `Missing required Fabric environment variables: ${missingVars.join(', ')}`
    );
  }
}
