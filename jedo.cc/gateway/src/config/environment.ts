import dotenv from 'dotenv';

dotenv.config();

interface FabricIdentityConfig {
  name: string;
  certPath: string;
  keyPath: string;
}

interface Environment {
  nodeEnv: string;
  port: number;
  host: string;
  logLevel: string;
  logPretty: boolean;
  rateLimitWindowMs: number;
  rateLimitMaxRequests: number;
  corsOrigin: string;
  fabric: {
    networkName: string;
    channelName: string;
    chaincodeName: string;
    mspId: string;
    peerEndpoint: string;
    peerHostAlias: string;
    tlsCertPath: string;
    tlsRootCertPath: string;
    issuer: FabricIdentityConfig;
    owner: FabricIdentityConfig;
  };
  walletPath: string;
}

const getEnv = (key: string, defaultValue?: string): string => {
  const value = process.env[key];
  if (!value && defaultValue === undefined) {
    throw new Error(`Environment variable ${key} is required but not set`);
  }
  return value || defaultValue || '';
};

const getEnvNumber = (key: string, defaultValue: number): number => {
  const value = process.env[key];
  return value ? parseInt(value, 10) : defaultValue;
};

const getEnvBoolean = (key: string, defaultValue: boolean): boolean => {
  const value = process.env[key];
  if (!value) return defaultValue;
  return value.toLowerCase() === 'true';
};

export const env: Environment = {
  nodeEnv: getEnv('NODE_ENV', 'development'),
  port: getEnvNumber('PORT', 3000),
  host: getEnv('HOST', '0.0.0.0'),
  logLevel: getEnv('LOG_LEVEL', 'info'),
  logPretty: getEnvBoolean('LOG_PRETTY', true),
  rateLimitWindowMs: getEnvNumber('RATE_LIMIT_WINDOW_MS', 900000),
  rateLimitMaxRequests: getEnvNumber('RATE_LIMIT_MAX_REQUESTS', 100),
  corsOrigin: getEnv('CORS_ORIGIN', '*'),
  fabric: {
    networkName: getEnv('FABRIC_NETWORK_NAME', 'jedo'),
    channelName: getEnv('FABRIC_CHANNEL_NAME', 'ea'),
    chaincodeName: getEnv('FABRIC_CHAINCODE_NAME', 'jedo-wallet'),
    mspId: getEnv('FABRIC_MSP_ID', 'alps'),
    peerEndpoint: getEnv('FABRIC_PEER_ENDPOINT', 'peer.alps.ea.jedo.cc:53511'),
    peerHostAlias: getEnv('FABRIC_PEER_HOST_ALIAS', 'peer.alps.ea.jedo.cc'),
    tlsCertPath: getEnv(
      'FABRIC_TLS_CERT_PATH',
      './infrastructure/jedo/ea/alps/peer.alps.ea.jedo.cc/tls/signcerts/cert.pem'
    ),
    tlsRootCertPath: getEnv(
      'FABRIC_TLS_ROOT_CERT_PATH',
      './infrastructure/jedo/ea/alps/peer.alps.ea.jedo.cc/tls/tlscacerts/tls-ca-cert.pem'
    ),
    issuer: {
      name: getEnv('FABRIC_IDENTITY_NAME', 'iss.alps.ea.jedo.cc'),
      certPath: getEnv(
        'FABRIC_IDENTITY_CERT_PATH',
        './infrastructure/jedo/ea/alps/iss.alps.ea.jedo.cc/msp/signcerts/cert.pem'
      ),
      keyPath: getEnv(
        'FABRIC_IDENTITY_KEY_PATH',
        './infrastructure/jedo/ea/alps/iss.alps.ea.jedo.cc/msp/keystore/*_sk'
      ),
    },
    owner: {
      name: getEnv('FABRIC_OWNER_NAME', 'worb.alps.ea.jedo.cc'),
      certPath: getEnv(
        'FABRIC_OWNER_CERT_PATH',
        './infrastructure/jedo/ea/alps/worb.alps.ea.jedo.cc/msp/signcerts/cert.pem'
      ),
      keyPath: getEnv(
        'FABRIC_OWNER_KEY_PATH',
        './infrastructure/jedo/ea/alps/worb.alps.ea.jedo.cc/msp/keystore/*_sk'
      ),
    },
  },
  walletPath: getEnv('WALLET_PATH', './wallet'),
};

export const isProduction = (): boolean => env.nodeEnv === 'production';
export const isDevelopment = (): boolean => env.nodeEnv === 'development';
