import { Request, Response, NextFunction } from 'express';
import logger from '../config/logger';

export interface FabricProxyRequest extends Request {
  fabricIdentity?: {
    certificate: string;
    privateKey: string;
  };
}

export const extractClientIdentity = (
  req: FabricProxyRequest,
  res: Response,
  next: NextFunction
): void => {
  try {
    // Extract from headers
    const certBase64 = req.headers['x-fabric-cert'] as string;
    const keyBase64 = req.headers['x-fabric-key'] as string;

    if (!certBase64 || !keyBase64) {
      res.status(401).json({
        success: false,
        error: {
          message: 'Missing client certificate or private key in headers',
          code: 'MISSING_CLIENT_IDENTITY',
        },
      });
      return;
    }

    // Decode from Base64
    const certificate = Buffer.from(certBase64, 'base64').toString('utf8');
    const privateKey = Buffer.from(keyBase64, 'base64').toString('utf8');

    // Attach to request
    req.fabricIdentity = {
      certificate,
      privateKey,
    };

    logger.debug('Client identity extracted from headers');
    next();
  } catch (error) {
    logger.error({ err: error }, 'Failed to extract client identity');
    res.status(400).json({
      success: false,
      error: {
        message: 'Invalid client certificate format',
        code: 'INVALID_CLIENT_IDENTITY',
      },
    });
  }
};
