import * as grpc from '@grpc/grpc-js';
import * as crypto from 'crypto';
import { connect, Gateway, Identity, Signer, signers } from '@hyperledger/fabric-gateway';

import logger from '../config/logger';
import { fabricConfig, readCertificate } from '../config/fabric';
import { walletService } from './walletService';
import { GatewayConnection } from '../types/fabric';

export class GatewayService {
  private gateway: Gateway | null = null;
  private grpcClient: grpc.Client | null = null;

  async connect(): Promise<GatewayConnection> {
    try {
      logger.info('Connecting to Fabric Gateway...');

      // Load identity from wallet or create new
      let identity = await walletService.get(fabricConfig.identityName);

      if (!identity) {
        logger.info('Identity not found in wallet, importing...');
        await walletService.importIdentity(
          fabricConfig.identityName,
          fabricConfig.mspId,
          fabricConfig.identityCertPath,
          fabricConfig.identityKeyPath
        );
        identity = await walletService.get(fabricConfig.identityName);

        if (!identity) {
          throw new Error('Failed to import identity');
        }
      }

      // Create gRPC client
      const tlsRootCert = readCertificate(fabricConfig.tlsRootCertPath);
      const grpcCredentials = grpc.credentials.createSsl(tlsRootCert);

      this.grpcClient = new grpc.Client(fabricConfig.peerEndpoint, grpcCredentials, {
        'grpc.ssl_target_name_override': fabricConfig.peerHostAlias,
      });

      // Create Gateway identity and signer
      const gatewayIdentity: Identity = {
        mspId: fabricConfig.mspId,
        credentials: Buffer.from(identity.certificate),
      };

      // Convert private key PEM to crypto.KeyObject
      const privateKeyPem = identity.privateKey;
      const privateKey = crypto.createPrivateKey(privateKeyPem);
      const gatewaySigner: Signer = signers.newPrivateKeySigner(privateKey);

      // Connect to Gateway
      this.gateway = connect({
        client: this.grpcClient,
        identity: gatewayIdentity,
        signer: gatewaySigner,
        evaluateOptions: () => ({ deadline: Date.now() + 5000 }), // 5 second timeout
        endorseOptions: () => ({ deadline: Date.now() + 15000 }), // 15 second timeout
        submitOptions: () => ({ deadline: Date.now() + 30000 }), // 30 second timeout
        commitStatusOptions: () => ({ deadline: Date.now() + 60000 }), // 60 second timeout
      });

      // Get network and contract
      const network = this.gateway.getNetwork(fabricConfig.channelName);
      const contract = network.getContract(fabricConfig.chaincodeName);

      logger.info(
        {
          mspId: fabricConfig.mspId,
          channel: fabricConfig.channelName,
          chaincode: fabricConfig.chaincodeName,
          peer: fabricConfig.peerEndpoint,
          identity: fabricConfig.identityName,
        },
        '✅ Successfully connected to Fabric Gateway'
      );

      return {
        gateway: this.gateway,
        network,
        contract,
      };
    } catch (error) {
      logger.error({ err: error }, 'Failed to connect to Fabric Gateway');
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    try {
      if (this.gateway) {
        this.gateway.close();
        this.gateway = null;
        logger.info('Gateway connection closed');
      }

      if (this.grpcClient) {
        this.grpcClient.close();
        this.grpcClient = null;
        logger.info('gRPC client closed');
      }
    } catch (error) {
      logger.error({ err: error }, 'Error closing Gateway connection');
      throw error;
    }
  }

  isConnected(): boolean {
    return this.gateway !== null;
  }

  getGateway(): Gateway {
    if (!this.gateway) {
      throw new Error('Gateway not connected. Call connect() first.');
    }
    return this.gateway;
  }
}

export const gatewayService = new GatewayService();
