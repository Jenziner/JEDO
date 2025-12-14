const FabricCAServices = require('fabric-ca-client');
const { User } = require('fabric-common');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { logger } = require('../config/logger');

class CertificateService {
  constructor() {
    this.caClient = null;
    this.adminUser = null;
  }

  async initialize() {
    try {
      logger.info('Initializing CA Service...');
      
      const tlsCertPath = process.env.FABRIC_CA_TLS_CERT_PATH;
      const caUrl = process.env.FABRIC_CA_URL;
      const caName = process.env.FABRIC_CA_NAME;
      
      if (!tlsCertPath || !caUrl) {
        throw new Error('FABRIC_CA_TLS_CERT_PATH and FABRIC_CA_URL must be set');
      }

      logger.info('CA connection details', { caUrl, caName, tlsCertPath });

      if (!fs.existsSync(tlsCertPath)) {
        throw new Error(`Fabric CA TLS cert not found: ${tlsCertPath}`);
      }
      const tlsCert = fs.readFileSync(tlsCertPath, 'utf8');
      
      const tlsOptions = {
        trustedRoots: tlsCert,
        verify: process.env.FABRIC_CA_TLS_VERIFY === 'true'
      };

      this.caClient = new FabricCAServices(caUrl, tlsOptions, caName);
      logger.info('Fabric CA Client created');

      await this.enrollBootstrapAdmin();
      
      logger.info('✅ CA Service initialized successfully', { 
        caUrl,
        caName,
        hasRegistrar: !!this.adminUser 
      });
      
    } catch (error) {
      logger.error('CA initialization failed', { 
        error: error.message,
        stack: error.stack 
      });
      throw error;
    }
  }

  async enrollBootstrapAdmin() {
    try {
      const adminUsername = process.env.FABRIC_CA_ADMIN_USER;
      const adminPass = process.env.FABRIC_CA_ADMIN_PASS;
      const mspId = process.env.FABRIC_MSP_ID || 'AlpsMSP';
      
      if (!adminUsername || !adminPass) {
        throw new Error('FABRIC_CA_ADMIN_USER and FABRIC_CA_ADMIN_PASS must be set');
      }
      
      logger.info('Enrolling bootstrap admin', { adminUsername });
      
      const enrollment = await this.caClient.enroll({
        enrollmentID: adminUsername,
        enrollmentSecret: adminPass
      });
      
      logger.info('Bootstrap admin enrollment successful');
      
      const user = new User(adminUsername);
      user.setCryptoSuite(this.caClient.getCryptoSuite());
      
      await user.setEnrollment(
        enrollment.key,
        enrollment.certificate,
        mspId
      );
      
      this.adminUser = user;
      
      logger.info('Bootstrap admin User object created', { 
        adminUsername, 
        mspId
      });
      
    } catch (error) {
      logger.error('Failed to enroll bootstrap admin', { 
        error: error.message,
        stack: error.stack
      });
      throw error;
    }
  }

  async registerUser(username, secret, role, affiliation, attrs = {}) {
    try {
      logger.info('Registering new user', { username, role, affiliation });
      
      if (!this.adminUser) {
        throw new Error('Registrar User not loaded');
      }

      // Build attributes array
      const attributes = [
        { name: 'role', value: role, ecert: true }
      ];
      
      // Add custom attributes
      for (const [name, value] of Object.entries(attrs)) {
        attributes.push({
          name,
          value: String(value),
          ecert: true
        });
      }

      const request = {
        enrollmentID: username,
        enrollmentSecret: secret,
        role: 'client',
        affiliation,
        maxEnrollments: -1,
        attrs: attributes
      };

      logger.info('Registration request', { 
        username, 
        role, 
        attrs: attributes.map(a => a.name)
      });

      const registerResponse = await this.caClient.register(
        request,
        this.adminUser
      );

      logger.info('User registered successfully', { 
        username,
        secret: registerResponse 
      });

      return { username, secret: registerResponse };
      
    } catch (error) {
      logger.error('User registration failed', { 
        error: error.message,
        stack: error.stack 
      });
      throw error;
    }
  }
  
  async enrollUser(enrollmentData) {
    const { 
      username, 
      secret, 
      enrollmentType = 'x509',
      idemixCurve = 'gurvy.Bn254',
      csr 
    } = enrollmentData;
    
    try {
      logger.info('Enrolling user', { username, enrollmentType });
      
      if (enrollmentType === 'idemix') {
        return await this._enrollIdemix(username, secret, idemixCurve);
      } else {
        return await this._enrollX509(username, secret, csr);
      }
      
    } catch (error) {
      logger.error('User enrollment failed', { 
        error: error.message,
        username 
      });
      throw error;
    }
  }
  
