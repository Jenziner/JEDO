import { Request, Response } from 'express';

import logger from '../config/logger';
import { chaincodeService } from '../services/chaincodeService';
import { AppError } from '../middlewares/errorHandler';
import {
  CreateWalletRequest,
  CreateWalletResponse,
  TransferRequest,
  TransferResponse,
  BalanceResponse,
  WalletResponse,
  WalletHistoryResponse,
} from '../types/wallet';

export class WalletController {
  async createWallet(req: Request, res: Response<CreateWalletResponse>): Promise<void> {
    try {
      const { walletId, ownerId, initialBalance = 0, metadata } = req.body as CreateWalletRequest;

      logger.info({ walletId, ownerId }, 'Creating new wallet');

      // Check if wallet already exists
      const exists = await chaincodeService.walletExists(walletId);
      if (exists) {
        throw new AppError(`Wallet ${walletId} already exists`, 409);
      }

      // Create wallet on blockchain
      const result = await chaincodeService.createWallet(
        walletId,
        ownerId,
        initialBalance,
        metadata
      );

      if (!result.success) {
        throw new AppError(result.error || 'Failed to create wallet', 500);
      }

      res.status(201).json({
        success: true,
        data: {
          walletId,
          ownerId,
          balance: initialBalance,
          transactionId: result.transactionId || 'N/A',
          timestamp: new Date().toISOString(),
        },
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      logger.error({ err: error }, 'Error creating wallet');
      throw new AppError('Failed to create wallet', 500);
    }
  }

  async transfer(req: Request, res: Response<TransferResponse>): Promise<void> {
    try {
      const { fromWalletId, toWalletId, amount, description } = req.body as TransferRequest;

      logger.info({ fromWalletId, toWalletId, amount }, 'Processing transfer');

      // Check if wallets exist
      const fromExists = await chaincodeService.walletExists(fromWalletId);
      const toExists = await chaincodeService.walletExists(toWalletId);

      if (!fromExists) {
        throw new AppError(`Source wallet ${fromWalletId} does not exist`, 404);
      }

      if (!toExists) {
        throw new AppError(`Destination wallet ${toWalletId} does not exist`, 404);
      }

      // Execute transfer
      const result = await chaincodeService.transfer(
        fromWalletId,
        toWalletId,
        amount,
        description
      );

      if (!result.success) {
        throw new AppError(result.error || 'Transfer failed', 500);
      }

      // Get updated balances
      const fromBalanceResult = await chaincodeService.getBalance(fromWalletId);
      const toBalanceResult = await chaincodeService.getBalance(toWalletId);

      res.status(200).json({
        success: true,
        data: {
          transactionId: result.transactionId || 'N/A',
          fromWalletId,
          toWalletId,
          amount,
          fromBalance: fromBalanceResult.data as number,
          toBalance: toBalanceResult.data as number,
          timestamp: new Date().toISOString(),
        },
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      logger.error({ err: error }, 'Error processing transfer');
      throw new AppError('Failed to process transfer', 500);
    }
  }

  async getBalance(req: Request, res: Response<BalanceResponse>): Promise<void> {
    try {
      const { walletId } = req.params;

      if (!walletId) {
        throw new AppError('walletId parameter is required', 400);
      }

      logger.info({ walletId }, 'Getting wallet balance');

      const exists = await chaincodeService.walletExists(walletId);
      if (!exists) {
        throw new AppError(`Wallet ${walletId} does not exist`, 404);
      }

      const result = await chaincodeService.getBalance(walletId);

      if (!result.success) {
        throw new AppError(result.error || 'Failed to get balance', 500);
      }

      res.status(200).json({
        success: true,
        data: {
          walletId,
          balance: result.data as number,
          currency: 'JEDO',
          timestamp: new Date().toISOString(),
        },
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      logger.error({ err: error }, 'Error getting balance');
      throw new AppError('Failed to get balance', 500);
    }
  }

  async getWallet(req: Request, res: Response<WalletResponse>): Promise<void> {
    try {
      const { walletId } = req.params;

      if (!walletId) {
        throw new AppError('walletId parameter is required', 400);
      }

      logger.info({ walletId }, 'Getting wallet details');

      const exists = await chaincodeService.walletExists(walletId);
      if (!exists) {
        throw new AppError(`Wallet ${walletId} does not exist`, 404);
      }

      const result = await chaincodeService.getWallet(walletId);

      if (!result.success) {
        throw new AppError(result.error || 'Failed to get wallet', 500);
      }

      res.status(200).json({
        success: true,
        data: result.data as WalletResponse['data'],
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      logger.error({ err: error }, 'Error getting wallet');
      throw new AppError('Failed to get wallet', 500);
    }
  }

  async getWalletHistory(req: Request, res: Response<WalletHistoryResponse>): Promise<void> {
    try {
      const { walletId } = req.params;

      if (!walletId) {
        throw new AppError('walletId parameter is required', 400);
      }

      const limitQuery = req.query.limit as string | undefined;
      const limit = limitQuery ? parseInt(limitQuery, 10) : 10;

      logger.info({ walletId, limit }, 'Getting wallet history');

      const exists = await chaincodeService.walletExists(walletId);
      if (!exists) {
        throw new AppError(`Wallet ${walletId} does not exist`, 404);
      }

      const result = await chaincodeService.getWalletHistory(walletId, limit);

      if (!result.success) {
        throw new AppError(result.error || 'Failed to get wallet history', 500);
      }

      res.status(200).json({
        success: true,
        data: result.data as WalletHistoryResponse['data'],
      });
    } catch (error) {
      if (error instanceof AppError) {
        throw error;
      }
      logger.error({ err: error }, 'Error getting wallet history');
      throw new AppError('Failed to get wallet history', 500);
    }
  }
}

export const walletController = new WalletController();
