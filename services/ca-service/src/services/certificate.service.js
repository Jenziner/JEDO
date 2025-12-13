const fabricCAService = require('./fabric-ca.service');
const env = require('../config/environment');
const { logger } = require('../config/logger');

class CertificateService {
  
  async registerUser({ username, secret, role, affiliation, attrs = {} }, requesterCert) {
    try {
      logger.info({ username, role, affiliation }, 'Registering new user');

      this._authorizeRegistration(role, requesterCert);

      const caClient = fabricCAService.getCAClient();
      const adminIdentity = await fabricCAService.getAdminIdentity();

      const registerRequest = {
        enrollmentID: username,
        enrollmentSecret: secret,
        role: 'client',
        affiliation: affiliation,
        maxEnrollments: -1,
        attrs: [
          { name: 'role', value: role, ecert: true },
          ...Object.entries(attrs).map(([name, value]) => ({
            name,
            value: String(value),
            ecert: true,
          })),
        ],
      };

      const registrationSecret = await caClient.register(registerRequest, adminIdentity);

      logger.info({ username, role }, 'User registered successfully');

      return {
        success: true,
        username,
        secret: registrationSecret,
        role,
        affiliation,
      };

    } catch (error) {
      logger.error({ err: error, username }, 'User registration failed');
      throw this._handleCAError(error);
    }
  }

  async enrollUser({ username, secret, role, csrOptions = {} }) {
    try {
      logger.info({ username, role }, 'Enrolling user');

      const caClient = fabricCAService.getCAClient();
      const wallet = fabricCAService.getWallet();

      const existingIdentity = await wallet.get(username);
      if (existingIdentity) {
        throw new Error(`User ${username} already enrolled`);
      }

      const enrollmentRequest = {
        enrollmentID: username,
        enrollmentSecret: secret,
      };

      if (csrOptions.cn || csrOptions.hosts || csrOptions.names) {
        enrollmentRequest.csr = {
          cn: csrOptions.cn || username,
          hosts: csrOptions.hosts || [],
          names: csrOptions.names || [],
        };
      }

      const enrollment = await caClient.enroll(enrollmentRequest);

      const identity = {
        credentials: {
          certificate: enrollment.certificate,
          privateKey: enrollment.key.toBytes(),
        },
        mspId: env.fabricCa.mspId,
        type: 'X.509',
      };

      await wallet.put(username, identity);

      logger.info({ username, role }, 'User enrolled successfully');

      return {
        success: true,
        username,
        certificate: enrollment.certificate,
        mspId: env.fabricCa.mspId,
        role,
      };

    } catch (error) {
      logger.error({ err: error, username }, 'User enrollment failed');
      throw this._handleCAError(error);
    }
  }

  async reenrollUser(username) {
    try {
      logger.info({ username }, 'Re-enrolling user');

      const caClient = fabricCAService.getCAClient();
      const wallet = fabricCAService.getWallet();

      const identity = await wallet.get(username);
      if (!identity) {
        throw new Error(`User ${username} not found`);
      }

      const enrollment = await caClient.reenroll(identity);

      const updatedIdentity = {
        credentials: {
          certificate: enrollment.certificate,
          privateKey: enrollment.key.toBytes(),
        },
        mspId: identity.mspId,
        type: identity.type,
      };

      await wallet.put(username, updatedIdentity);

      logger.info({ username }, 'User re-enrolled successfully');

      return {
        success: true,
        username,
        certificate: enrollment.certificate,
      };

    } catch (error) {
      logger.error({ err: error, username }, 'User re-enrollment failed');
      throw this._handleCAError(error);
    }
  }

  async revokeUser(username, reason = 'unspecified', requesterCert) {
    try {
      logger.info({ username, reason }, 'Revoking user');

      this._authorizeRevocation(requesterCert);

      const caClient = fabricCAService.getCAClient();
      const adminIdentity = await fabricCAService.getAdminIdentity();

      await caClient.revoke(
        {
          enrollmentID: username,
          reason: reason,
        },
        adminIdentity
      );

      const wallet = fabricCAService.getWallet();
      await wallet.remove(username);

      logger.info({ username }, 'User revoked successfully');

      return {
        success: true,
        username,
        revoked: true,
      };

    } catch (error) {
      logger.error({ err: error, username }, 'User revocation failed');
      throw this._handleCAError(error);
    }
  }

  async getCertificateInfo(username) {
    try {
      const wallet = fabricCAService.getWallet();
      const identity = await wallet.get(username);

      if (!identity) {
        throw new Error(`Certificate for ${username} not found`);
      }

      const certInfo = this._parseCertificate(identity.credentials.certificate);

      return {
        success: true,
        username,
        mspId: identity.mspId,
        type: identity.type,
        certificate: certInfo,
      };

    } catch (error) {
      logger.error({ err: error, username }, 'Failed to get certificate info');
      throw error;
    }
  }

  _authorizeRegistration(targetRole, requesterCert) {
    if (!requesterCert) {
      throw new Error('Authentication required');
    }

    const requesterRole = requesterCert.attrs?.role;

    const authRules = {
      regnum: ['ager'],
      ager: ['gens'],
      gens: ['human'],
    };

    const allowedRoles = authRules[requesterRole] || [];

    if (!allowedRoles.includes(targetRole)) {
      throw new Error(
        `Unauthorized: Role '${requesterRole}' cannot register '${targetRole}'`
      );
    }

    logger.debug({ requesterRole, targetRole }, 'Authorization check passed');
  }

  _authorizeRevocation(requesterCert) {
    if (!requesterCert) {
      throw new Error('Authentication required');
    }

    const requesterRole = requesterCert.attrs?.role;

    if (requesterRole !== 'admin' && requesterRole !== 'ager') {
      throw new Error('Unauthorized: Only admin can revoke certificates');
    }
  }

  _parseCertificate(certPem) {
    const lines = certPem.split('\n');
    return {
      pem: certPem,
      lines: lines.length,
      valid: certPem.includes('BEGIN CERTIFICATE'),
    };
  }

  _handleCAError(error) {
    if (error.message.includes('already registered')) {
      return new Error('User already registered');
    }
    if (error.message.includes('authentication failure')) {
      return new Error('Invalid credentials');
    }
    if (error.message.includes('not found')) {
      return new Error('User not found');
    }
    return error;
  }
}

module.exports = new CertificateService();
