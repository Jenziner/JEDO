import { Router, Response } from 'express';

import { extractClientIdentity, FabricProxyRequest } from '../middlewares/fabricProxy';
import { submitTransaction, evaluateTransaction } from '../controllers/proxyController';
import {
  validateCreateWallet,
  validateTransfer,
  validateWalletId,
} from '../validators/walletValidators';
import { asyncHandler } from '../middlewares/asyncHandler';

const router = Router();

// All routes require Client-Identity
router.use(extractClientIdentity);

/**
 * @route   POST /api/v1/wallets
 * @desc    Create a new wallet (via client identity)
 * @access  Private (requires X-Fabric-Cert + X-Fabric-Key headers)
 */
router.post(
  '/',
  validateCreateWallet,
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    req.body = {
      function: 'CreateWallet',
      args: [
        req.body.walletId,
        req.body.ownerId,
        req.body.initialBalance?.toString() || '0',
      ],
    };
    await submitTransaction(req, res);
  })
);

/**
 * @route   POST /api/v1/wallets/transfer
 * @desc    Transfer funds between wallets
 * @access  Private
 */
router.post(
  '/transfer',
  validateTransfer,
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    req.body = {
      function: 'Transfer',
      args: [
        req.body.fromWallet,
        req.body.toWallet,
        req.body.amount.toString(),
      ],
    };
    await submitTransaction(req, res);
  })
);

/**
 * @route   GET /api/v1/wallets/:walletId/balance
 * @desc    Get wallet balance
 * @access  Private
 */
router.get(
  '/:walletId/balance',
  validateWalletId,
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    req.body = {
      function: 'GetBalance',
      args: [req.params.walletId],
    };
    await evaluateTransaction(req, res);
  })
);

/**
 * @route   GET /api/v1/wallets/:walletId
 * @desc    Get wallet details
 * @access  Private
 */
router.get(
  '/:walletId',
  validateWalletId,
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    req.body = {
      function: 'GetWallet',
      args: [req.params.walletId],
    };
    await evaluateTransaction(req, res);
  })
);

/**
 * @route   GET /api/v1/wallets/:walletId/history
 * @desc    Get wallet transaction history
 * @access  Private
 */
router.get(
  '/:walletId/history',
  validateWalletId,
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    req.body = {
      function: 'GetWalletHistory',
      args: [req.params.walletId],
    };
    await evaluateTransaction(req, res);
  })
);

export default router;
