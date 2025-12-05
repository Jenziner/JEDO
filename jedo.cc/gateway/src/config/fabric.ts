import * as fs from 'fs';
import * as path from 'path';

import { env } from './environment';
import logger from './logger';
import { FabricConfig } from '../types/fabric';

export const fabricConfig: FabricConfig = {
  mspId: env.fabric.mspId,
  channelName: env.fabric.channelName,
  chaincodeName: env.fabric.chaincodeName,
  peerEndpoint: env.fabric.peerEndpoint,
  peerHostAlias: env.fabric.peerHostAlias,
  tlsCertPath: env.fabric.tlsCertPath,
  tlsRootCertPath: env.fabric.tlsRootCertPath,
  identityName: env.fabric.issuer.name,
  identityCertPath: env.fabric.issuer.certPath,
  identityKeyPath: env.fabric.issuer.keyPath,
  walletPath: env.walletPath,
};

export const readCertificate = (certPath: string): Buffer => {
  const absolutePath = path.resolve(certPath);

  // Handle wildcard (z.B. *.pem)
  if (certPath.includes('*')) {
    const dir = path.dirname(absolutePath);
    const pattern = path.basename(absolutePath);

    if (!fs.existsSync(dir)) {
      logger.error(`Certificate directory not found: ${dir}`);
      throw new Error(`Certificate directory not found: ${dir}`);
    }

    const files = fs.readdirSync(dir);
    const certFile = files.find((f) => f.endsWith('.pem'));

    if (!certFile) {
      logger.error(`Certificate not found matching pattern: ${pattern} in ${dir}`);
      throw new Error(`Certificate file not found in: ${certPath}`);
    }

    const fullPath = path.join(dir, certFile);
    logger.debug(`Using certificate: ${fullPath}`);
    return fs.readFileSync(fullPath);
  }

  if (!fs.existsSync(absolutePath)) {
    logger.error(`Certificate not found: ${absolutePath}`);
    throw new Error(`Certificate file not found: ${certPath}`);
  }
  
  return fs.readFileSync(absolutePath);
};

export const readPrivateKey = (keyPath: string): Buffer => {
  const absolutePath = path.resolve(keyPath);

  // Handle wildcard for keystore (z.B. *_sk files)
  if (keyPath.includes('*')) {
    const dir = path.dirname(absolutePath);
    const pattern = path.basename(absolutePath);

    if (!fs.existsSync(dir)) {
      logger.error(`Keystore directory not found: ${dir}`);
      throw new Error(`Keystore directory not found: ${dir}`);
    }

    const files = fs.readdirSync(dir);
    const keyFile = files.find((f) => (pattern === '*_sk' ? f.endsWith('_sk') : f.match(pattern)));

    if (!keyFile) {
      logger.error(`Private key not found matching pattern: ${pattern} in ${dir}`);
      throw new Error(`Private key file not found in: ${keyPath}`);
    }

    const fullPath = path.join(dir, keyFile);
    logger.debug(`Using private key: ${fullPath}`);
    return fs.readFileSync(fullPath);
  }

  if (!fs.existsSync(absolutePath)) {
    logger.error(`Private key not found: ${absolutePath}`);
    throw new Error(`Private key file not found: ${keyPath}`);
  }

  return fs.readFileSync(absolutePath);
};

export const validateFabricConfig = (): void => {
  logger.info('Validating Fabric configuration...');

  const checks = [
    {
      name: 'Infrastructure Directory',
      path: './infrastructure/jedo/ea/alps',
      isDirectory: true,
      allowWildcard: false,
    },
    {
      name: 'Peer TLS Certificate',
      path: fabricConfig.tlsCertPath,
      isDirectory: false,
      allowWildcard: true,
    },
    {
      name: 'Peer TLS Root Certificate',
      path: fabricConfig.tlsRootCertPath,
      isDirectory: false,
      allowWildcard: true,
    },
    {
      name: 'Issuer Certificate',
      path: fabricConfig.identityCertPath,
      isDirectory: false,
      allowWildcard: false,
    },
    {
      name: 'Issuer Private Key Directory',
      path: path.dirname(fabricConfig.identityKeyPath),
      isDirectory: true,
      allowWildcard: false,
    },
  ];

  const missingPaths: string[] = [];

  checks.forEach(({ name, path: checkPath, isDirectory, allowWildcard }) => {
    const resolvedPath = path.resolve(checkPath);

    // Handle wildcard paths
    if (allowWildcard && checkPath.includes('*')) {
      const dir = path.dirname(resolvedPath);

      if (!fs.existsSync(dir)) {
        missingPaths.push(`${name}: ${checkPath} (directory not found)`);
        return;
      }

      const files = fs.readdirSync(dir);
      const matchingFile = files.find((f) => f.endsWith('.pem'));

      if (!matchingFile) {
        missingPaths.push(`${name}: ${checkPath} (no matching file found)`);
      }
      return;
    }

    // Regular path checks
    if (isDirectory) {
      if (!fs.existsSync(resolvedPath) || !fs.statSync(resolvedPath).isDirectory()) {
        missingPaths.push(`${name}: ${checkPath} (directory not found)`);
      }
    } else {
      if (!fs.existsSync(resolvedPath)) {
        missingPaths.push(`${name}: ${checkPath}`);
      }
    }
  });

  // Validate private key file exists (with wildcard support)
  try {
    readPrivateKey(fabricConfig.identityKeyPath);
  } catch (error) {
    missingPaths.push(`Issuer Private Key: ${fabricConfig.identityKeyPath}`);
  }

  if (missingPaths.length > 0) {
    logger.error({ missingPaths }, 'Missing Fabric certificates/keys');
    throw new Error(`Missing required Fabric files:\n${missingPaths.join('\n')}`);
  }

  logger.info(
    {
      mspId: fabricConfig.mspId,
      channel: fabricConfig.channelName,
      chaincode: fabricConfig.chaincodeName,
      peerEndpoint: fabricConfig.peerEndpoint,
      identity: fabricConfig.identityName,
      infrastructureMount: path.resolve('./infrastructure'),
    },
    'Fabric configuration validated successfully'
  );
};

export const getInfrastructurePath = (
  orbis: string,
  regnum: string,
  ager: string,
  entity: string
): string => {
  return path.resolve(`./infrastructure/${orbis}/${regnum}/${ager}/${entity}`);
};

export const listIdentities = (
  orbis: string = 'jedo',
  regnum: string = 'ea',
  ager: string = 'alps'
): string[] => {
  try {
    const agerPath = path.resolve(`./infrastructure/${orbis}/${regnum}/${ager}`);
    const entries = fs.readdirSync(agerPath, { withFileTypes: true });

    return entries
      .filter((entry) => entry.isDirectory())
      .filter((entry) => {
        const mspPath = path.join(agerPath, entry.name, 'msp');
        return fs.existsSync(mspPath);
      })
      .map((entry) => entry.name);
  } catch (error) {
    logger.error({ err: error }, 'Failed to list identities from infrastructure');
    return [];
  }
};
