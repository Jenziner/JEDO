import { Router, Response } from 'express';
import { extractClientIdentity, FabricProxyRequest } from '../middlewares/fabricProxy';
import { submitTransaction, evaluateTransaction } from '../controllers/proxyController';
import {
  validateCreateWallet,
  validateTransfer,
  validateWalletId,
} from '../validators/walletValidators';
import { asyncHandler } from '../middlewares/asyncHandler';

// Import rate limiters
import {
  financialWriteLimit,
  walletCreateLimit,
  balanceReadLimit,
  historyReadLimit,
  walletReadLimit,
} from '../middlewares/routeRateLimits';

const router = Router();

// All routes require Client-Identity
router.use(extractClientIdentity);

/**
 * @route POST /api/v1/wallets
 * @desc Create a new wallet
 * @limit 3 requests per minute per certificate
 */
router.post(
  '/',
  walletCreateLimit, // 3/min
  validateCreateWallet,
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    const { walletId, ownerId, initialBalance, metadata } = req.body;

    req.body = {
      channelName: 'ea',
      chaincodeName: 'jedo-wallet',
      functionName: 'CreateWallet',
      args: [
        req.body.walletId,
        req.body.ownerId,
        req.body.initialBalance?.toString() || '0',
        JSON.stringify(metadata || {}),
      ],
    };
    await submitTransaction(req, res);
  })
);

/**
 * @route POST /api/v1/wallets/transfer
 * @desc Transfer funds between wallets
 * @limit 5 requests per minute per certificate
 */
router.post(
  '/transfer',
  financialWriteLimit, // 5/min
  validateTransfer,
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    req.body = {
      channelName: 'ea',
      chaincodeName: 'jedo-wallet',
      functionName: 'Transfer',
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
 * @route GET /api/v1/wallets/:walletId/balance
 * @desc Get wallet balance
 * @limit 100 requests per minute per certificate
 */
router.get(
  '/:walletId/balance',
  balanceReadLimit, // 100/min
  validateWalletId,
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    req.body = {
      channelName: 'ea',
      chaincodeName: 'jedo-wallet',
      functionName: 'GetBalance',
      args: [req.params.walletId],
    };
    await evaluateTransaction(req, res);
  })
);

/**
 * @route GET /api/v1/wallets/:walletId
 * @desc Get wallet details
 * @limit 100 requests per minute per certificate
 */
router.get(
  '/:walletId',
  walletReadLimit, // 100/min
  validateWalletId,
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    req.body = {
      channelName: 'ea',
      chaincodeName: 'jedo-wallet',
      functionName: 'GetWallet',
      args: [req.params.walletId],
    };
    await evaluateTransaction(req, res);
  })
);

/**
 * @route GET /api/v1/wallets/:walletId/history
 * @desc Get wallet transaction history
 * @limit 50 requests per minute per certificate
 */
router.get(
  '/:walletId/history',
  historyReadLimit, // 50/min
  validateWalletId,
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    req.body = {
      channelName: 'ea',
      chaincodeName: 'jedo-wallet',
      functionName: 'GetWalletHistory',
      args: [req.params.walletId],
    };
    await evaluateTransaction(req, res);
  })
);

export default router;
