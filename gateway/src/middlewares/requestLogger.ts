import { Request, Response } from 'express';
import pinoHttp from 'pino-http';

import logger from '../config/logger';

export const requestLogger = pinoHttp({
  logger,
  autoLogging: true,
  customLogLevel: (_req: Request, res: Response, err?: Error) => {
    if (res.statusCode >= 500 || err) {
      return 'error';
    }
    if (res.statusCode >= 400) {
      return 'warn';
    }
    return 'info';
  },
  customSuccessMessage: (req: Request, _res: Response) => {
    return `${req.method} ${req.url} completed`;
  },
  customErrorMessage: (req: Request, _res: Response, err: Error) => {
    return `${req.method} ${req.url} failed: ${err.message}`;
  },
  serializers: {
    req: (req) => ({
      id: req.id,
      method: req.method,
      url: req.url,
      remoteAddress: req.remoteAddress,
      remotePort: req.remotePort,
    }),
    res: (res) => ({
      statusCode: res.statusCode,
    }),
  },
});
