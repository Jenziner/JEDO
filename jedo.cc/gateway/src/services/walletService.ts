import * as fs from 'fs';
import * as path from 'path';

import logger from '../config/logger';
import { fabricConfig, readCertificate, readPrivateKey } from '../config/fabric';
import { WalletIdentity } from '../types/fabric';

export class WalletService {
  private walletPath: string;

  constructor(walletPath: string = fabricConfig.walletPath) {
    this.walletPath = path.resolve(walletPath);
    this.ensureWalletDirectory();
  }

  private ensureWalletDirectory(): void {
    if (!fs.existsSync(this.walletPath)) {
      fs.mkdirSync(this.walletPath, { recursive: true });
      logger.info({ walletPath: this.walletPath }, 'Wallet directory created');
    }
  }

  private getIdentityPath(label: string): string {
    return path.join(this.walletPath, `${label}.json`);
  }

  async put(label: string, identity: WalletIdentity): Promise<void> {
    try {
      const identityPath = this.getIdentityPath(label);
      fs.writeFileSync(identityPath, JSON.stringify(identity, null, 2));
      logger.info({ label, walletPath: this.walletPath }, 'Identity stored in wallet');
    } catch (error) {
      logger.error({ err: error, label }, 'Failed to store identity in wallet');
      throw error;
    }
  }

  async get(label: string): Promise<WalletIdentity | null> {
    try {
      const identityPath = this.getIdentityPath(label);
      if (!fs.existsSync(identityPath)) {
        return null;
      }
      const data = fs.readFileSync(identityPath, 'utf8');
      return JSON.parse(data) as WalletIdentity;
    } catch (error) {
      logger.error({ err: error, label }, 'Failed to retrieve identity from wallet');
      throw error;
    }
  }

  async exists(label: string): Promise<boolean> {
    const identityPath = this.getIdentityPath(label);
    return fs.existsSync(identityPath);
  }

  async list(): Promise<string[]> {
    try {
      const files = fs.readdirSync(this.walletPath);
      return files.filter((f) => f.endsWith('.json')).map((f) => f.replace('.json', ''));
    } catch (error) {
      logger.error({ err: error }, 'Failed to list wallet identities');
      return [];
    }
  }

  async remove(label: string): Promise<void> {
    try {
      const identityPath = this.getIdentityPath(label);
      if (fs.existsSync(identityPath)) {
        fs.unlinkSync(identityPath);
        logger.info({ label }, 'Identity removed from wallet');
      }
    } catch (error) {
      logger.error({ err: error, label }, 'Failed to remove identity from wallet');
      throw error;
    }
  }

  async importIdentity(
    label: string,
    mspId: string,
    certPath: string,
    keyPath: string
  ): Promise<void> {
    try {
      const certificate = readCertificate(certPath).toString('utf8');
      const privateKey = readPrivateKey(keyPath).toString('utf8');

      const identity: WalletIdentity = {
        label,
        mspId,
        certificate,
        privateKey,
      };

      await this.put(label, identity);
      logger.info({ label, mspId }, 'Identity imported successfully');
    } catch (error) {
      logger.error({ err: error, label }, 'Failed to import identity');
      throw error;
    }
  }

  /**
  * Import identity directly from infrastructure directory
  */
  async importFromInfrastructure(
    identityName: string,
    orbis: string = 'jedo',
    regnum: string = 'ea',
    ager: string = 'alps'
  ): Promise<void> {
    try {
      const basePath = path.resolve(`./infrastructure/${orbis}/${regnum}/${ager}/${identityName}`);

      if (!fs.existsSync(basePath)) {
        throw new Error(`Identity not found in infrastructure: ${basePath}`);
      }

      const certPath = path.join(basePath, 'msp/signcerts/cert.pem');
      const keystoreDir = path.join(basePath, 'msp/keystore');

      if (!fs.existsSync(certPath)) {
        throw new Error(`Certificate not found: ${certPath}`);
      }

      if (!fs.existsSync(keystoreDir)) {
        throw new Error(`Keystore directory not found: ${keystoreDir}`);
      }

      // Find private key file (*_sk)
      const files = fs.readdirSync(keystoreDir);
      const keyFile = files.find((f) => f.endsWith('_sk'));

      if (!keyFile) {
        throw new Error(`Private key not found in: ${keystoreDir}`);
      }

      const keyPath = path.join(keystoreDir, keyFile);

      await this.importIdentity(identityName, ager, certPath, keyPath);
      logger.info(
        { identityName, path: basePath },
        'Identity imported from infrastructure successfully'
      );
    } catch (error) {
      logger.error({ err: error, identityName }, 'Failed to import identity from infrastructure');
      throw error;
    }
  }
}

export const walletService = new WalletService();
