import { Response } from 'express';
import { FabricProxyRequest } from '../middlewares/fabricProxy';
import { fabricProxyService } from '../services/fabricProxyService';
import logger from '../config/logger';

/**
 * Submit a transaction to the Fabric network
 */
export const submitTransaction = async (req: FabricProxyRequest, res: Response): Promise<void> => {
  const { channelName, chaincodeName, functionName, args } = req.body;
  const { certificate, privateKey } = req.fabricIdentity!;

  // Validation
  if (!functionName) {
    res.status(400).json({
      success: false,
      error: {
        message: 'Missing function name',
      },
    });
    return;
  }

  if (!channelName || !chaincodeName) {
    res.status(400).json({
      success: false,
      error: {
        message: 'Missing channelName or chaincodeName',
      },
    });
    return;
  }

  if (!Array.isArray(args)) {
    res.status(400).json({
      success: false,
      error: {
        message: 'args must be an array',
      },
    });
    return;
  }

  try {
    logger.info(
      {
        function: functionName,
        args: args,
        channel: channelName,
        chaincode: chaincodeName,
      },
      'Submitting transaction'
    );

    const result = await fabricProxyService.submitWithClientIdentity(
      certificate,
      privateKey,
      channelName,
      chaincodeName,
      functionName,
      args
    );

    res.json({
      success: true,
      data: {
        rresult: Buffer.from(result).toString('utf8'),
        function: functionName,
      },
    });
  } catch (error: any) {
    logger.error({ err: error, function: functionName }, 'Transaction submission failed');
    res.status(500).json({
      success: false,
      error: {
        message: error.message || 'Transaction failed',
      },
    });
  }
};

/**
 * Evaluate (query) a transaction from the Fabric network
 */
export const evaluateTransaction = async (req: FabricProxyRequest, res: Response): Promise<void> => {
  const { channelName, chaincodeName, functionName, args } = req.body;
  const { certificate, privateKey } = req.fabricIdentity!;

  // Validation
  if (!functionName) {
    res.status(400).json({
      success: false,
      error: {
        message: 'Missing function name',
      },
    });
    return;
  }

  if (!channelName || !chaincodeName) {
    res.status(400).json({
      success: false,
      error: {
        message: 'Missing channelName or chaincodeName',
      },
    });
    return;
  }

  if (!Array.isArray(args)) {
    res.status(400).json({
      success: false,
      error: {
        message: 'args must be an array',
      },
    });
    return;
  }

  try {
    logger.info(
      {
        function: functionName,
        args: args,
        channel: channelName,
        chaincode: chaincodeName,
      },
      'Evaluating transaction'
    );

    const result = await fabricProxyService.evaluateWithClientIdentity(
      certificate,
      privateKey,
      channelName,
      chaincodeName,
      functionName,
      args
    );

    res.json({
      success: true,
      data: {
        result: Buffer.from(result).toString('utf8'),
        function: functionName,
      },
    });
  } catch (error: any) {
    logger.error({ err: error, function: functionName }, 'Transaction evaluation failed');
    res.status(500).json({
      success: false,
      error: {
        message: error.message || 'Query failed',
      },
    });
  }
};
