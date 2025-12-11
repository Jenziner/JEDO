import dotenv from 'dotenv';
import path from 'path';

const nodeEnv = process.env.NODE_ENV || 'development';

// Load .env first (base configuration)
dotenv.config({ path: path.resolve(process.cwd(), '.env') });

// Load environment-specific .env file
dotenv.config({ path: path.resolve(process.cwd(), `.env.${nodeEnv}`) });

// Load local overrides with OVERRIDE flag (highest priority)
dotenv.config({ 
  path: path.resolve(process.cwd(), `.env.${nodeEnv}.local`),
  override: true 
});
dotenv.config({ 
  path: path.resolve(process.cwd(), '.env.local'),
  override: true 
});

interface Environment {
  nodeEnv: string;
  port: number;
  host: string;
  serviceName: string;
  logLevel: string;
  logPretty: boolean;
  requireClientCert: boolean;
  rateLimitWindowMs: number;
  rateLimitMaxRequests: number;
  maxRequestSize: string;
  corsOrigin: string;
  fabric: {
    networkName: string;
    channelName: string;
    chaincodeName: string;
    mspId: string;
    peerEndpoint: string;
    peerHostAlias: string;
    peerTlsCert: string;
    peerTlsRootCert: string;
  };
  caApi: {
    url: string;
  };
  audit: {
    logPath: string;
    logLevel: string;
  };
}

/**
 * Get environment variable - REQUIRED (no default!)
 */
const getEnv = (key: string): string => {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Environment variable ${key} is required but not set`);
  }
  return value;
};

/**
 * Get environment variable with optional default
 */
const getEnvWithDefault = (key: string, defaultValue: string): string => {
  return process.env[key] || defaultValue;
};

/**
 * Get number from environment variable
 */
const getEnvNumber = (key: string): number => {
  const value = getEnv(key);
  const parsed = parseInt(value, 10);
  if (isNaN(parsed)) {
    throw new Error(`Environment variable ${key} must be a number, got: ${value}`);
  }
  return parsed;
};

/**
 * Get boolean from environment variable
 */
const getEnvBoolean = (key: string): boolean => {
  const value = getEnv(key);
  const lower = value.toLowerCase();
  if (lower !== 'true' && lower !== 'false') {
    throw new Error(`Environment variable ${key} must be 'true' or 'false', got: ${value}`);
  }
  return lower === 'true';
};

export const env: Environment = {
  // Server Configuration
  nodeEnv: getEnv('NODE_ENV'),
  port: getEnvNumber('PORT'),
  host: getEnv('HOST'),
  serviceName: getEnv('SERVICE_NAME'),

  // Logging
  logLevel: getEnv('LOG_LEVEL'),
  logPretty: getEnvBoolean('LOG_PRETTY'),

  // Security
  requireClientCert: getEnvBoolean('REQUIRE_CLIENT_CERT'),
  rateLimitWindowMs: getEnvNumber('RATE_LIMIT_WINDOW_MS'),
  rateLimitMaxRequests: getEnvNumber('RATE_LIMIT_MAX_REQUESTS'),
  maxRequestSize: getEnv('MAX_REQUEST_SIZE'),

  // CORS
  corsOrigin: getEnv('CORS_ORIGIN'),

  // Hyperledger Fabric
  fabric: {
    networkName: getEnv('FABRIC_NETWORK_NAME'),
    channelName: getEnv('FABRIC_CHANNEL_NAME'),
    chaincodeName: getEnv('FABRIC_CHAINCODE_NAME'),
    mspId: getEnv('FABRIC_MSP_ID'),
    peerEndpoint: getEnv('FABRIC_PEER_ENDPOINT'),
    peerHostAlias: getEnv('FABRIC_PEER_HOST_ALIAS'),
    peerTlsCert: getEnv('FABRIC_PEER_TLS_CERT'),
    peerTlsRootCert: getEnv('FABRIC_PEER_TLS_ROOT_CERT'),
  },

  // CA-API
  caApi: {
    url: getEnv('CA_API_URL'),
  },

  // Audit Logging
  audit: {
    logPath: getEnvWithDefault('AUDIT_LOG_PATH', './logs/audit.log'),
    logLevel: getEnvWithDefault('AUDIT_LOG_LEVEL', 'info'),
  },
};

// Environment Checks
export const isProduction = (): boolean => env.nodeEnv === 'me';
export const isDevelopment = (): boolean => env.nodeEnv === 'dev';
export const isTest = (): boolean => env.nodeEnv === 'cc';
