import { Router } from 'express';

import { walletController } from '../controllers/walletController';
import {
  validateCreateWallet,
  validateTransfer,
  validateWalletId,
} from '../validators/walletValidators';
import { asyncHandler } from '../middlewares/asyncHandler';

const router = Router();

/**
 * @route   POST /api/v1/wallets
 * @desc    Create a new wallet
 * @access  Private
 */
router.post(
  '/',
  validateCreateWallet,
  asyncHandler(walletController.createWallet.bind(walletController))
);

/**
 * @route   POST /api/v1/wallets/transfer
 * @desc    Transfer funds between wallets
 * @access  Private
 */
router.post(
  '/transfer',
  validateTransfer,
  asyncHandler(walletController.transfer.bind(walletController))
);

/**
 * @route   GET /api/v1/wallets/:walletId/balance
 * @desc    Get wallet balance
 * @access  Private
 */
router.get(
  '/:walletId/balance',
  validateWalletId,
  asyncHandler(walletController.getBalance.bind(walletController))
);

/**
 * @route   GET /api/v1/wallets/:walletId
 * @desc    Get wallet details
 * @access  Private
 */
router.get(
  '/:walletId',
  validateWalletId,
  asyncHandler(walletController.getWallet.bind(walletController))
);

/**
 * @route   GET /api/v1/wallets/:walletId/history
 * @desc    Get wallet transaction history
 * @access  Private
 */
router.get(
  '/:walletId/history',
  validateWalletId,
  asyncHandler(walletController.getWalletHistory.bind(walletController))
);

export default router;
