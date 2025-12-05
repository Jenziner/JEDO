export interface CreateWalletRequest {
  walletId: string;
  ownerId: string;
  initialBalance?: number;
  metadata?: Record<string, string>;
}

export interface CreateWalletResponse {
  success: boolean;
  data: {
    walletId: string;
    ownerId: string;
    balance: number;
    transactionId: string;
    timestamp: string;
  };
}

export interface TransferRequest {
  fromWalletId: string;
  toWalletId: string;
  amount: number;
  description?: string;
}

export interface TransferResponse {
  success: boolean;
  data: {
    transactionId: string;
    fromWalletId: string;
    toWalletId: string;
    amount: number;
    fromBalance: number;
    toBalance: number;
    timestamp: string;
  };
}

export interface BalanceResponse {
  success: boolean;
  data: {
    walletId: string;
    balance: number;
    currency: string;
    timestamp: string;
  };
}

export interface WalletResponse {
  success: boolean;
  data: {
    walletId: string;
    ownerId: string;
    balance: number;
    currency: string;
    status: string;
    createdAt: string;
    updatedAt: string;
    metadata?: Record<string, string>;
  };
}

export interface WalletHistory {
  transactionId: string;
  type: 'credit' | 'debit';
  amount: number;
  balance: number;
  counterparty?: string;
  description?: string;
  timestamp: string;
}

export interface WalletHistoryResponse {
  success: boolean;
  data: {
    walletId: string;
    transactions: WalletHistory[];
    count: number;
  };
}
