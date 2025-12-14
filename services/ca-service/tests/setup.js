// Mock Environment Variables für Tests
process.env.NODE_ENV = 'test';
process.env.PORT = '3001';
process.env.HOST = '0.0.0.0';
process.env.SERVICE_NAME = 'ca-service-test';
process.env.LOG_LEVEL = 'error';
process.env.CORS_ORIGIN = '*';
process.env.RATE_LIMIT_WINDOW_MS = '900000';
process.env.RATE_LIMIT_MAX_REQUESTS = '100';

// Fabric CA (Test Values)
process.env.FABRIC_CA_NAME = 'test-ca';
process.env.FABRIC_CA_URL = 'https://localhost:7054';
process.env.FABRIC_CA_ADMIN_USER = 'admin';
process.env.FABRIC_CA_ADMIN_PASS = 'adminpw';
process.env.FABRIC_MSP_ID = 'TestMSP';
process.env.FABRIC_CA_TLS_CERT_PATH = '/tmp/ca-cert.pem';
process.env.FABRIC_CA_TLS_VERIFY = 'false';
process.env.FABRIC_CA_IDEMIX_CURVE = 'gurvy.Bn254';
process.env.FABRIC_ORBIS_NAME = 'test';
process.env.FABRIC_REGNUM_NAME = 'test';
process.env.FABRIC_AGER_NAME = 'test';
process.env.CRYPTO_PATH = '/tmp';
