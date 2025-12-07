import { Router, Response } from 'express';
import { extractClientIdentity, FabricProxyRequest } from '../middlewares/fabricProxy';
import { submitTransaction, evaluateTransaction } from '../controllers/proxyController';
import { asyncHandler } from '../utils/asyncHandler';

const router = Router();

// Apply Fabric proxy middleware to extract client identity from headers
router.use(extractClientIdentity);

/**
 * @route POST /api/v1/proxy/submit
 * @description Submit a transaction to Fabric chaincode
 */
router.post(
  '/submit',
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    await submitTransaction(req, res);
  })
);

/**
 * @route POST /api/v1/proxy/evaluate
 * @description Evaluate (query) a transaction from Fabric chaincode
 */
router.post(
  '/evaluate',
  asyncHandler(async (req: FabricProxyRequest, res: Response) => {
    await evaluateTransaction(req, res);
  })
);

export default router;
