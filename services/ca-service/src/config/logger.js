const pino = require('pino');
const env = require('./environment');

/**
 * Create Pino Logger
 * - Development: Pretty-printed colored logs (if pino-pretty available)
 * - Production: JSON logs for log aggregation
 */
const createLogger = () => {
  const baseConfig = {
    name: env.serviceName,
    level: env.logLevel,
    serializers: {
      req: pino.stdSerializers.req,
      res: pino.stdSerializers.res,
      err: pino.stdSerializers.err,
    },
  };

  // Try to use pino-pretty in development
  if (env.logPretty && env.isDevelopment()) {
    try {
      // Check if pino-pretty is available
      require.resolve('pino-pretty');
      
      return pino({
        ...baseConfig,
        transport: {
          target: 'pino-pretty',
          options: {
            colorize: true,
            translateTime: 'SYS:standard',
            ignore: 'pid,hostname',
          },
        },
      });
    } catch (error) {
      // pino-pretty not available, fall back to JSON
      console.warn('pino-pretty not found, using JSON output');
    }
  }

  // Production: JSON output
  return pino(baseConfig);
};

const logger = createLogger();

module.exports = { logger };
