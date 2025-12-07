import { Router, Response } from 'express';
import { extractClientIdentity, FabricProxyRequest } from '../middlewares/fabricProxy';
import { submitTransaction, evaluateTransaction } from '../controllers/proxyController';
import { asyncHandler } from '../utils/asyncHandler';
import { adminProxyLimit, queryProxyLimit } from '../middlewares/routeRateLimits';

const router = Router();

// Apply Fabric proxy middleware to extract client identity from headers
router.use(extractClientIdentity);

/**
 * @route POST /api/v1/proxy/submit
 * @desc Submit a transaction to Fabric chaincode (admin operations)
 * @limit 5 requests per minute per certificate
 */
router.post(
  '/submit',
  adminProxyLimit, // 5/min
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    await submitTransaction(req, res);
  })
);

/**
 * @route POST /api/v1/proxy/evaluate
 * @desc Evaluate (query) a transaction from Fabric chaincode
 * @limit 50 requests per minute per certificate
 */
router.post(
  '/evaluate',
  queryProxyLimit, // 50/min
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    await evaluateTransaction(req, res);
  })
);

export default router;
