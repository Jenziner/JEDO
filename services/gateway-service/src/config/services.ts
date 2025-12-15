import dotenv from 'dotenv';
dotenv.config();

export const serviceConfig = {
  caService: {
    url: process.env.CA_SERVICE_URL || 'http://localhost:3001',
    timeout: parseInt(process.env.SERVICE_TIMEOUT || '10000', 10),
    healthPath: '/health'
  },
  ledgerService: {
    url: process.env.LEDGER_SERVICE_URL || 'http://localhost:3002',
    timeout: parseInt(process.env.SERVICE_TIMEOUT || '10000', 10),
    healthPath: '/health'
  },
  recoveryService: {
    url: process.env.RECOVERY_SERVICE_URL || 'http://localhost:3003',
    timeout: parseInt(process.env.SERVICE_TIMEOUT || '10000', 10),
    healthPath: '/health'
  },
  votingService: {
    url: process.env.VOTING_SERVICE_URL || 'http://localhost:3004',
    timeout: parseInt(process.env.SERVICE_TIMEOUT || '10000', 10),
    healthPath: '/health'
  }
};

export type ServiceName = keyof typeof serviceConfig;