  async _enrollX509(username, secret, csr) {
    const enrollmentRequest = {
      enrollmentID: username,
      enrollmentSecret: secret,
      // REQUEST ALL ATTRIBUTES TO BE INCLUDED IN CERTIFICATE
      attr_reqs: [
        { name: 'role', optional: false },
        { name: 'hf.Registrar.Roles', optional: true },
        { name: 'hf.Registrar.Attributes', optional: true },
        { name: 'hf.Revoker', optional: true },
        { name: 'hf.EnrollmentID', optional: true },
        { name: 'hf.Type', optional: true },
        { name: 'hf.Affiliation', optional: true }
      ]
    };
    
    // Only add CSR if provided AND if it's a string (PEM format)
    if (csr) {
      if (typeof csr === 'string') {
        // It's already a PEM string
        enrollmentRequest.csr = csr;
      } else if (typeof csr === 'object' && csr.attrs) {
        // Merge custom attribute requests
        const customAttrReqs = Object.keys(csr.attrs).map(name => ({
          name,
          optional: false
        }));
        enrollmentRequest.attr_reqs = [
          ...enrollmentRequest.attr_reqs,
          ...customAttrReqs
        ];
      }
    }
    
    logger.info('Enrollment with attr_reqs', { 
      username,
      attr_reqs: enrollmentRequest.attr_reqs.map(a => a.name)
    });
    
    const enrollment = await this.caClient.enroll(enrollmentRequest);
    
    logger.info('X.509 enrollment successful', { username });
    
    // Get private key as string and normalize line endings
    let privateKeyPem = enrollment.key.toBytes();
    
    // Normalize line endings: \r\n -> \n
    if (typeof privateKeyPem === 'string') {
      privateKeyPem = privateKeyPem.replace(/\r\n/g, '\n');
    }
    
    return {
      certificate: enrollment.certificate,
      privateKey: privateKeyPem,
      rootCertificate: enrollment.rootCertificate,
      caChain: enrollment.caChain
    };
  }
  
  /**
   * Idemix Enrollment via CLI
   * TODO: Switch to SDK when fabric-ca-client npm package supports Idemix
   */
  async _enrollIdemix(username, secret, curve) {
    const tempMspDir = `/tmp/idemix-${username}-${Date.now()}`;
    
    try {
      logger.info('Starting Idemix enrollment via CLI', { username, curve });
      
      // Ensure temp directory exists
      fs.mkdirSync(tempMspDir, { recursive: true });
      
      // Build CLI command
      const caUrl = process.env.FABRIC_CA_URL.replace('https://', '');
      const command = `/usr/local/bin/fabric-ca-client enroll \
        -u https://${username}:${secret}@${caUrl} \
        --caname ${process.env.FABRIC_CA_NAME} \
        --tls.certfiles ${process.env.FABRIC_CA_TLS_CERT_PATH} \
        --mspdir ${tempMspDir} \
        --enrollment.type idemix \
        --idemix.curve ${curve}`;
      
      logger.debug('Executing fabric-ca-client CLI', { 
        command: command.replace(secret, '****'),
        tempMspDir 
      });
      
      // Execute CLI command
      const output = execSync(command, { 
        encoding: 'utf8',
        stdio: 'pipe',
        env: { 
          ...process.env,
          PATH: '/usr/local/bin:/usr/bin:/bin'
        },
      });
      
      logger.debug('CLI execution completed', { output });
      
      // Read generated Idemix credentials
      const signerConfigPath = path.join(tempMspDir, 'user', 'SignerConfig');
      const issuerPublicKeyPath = path.join(tempMspDir, 'msp', 'IssuerPublicKey');
      const issuerRevocationPublicKeyPath = path.join(tempMspDir, 'msp', 'IssuerRevocationPublicKey');
      
      if (!fs.existsSync(signerConfigPath)) {
        throw new Error(`SignerConfig not found at ${signerConfigPath}`);
      }
      
      const signerConfig = fs.readFileSync(signerConfigPath, 'utf8');
      const issuerPublicKey = fs.existsSync(issuerPublicKeyPath) 
        ? fs.readFileSync(issuerPublicKeyPath, 'utf8') 
        : null;
      const issuerRevocationPublicKey = fs.existsSync(issuerRevocationPublicKeyPath)
        ? fs.readFileSync(issuerRevocationPublicKeyPath, 'utf8')
        : null;
      
      // Cleanup temp directory
      fs.rmSync(tempMspDir, { recursive: true, force: true });
      
      logger.info('✅ Idemix enrollment successful via CLI', { 
        username,
        hasSignerConfig: !!signerConfig,
        hasIssuerPublicKey: !!issuerPublicKey,
        hasRevocationKey: !!issuerRevocationPublicKey
      });
      
      return {
        signerConfig,
        issuerPublicKey,
        issuerRevocationPublicKey,
        curve
      };
      
    } catch (error) {
      logger.error('Idemix enrollment via CLI failed', {
        error: error.message,
        stderr: error.stderr?.toString(),
        stdout: error.stdout?.toString(),
        username
      });
      
      // Cleanup on error
      try {
        if (fs.existsSync(tempMspDir)) {
          fs.rmSync(tempMspDir, { recursive: true, force: true });
        }
      } catch (cleanupError) {
        logger.error('Cleanup failed', { error: cleanupError.message });
      }
      
      throw new Error(`Idemix enrollment failed: ${error.message}`);
    }
  }
}

module.exports = new CertificateService();
