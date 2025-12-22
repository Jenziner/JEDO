// Mock Environment Variables für Tests
process.env.NODE_ENV = 'test';
process.env.PORT = '3001';
process.env.HOST = '0.0.0.0';
process.env.SERVICE_NAME = 'gateway-service-test';
process.env.LOG_LEVEL = 'error';
process.env.CORS_ORIGIN = '*';
process.env.RATE_LIMIT_WINDOW_MS = '900000';
process.env.RATE_LIMIT_MAX_REQUESTS = '100';

// Fabric (Test Values)
process.env.FABRIC_MSP_ID = 'TestMSP';
process.env.CA_SERVICE_URL = '';
process.env.LEDGER_SERVICE_URL = '';
process.env.TLS_ENABLED = 'true';
process.env.TLS_CERT_PATH = '/tmp/cert.pem';
process.env.TLS_KEY_PATH = '/tmp/key.pem';
process.env.TLS_CA_PATH = '/tmp/ca-cert.pem';
 