import { Contract } from '@hyperledger/fabric-gateway';

import logger from '../config/logger';
import { gatewayService } from './gatewayService';
import { ChaincodeResponse } from '../types/fabric';

export class ChaincodeService {
  private getContract(): Contract {
    const gateway = gatewayService.getGateway();
    const network = gateway.getNetwork(process.env.FABRIC_CHANNEL_NAME || 'ea');
    return network.getContract(process.env.FABRIC_CHAINCODE_NAME || 'jedo-wallet');
  }

  async submitTransaction(
    functionName: string,
    ...args: string[]
  ): Promise<ChaincodeResponse<unknown>> {
    try {
      const contract = this.getContract();

      logger.info(
        {
          function: functionName,
          args: args,
        },
        'Submitting transaction to chaincode'
      );

      const result = await contract.submitTransaction(functionName, ...args);
      const resultString = Buffer.from(result).toString('utf8');

      logger.info(
        {
          function: functionName,
          result: resultString,
        },
        'Transaction submitted successfully'
      );

      return {
        success: true,
        data: resultString ? JSON.parse(resultString) : null,
      };
    } catch (error) {
      logger.error(
        {
          err: error,
          function: functionName,
          args: args,
        },
        'Failed to submit transaction'
      );

      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  async evaluateTransaction(
    functionName: string,
    ...args: string[]
  ): Promise<ChaincodeResponse<unknown>> {
    try {
      const contract = this.getContract();

      logger.info(
        {
          function: functionName,
          args: args,
        },
        'Evaluating transaction (query)'
      );

      const result = await contract.evaluateTransaction(functionName, ...args);
      const resultString = Buffer.from(result).toString('utf8');

      logger.debug(
        {
          function: functionName,
          result: resultString,
        },
        'Query evaluated successfully'
      );

      return {
        success: true,
        data: resultString ? JSON.parse(resultString) : null,
      };
    } catch (error) {
      logger.error(
        {
          err: error,
          function: functionName,
          args: args,
        },
        'Failed to evaluate transaction'
      );

      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  async createWallet(
    walletId: string,
    ownerId: string,
    initialBalance: number = 0,
    metadata?: Record<string, string>
  ): Promise<ChaincodeResponse<unknown>> {
    const args = [walletId, ownerId, initialBalance.toString()];

    if (metadata) {
      args.push(JSON.stringify(metadata));
    }

    return this.submitTransaction('CreateWallet', ...args);
  }

  async transfer(
    fromWalletId: string,
    toWalletId: string,
    amount: number,
    description?: string
  ): Promise<ChaincodeResponse<unknown>> {
    const args = [fromWalletId, toWalletId, amount.toString()];

    if (description) {
      args.push(description);
    }

    return this.submitTransaction('Transfer', ...args);
  }

  async getBalance(walletId: string): Promise<ChaincodeResponse<unknown>> {
    return this.evaluateTransaction('GetBalance', walletId);
  }

  async getWallet(walletId: string): Promise<ChaincodeResponse<unknown>> {
    return this.evaluateTransaction('GetWallet', walletId);
  }

  async getWalletHistory(
    walletId: string,
    limit: number = 10
  ): Promise<ChaincodeResponse<unknown>> {
    return this.evaluateTransaction('GetWalletHistory', walletId, limit.toString());
  }

  async walletExists(walletId: string): Promise<boolean> {
    const result = await this.evaluateTransaction('WalletExists', walletId);
    return result.success && result.data === true;
  }
}

export const chaincodeService = new ChaincodeService();
