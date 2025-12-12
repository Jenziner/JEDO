import pino from 'pino';
import { env } from './environment';

const transport = env.nodeEnv === 'development' && env.logPretty
  ? {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: 'HH:MM:ss.l',
        ignore: 'pid,hostname',
      },
    }
  : undefined;

const logger = pino({
  level: env.logLevel,
  transport,
});

export default logger;
