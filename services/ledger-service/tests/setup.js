// Mock Environment Variables für Tests
process.env.NODE_ENV = 'test';
process.env.PORT = '3002';
process.env.HOST = '0.0.0.0';
process.env.SERVICE_NAME = 'ledger-service-test';
process.env.LOG_LEVEL = 'error';
process.env.CORS_ORIGIN = '*';
process.env.RATE_LIMIT_WINDOW_MS = '900000';
process.env.RATE_LIMIT_MAX_REQUESTS = '100';

// Fabric CA (Test Values)
process.env.FABRIC_NETWORK_NAME = 'jedo';
process.env.FABRIC_CHANNEL_NAME = 'test';
process.env.FABRIC_CHAINCODE_NAME = 'jedo-wallet';
process.env.FABRIC_MSP_ID = 'TestMSP';
process.env.FABRIC_GATEWAY_CERT = '/tmp/cert.pem';
process.env.FABRIC_GATEWAY_KEY = '/tmp/key.pem';
