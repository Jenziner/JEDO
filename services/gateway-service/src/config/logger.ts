import pino from 'pino';

import { env, isDevelopment } from './environment';

const transport = isDevelopment() && env.logPretty
  ? {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: 'HH:MM:ss Z',
        ignore: 'pid,hostname',
        singleLine: false,
      },
    }
  : undefined;

export const logger = pino(
  {
    level: env.logLevel,
    formatters: {
      level: (label) => {
        return { level: label };
      },
    },
    timestamp: pino.stdTimeFunctions.isoTime,
    serializers: {
      req: pino.stdSerializers.req,
      res: pino.stdSerializers.res,
      err: pino.stdSerializers.err,
    },
  },
  transport ? pino.transport(transport) : undefined
);

export default logger;
