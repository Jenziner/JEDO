import { Contract, Network, Gateway as FabricGateway } from '@hyperledger/fabric-gateway';

export interface FabricConfig {
  mspId: string;
  channelName: string;
  chaincodeName: string;
  peerEndpoint: string;
  peerHostAlias: string;
  tlsCertPath: string;
  tlsRootCertPath: string;
  identityName: string;
  identityCertPath: string;
  identityKeyPath: string;
  walletPath: string;
}

export interface FabricIdentity {
  credentials: {
    certificate: string;
    privateKey: string;
  };
  mspId: string;
  type: 'X.509';
}

export interface WalletIdentity {
  label: string;
  mspId: string;
  certificate: string;
  privateKey: string;
}

export interface GatewayConnection {
  gateway: FabricGateway;
  network: Network;
  contract: Contract;
}

export interface ChaincodeResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  transactionId?: string;
}
