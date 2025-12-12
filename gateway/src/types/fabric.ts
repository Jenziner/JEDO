export interface FabricProxyRequest {
  certificate: string;
  privateKey: string;
}

export interface TransactionProposal {
  channelName: string;
  chaincodeName: string;
  functionName: string;
  args: string[];
}

export interface WalletIdentity {
  label: string;
  mspId: string;
  certificate: string;
  privateKey: string;
}

export interface ChaincodeResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  transactionId?: string;
}
