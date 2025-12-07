import * as grpc from '@grpc/grpc-js';
import * as crypto from 'crypto';
import { connect, Identity, Signer, signers } from '@hyperledger/fabric-gateway';

import logger from '../config/logger';
import { fabricConfig, readCertificate } from '../config/fabric';

/**
 * Extract MSP ID from X.509 certificate
 * For JEDO certs with multiple OUs: OU=ea+OU=alps+OU=jedo+OU=client
 * We take the second OU which is the organization/MSP
 */
function extractMspIdFromCert(certPem: string): string {
  try {
    const cert = new crypto.X509Certificate(certPem);
    const subject = cert.subject;
    
    // Match O= field (Organization)
    const oMatch = subject.match(/O=([^,+\s]+)/);
    
    if (!oMatch || !oMatch[1]) {
      throw new Error(`Certificate must have O= field. Subject: ${subject}`);
    }
    
    const mspId = oMatch[1].trim();
    
    if (!mspId) {
      throw new Error('MSP ID extracted from certificate O= field is empty');
    }
    
    logger.debug({ mspId, subject }, 'Extracted MSP ID from certificate O= field');
    return mspId;
  } catch (error) {
    logger.error({ err: error }, 'Failed to extract MSP ID from certificate');
    throw error;
  }
}

export class FabricProxyService {
  private grpcClient: grpc.Client | null = null;

  async initialize(): Promise<void> {
    try {
      logger.info('Initializing Fabric Proxy (no gateway identity)...');

      // Only create gRPC client for peer connection
      const tlsRootCert = readCertificate(fabricConfig.tlsRootCertPath);
      const grpcCredentials = grpc.credentials.createSsl(tlsRootCert);

      this.grpcClient = new grpc.Client(fabricConfig.peerEndpoint, grpcCredentials, {
        'grpc.ssl_target_name_override': fabricConfig.peerHostAlias,
      });

      logger.info(
        {
          peer: fabricConfig.peerEndpoint,
          channel: fabricConfig.channelName,
          chaincode: fabricConfig.chaincodeName,
        },
        '✅ Fabric Proxy initialized (stateless mode)'
      );
    } catch (error) {
      logger.error({ err: error }, 'Failed to initialize Fabric Proxy');
      throw error;
    }
  }

  /**
   * Submit transaction with CLIENT identity (from request headers)
   */
  async submitWithClientIdentity(
    clientCertPem: string,
    clientPrivateKeyPem: string,
    channelName: string,
    chaincodeName: string,
    functionName: string,
    args: string[]
  ): Promise<Uint8Array> {
    if (!this.grpcClient) {
      throw new Error('Fabric Proxy not initialized');
    }

    try {
      // Extract MSP ID from client certificate
      const mspId = extractMspIdFromCert(clientCertPem);
      
      // Create identity from client certificate
      const identity: Identity = {
        mspId: mspId,
        credentials: Buffer.from(clientCertPem),
      };

      // Create signer from client's private key
      const privateKey = crypto.createPrivateKey(clientPrivateKeyPem);
      const signer: Signer = signers.newPrivateKeySigner(privateKey);

      // Create Gateway connection WITH CLIENT IDENTITY
      const gateway = connect({
        client: this.grpcClient,
        identity: identity,
        signer: signer,
        evaluateOptions: () => ({ deadline: Date.now() + 5000 }),
        endorseOptions: () => ({ deadline: Date.now() + 15000 }),
        submitOptions: () => ({ deadline: Date.now() + 30000 }),
        commitStatusOptions: () => ({ deadline: Date.now() + 60000 }),
      });

      try {
        const network = gateway.getNetwork(channelName);
        const contract = network.getContract(chaincodeName);

        // Submit transaction
        const result = await contract.submitTransaction(functionName, ...args);

        logger.info(
          {
            mspId,
            function: functionName,
            args: args,
            resultLength: result.length,
          },
          'Transaction submitted with client identity'
        );

        return result;
      } finally {
        gateway.close();
      }
    } catch (error) {
      logger.error({ err: error, function: functionName }, 'Failed to submit transaction');
      throw error;
    }
  }

  /**
   * Evaluate transaction (query) with CLIENT identity
   */
  async evaluateWithClientIdentity(
    clientCertPem: string,
    clientPrivateKeyPem: string,
    channelName: string,
    chaincodeName: string,
    functionName: string,
    args: string[]
  ): Promise<Uint8Array> {
    if (!this.grpcClient) {
      throw new Error('Fabric Proxy not initialized');
    }

    try {
      // Extract MSP ID from client certificate
      const mspId = extractMspIdFromCert(clientCertPem);
      
      const identity: Identity = {
        mspId: mspId,
        credentials: Buffer.from(clientCertPem),
      };

      const privateKey = crypto.createPrivateKey(clientPrivateKeyPem);
      const signer: Signer = signers.newPrivateKeySigner(privateKey);

      const gateway = connect({
        client: this.grpcClient,
        identity: identity,
        signer: signer,
        evaluateOptions: () => ({ deadline: Date.now() + 5000 }),
      });

      try {
        const network = gateway.getNetwork(channelName);
        const contract = network.getContract(chaincodeName);

        const result = await contract.evaluateTransaction(functionName, ...args);

        logger.info(
          {
            mspId,
            function: functionName,
            args: args,
            resultLength: result.length,
          },
          'Transaction evaluated with client identity'
        );

        return result;
      } finally {
        gateway.close();
      }
    } catch (error) {
      logger.error({ err: error, function: functionName }, 'Failed to evaluate transaction');
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    if (this.grpcClient) {
      this.grpcClient.close();
      this.grpcClient = null;
      logger.info('gRPC client closed');
    }
  }

  isReady(): boolean {
    return this.grpcClient !== null;
  }
}

export const fabricProxyService = new FabricProxyService();
