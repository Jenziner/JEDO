import { Router, Request, Response } from 'express';

import { fabricProxyService } from '../services/fabricProxyService';
import { fabricConfig } from '../config/fabric';

const router = Router();

interface HealthResponse {
  success: boolean;
  data: {
    status: string;
    timestamp: string;
    uptime: number;
    environment: string;
    version: string;
    fabric?: {
      connected: boolean;
      mspId: string;
      channel: string;
      chaincode: string;
    };
  };
}

router.get('/health', async (_req: Request, res: Response<HealthResponse>) => {
  try {
    const healthcheck: HealthResponse = {
      success: true,
      data: {
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
        version: process.env.npm_package_version || '1.0.0',
        fabric: {
          connected: true,
          mspId: fabricConfig.mspId,
          channel: fabricConfig.channelName,
          chaincode: fabricConfig.chaincodeName,
        },
      },
    };

    res.status(200).json(healthcheck);
  } catch (_error) {
    res.status(500).json({
      success: false,
      data: {
        status: 'ERROR',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development',
        version: process.env.npm_package_version || '1.0.0',
      },
    });
  }
});

router.get('/ready', async (_req: Request, res: Response) => {
  try {
    const isConnected = fabricProxyService['grpcClient'] !== null;

    if (!isConnected) {
      return res.status(503).json({
        success: false,
        data: {
          status: 'Not Ready',
          message: 'Fabric Gateway not connected',
          timestamp: new Date().toISOString(),
        },
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        status: 'Ready',
        timestamp: new Date().toISOString(),
      },
    });
  } catch (_error) {
    return res.status(503).json({
      success: false,
      data: {
        status: 'Not Ready',
        timestamp: new Date().toISOString(),
      },
    });
  }
});

router.get('/live', (_req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    data: {
      status: 'Alive',
      timestamp: new Date().toISOString(),
    },
  });
});

export default router;
