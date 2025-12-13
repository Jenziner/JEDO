const FabricCAServices = require('fabric-ca-client');
const { Wallets } = require('fabric-network');
const fs = require('fs');
const path = require('path');
const env = require('../config/environment');
const { logger } = require('../config/logger');

class FabricCAService {
  constructor() {
    this.caClient = null;
    this.wallet = null;
    this.adminIdentity = null;
  }

  /**
   * Initialize Fabric CA Client
   */
  async initialize() {
    try {
      logger.info('Initializing Fabric CA Client...');

      // Load TLS Certificate
      const tlsCertPath = path.resolve(env.fabricCa.tlsCertPath);
      if (!fs.existsSync(tlsCertPath)) {
        throw new Error(`TLS Certificate not found: ${tlsCertPath}`);
      }
      const tlsCert = fs.readFileSync(tlsCertPath).toString();

      // Create CA Client
      this.caClient = new FabricCAServices(
        env.fabricCa.caUrl,
        {
          trustedRoots: [tlsCert],
          verify: env.fabricCa.tlsVerify,
        },
        env.fabricCa.caName
      );

      // Initialize In-Memory Wallet
      this.wallet = await Wallets.newInMemoryWallet();

      // Enroll Admin
      await this.enrollAdmin();

      logger.info({
        caUrl: env.fabricCa.caUrl,
        caName: env.fabricCa.caName,
        mspId: env.fabricCa.mspId,
      }, 'Fabric CA Client initialized successfully');

    } catch (error) {
      logger.error({ err: error }, 'Failed to initialize Fabric CA Client');
      throw error;
    }
  }

  /**
   * Enroll CA Admin
   */
  async enrollAdmin() {
    try {
      // Check if admin already enrolled
      const adminExists = await this.wallet.get(env.fabricCa.caAdminUser);
      if (adminExists) {
        logger.debug('Admin identity already exists in wallet');
        this.adminIdentity = adminExists;
        return;
      }

      logger.info('Enrolling CA Admin...');

      // Enroll Admin
      const enrollment = await this.caClient.enroll({
        enrollmentID: env.fabricCa.caAdminUser,
        enrollmentSecret: env.fabricCa.caAdminPass,
      });

      // Create Admin Identity
      const identity = {
        credentials: {
          certificate: enrollment.certificate,
          privateKey: enrollment.key.toBytes(),
        },
        mspId: env.fabricCa.mspId,
        type: 'X.509',
      };

      // Store in Wallet
      await this.wallet.put(env.fabricCa.caAdminUser, identity);
      this.adminIdentity = identity;

      logger.info('Admin enrolled successfully');

    } catch (error) {
      logger.error({ err: error }, 'Admin enrollment failed');
      throw error;
    }
  }

  /**
   * Get CA Client instance
   */
  getCAClient() {
    if (!this.caClient) {
      throw new Error('CA Client not initialized. Call initialize() first.');
    }
    return this.caClient;
  }

  /**
   * Get Wallet instance
   */
  getWallet() {
    if (!this.wallet) {
      throw new Error('Wallet not initialized. Call initialize() first.');
    }
    return this.wallet;
  }

  /**
   * Get Admin Identity
   */
  async getAdminIdentity() {
    if (!this.adminIdentity) {
      // Try to load from wallet
      this.adminIdentity = await this.wallet.get(env.fabricCa.caAdminUser);
      if (!this.adminIdentity) {
        throw new Error('Admin identity not found. Please enroll admin first.');
      }
    }
    return this.adminIdentity;
  }

  /**
   * Health Check
   */
  async healthCheck() {
    try {
      if (!this.caClient) {
        return { healthy: false, error: 'CA Client not initialized' };
      }

      // Simple check: Try to get CA Info
      const caInfo = await this.caClient.getCaInfo();
      
      return {
        healthy: true,
        caName: caInfo.CAName,
        version: caInfo.Version,
      };
    } catch (error) {
      logger.error({ err: error }, 'CA Health Check failed');
      return {
        healthy: false,
        error: error.message,
      };
    }
  }
}

// Singleton Instance
module.exports = new FabricCAService();
