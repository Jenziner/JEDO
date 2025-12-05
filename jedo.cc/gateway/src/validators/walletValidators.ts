import { Request, Response, NextFunction } from 'express';

import { AppError } from '../middlewares/errorHandler';

export const validateCreateWallet = (req: Request, _res: Response, next: NextFunction): void => {
  const { walletId, ownerId, initialBalance } = req.body;

  if (!walletId || typeof walletId !== 'string') {
    throw new AppError('walletId is required and must be a string', 400);
  }

  if (!ownerId || typeof ownerId !== 'string') {
    throw new AppError('ownerId is required and must be a string', 400);
  }

  if (initialBalance !== undefined) {
    if (typeof initialBalance !== 'number' || initialBalance < 0) {
      throw new AppError('initialBalance must be a non-negative number', 400);
    }
  }

  // Validate walletId format (alphanumeric, dash, underscore)
  const walletIdRegex = /^[a-zA-Z0-9_-]+$/;
  if (!walletIdRegex.test(walletId)) {
    throw new AppError('walletId must contain only alphanumeric characters, dashes, or underscores', 400);
  }

  next();
};

export const validateTransfer = (req: Request, _res: Response, next: NextFunction): void => {
  const { fromWalletId, toWalletId, amount } = req.body;

  if (!fromWalletId || typeof fromWalletId !== 'string') {
    throw new AppError('fromWalletId is required and must be a string', 400);
  }

  if (!toWalletId || typeof toWalletId !== 'string') {
    throw new AppError('toWalletId is required and must be a string', 400);
  }

  if (!amount || typeof amount !== 'number' || amount <= 0) {
    throw new AppError('amount is required and must be a positive number', 400);
  }

  if (fromWalletId === toWalletId) {
    throw new AppError('fromWalletId and toWalletId cannot be the same', 400);
  }

  next();
};

export const validateWalletId = (req: Request, _res: Response, next: NextFunction): void => {
  const { walletId } = req.params;

  if (!walletId || typeof walletId !== 'string') {
    throw new AppError('walletId parameter is required', 400);
  }

  const walletIdRegex = /^[a-zA-Z0-9_-]+$/;
  if (!walletIdRegex.test(walletId)) {
    throw new AppError('Invalid walletId format', 400);
  }

  next();
};
