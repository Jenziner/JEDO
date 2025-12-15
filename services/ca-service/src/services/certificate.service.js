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

      this.idemixIssuerKeys = await this._loadIdemixIssuerKeys()
      
      logger.info('✅ CA Service initialized successfully', { 
        caUrl,
        caName,
        hasRegistrar: !!this.adminUser,
        hasIdemixKeys: !!(this.idemixIssuerKeys.issuerPublicKey && this.idemixIssuerKeys.issuerRevocationPublicKey)
      });
      
    } catch (error) {
      logger.error('CA initialization failed', { 
        error: error.message,
        stack: error.stack 
      });
      throw error;
    }
  }

  async _loadIdemixIssuerKeys() {
    try {
      logger.info('Loading Idemix Issuer Keys from CA directory...');
      
      // Build path from environment variables
      const caBasePath = path.join(
        '/app/infrastructure',
        process.env.FABRIC_ORBIS_NAME,
        process.env.FABRIC_REGNUM_NAME,
        process.env.FABRIC_AGER_NAME,
        process.env.FABRIC_CA_NAME
      );
      
      const issuerPublicKeyPath = path.join(caBasePath, 'IssuerPublicKey');
      const issuerRevocationPublicKeyPath = path.join(caBasePath, 'IssuerRevocationPublicKey');

      logger.info('Looking for Idemix keys', {
        caBasePath,
        issuerPublicKeyPath,
        issuerRevocationPublicKeyPath
      });

      if (fs.existsSync(issuerPublicKeyPath) && fs.existsSync(issuerRevocationPublicKeyPath)) {
        const issuerPublicKey = fs.readFileSync(issuerPublicKeyPath, 'utf8');
        const issuerRevocationPublicKey = fs.readFileSync(issuerRevocationPublicKeyPath, 'utf8');
        
        logger.info('✅ Loaded Idemix Issuer Keys successfully', {
          issuerPublicKeyLength: issuerPublicKey.length,
          issuerRevocationPublicKeyLength: issuerRevocationPublicKey.length
        });
        
        return { issuerPublicKey, issuerRevocationPublicKey };
      }

      logger.warn('⚠️  Idemix keys not found at expected paths', {
        issuerPublicKeyPath,
        issuerRevocationPublicKeyPath,
        issuerPublicKeyExists: fs.existsSync(issuerPublicKeyPath),
        issuerRevocationPublicKeyExists: fs.existsSync(issuerRevocationPublicKeyPath)
      });
    
      return { issuerPublicKey: null, issuerRevocationPublicKey: null };
      
    } catch (error) {
      logger.error('Failed to load Idemix Issuer Keys', { 
        error: error.message,
        stack: error.stack 
      });

      return { issuerPublicKey: null, issuerRevocationPublicKey: null };
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
      gensName,  // NEW: Parent Gens name (for Human)
      role      // NEW: User role
    } = enrollmentData;
    
    try {
      logger.info('Enrolling user', { username, enrollmentType, role, gensName });
      
      if (enrollmentType === 'idemix') {
        return await this._enrollIdemix(username, secret, idemixCurve, gensName, role);
      } else {
        return await this._enrollX509(username, secret, role);
      }
      
    } catch (error) {
      logger.error('User enrollment failed', { 
        error: error.message,
        username 
      });
      throw error;
    }
  }
  
  async _enrollX509(username, secret, role) {
    const tempMspDir = `/tmp/x509-${username}-${Date.now()}`;
    
    try {
      // Build CSR options
      const orbisName = process.env.FABRIC_ORBIS_NAME || 'jedo';
      const regnumName = process.env.FABRIC_REGNUM_NAME || 'ea';
      const agerName = process.env.FABRIC_AGER_NAME || 'alps';
      const nodeEnv = process.env.NODE_ENV || 'dev';
      const caName = process.env.FABRIC_CA_NAME || 'msp.alps.ea.jedo.dev';
      const caSrvName = process.env.SERVICE_NAME || 'ca.via.alps.ea.jedo.dev';    

      // Build hosts list similar to CLI: $AGER_MSP_NAME,$AGER_CAAPI_NAME,$AGER_CAAPI_IP,*.$ORBIS.$ORBIS_ENV
      const csrHosts = [
        caName,
        caSrvName,
        `*.${orbisName}.${nodeEnv}`
      ].join(',');
      
      // Build CSR names (Subject fields)
      const csrNames = `C=jd,ST=${nodeEnv},L=${regnumName},O=${agerName}`;

      // Build CSR CN (Subject fields)
      const csrCn = `${username}.${agerName}.${regnumName}.${orbisName}.${nodeEnv}`;

      // Build attribute requests (comma-separated for CLI)
      // Format: attrname:opt for optional, attrname for required
      const attrReqs = [
        'role',
        'hf.Registrar.Roles:opt',
        'hf.Registrar.Attributes:opt',
        'hf.Revoker:opt',
        'hf.EnrollmentID:opt',
        'hf.Type:opt',
        'hf.Affiliation:opt'
      ].join(',');
      
      logger.info('Enrollment with attr_reqs', { 
        username,
        role,
        csrCn,
        csrHosts,
        csrNames,
        attrReqs
      });
      
      // Ensure temp directory exists
      fs.mkdirSync(tempMspDir, { recursive: true });
      
      // Build CLI command with CSR parameters and attr requests
      const caUrl = process.env.FABRIC_CA_URL.replace('https://', '');
      const command = `/usr/local/bin/fabric-ca-client enroll \
        -u https://${username}:${secret}@${caUrl} \
        --caname ${process.env.FABRIC_CA_NAME} \
        --tls.certfiles ${process.env.FABRIC_CA_TLS_CERT_PATH} \
        --mspdir ${tempMspDir} \
        --csr.cn "${csrCn}" \
        --csr.hosts "${csrHosts}" \
        --csr.names "${csrNames}" \
        --enrollment.attrs "${attrReqs}"`;

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

      // Read generated credentials
      const signcertsDir = path.join(tempMspDir, 'signcerts');
      const keystoreDir = path.join(tempMspDir, 'keystore');
      const cacertsDir = path.join(tempMspDir, 'cacerts');
      
      // Find files (fabric-ca-client creates files with cert names)
      const certFiles = fs.readdirSync(signcertsDir);
      const keyFiles = fs.readdirSync(keystoreDir);
      
      if (certFiles.length === 0 || keyFiles.length === 0) {
        throw new Error('No certificate or key generated');
      }
      
      const certificate = fs.readFileSync(path.join(signcertsDir, certFiles[0]), 'utf8');
      const privateKey = fs.readFileSync(path.join(keystoreDir, keyFiles[0]), 'utf8');
      
      // Read root certificate if exists
      let rootCertificate = null;
      if (fs.existsSync(cacertsDir)) {
        const caFiles = fs.readdirSync(cacertsDir);
        if (caFiles.length > 0) {
          rootCertificate = fs.readFileSync(path.join(cacertsDir, caFiles[0]), 'utf8');
        }
      }

      if (!role) {
        logger.error('Role not provided for X.509 enrollment', { username });
        throw new Error('Role is required for crypto material storage');
      }

      // Save to disk
      await this._saveCryptoMaterial({
        username,
        certificate,
        privateKey,
        rootCertificate,
        enrollmentType: 'x509',
        role: role
      });

      // Cleanup temp directory
      fs.rmSync(tempMspDir, { recursive: true, force: true });
      
      logger.info('✅ X.509 enrollment successful via CLI', { 
        username, 
        role,
        hasCertificate: !!certificate,
        hasPrivateKey: !!privateKey,
        hasRootCert: !!rootCertificate
      });

      return {
          certificate,
          privateKey,
          rootCertificate
        };

    } catch (error) {
      logger.error('X.509 enrollment via CLI failed', {
        error: error.message,
        stderr: error.stderr?.toString(),
        stdout: error.stdout?.toString(),
        username,
        role
      });

      // Cleanup on error
      try {
        if (fs.existsSync(tempMspDir)) {
          fs.rmSync(tempMspDir, { recursive: true, force: true });
        }
      } catch (cleanupError) {
        logger.error('Cleanup failed', { error: cleanupError.message });
      }
      
      throw new Error(`X.509 enrollment failed: ${error.message}`);
    }
  }




  /**
   * Idemix Enrollment via CLI
   * TODO: Switch to SDK when fabric-ca-client npm package supports Idemix
   */
  async _enrollIdemix(username, secret, curve, gensName, role) {
    const tempMspDir = `/tmp/idemix-${username}-${Date.now()}`;
    
    try {
        // Build CSR options
        const orbisName = process.env.FABRIC_ORBIS_NAME || 'jedo';
        const regnumName = process.env.FABRIC_REGNUM_NAME || 'ea';
        const agerName = process.env.FABRIC_AGER_NAME || 'alps';
        const nodeEnv = process.env.NODE_ENV || 'dev';
        const caName = process.env.FABRIC_CA_NAME || 'msp.alps.ea.jedo.dev';
        const caSrvName = process.env.SERVICE_NAME || 'ca.via.alps.ea.jedo.dev';    

        // Build hosts list similar to CLI: $AGER_MSP_NAME,$AGER_CAAPI_NAME,$AGER_CAAPI_IP,*.$ORBIS.$ORBIS_ENV
        const csrHosts = [
          caName,
          caSrvName,
          `*.${orbisName}.${nodeEnv}`,
        ];
        
        // Build CSR names (Subject fields)
        const csrNames = `C=jd,ST=${nodeEnv},L=${regnumName},O=${agerName}`;

        // Build CSR CN (Subject fields)
        const csrCn = `${username}.${agerName}.${regnumName}.${orbisName}.${nodeEnv}`;

      logger.info('Starting Idemix enrollment via CLI', { 
        username, 
        curve, 
        gensName, 
        role,
        csrCn,
        csrHosts,
        csrNames
      });
      
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
        --idemix.curve ${curve} \
        --csr.cn "${csrCn}" \
        --csr.hosts "${csrHosts}" \
        --csr.names "${csrNames}"`;

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
     
      if (!fs.existsSync(signerConfigPath)) {
        throw new Error(`SignerConfig not found at ${signerConfigPath}`);
      }
      
      const signerConfig = fs.readFileSync(signerConfigPath, 'utf8');
      const issuerPublicKey = this.idemixIssuerKeys?.issuerPublicKey || null;
      const issuerRevocationPublicKey = this.idemixIssuerKeys?.issuerRevocationPublicKey || null;

        if (!role) {
        logger.error('Role not provided for Idemix enrollment', { username });
        throw new Error('Role is required for crypto material storage');
      }

      if (!gensName) {
        logger.error('GensName not provided for Idemix enrollment', { username });
        throw new Error('GensName is required for Human crypto material storage');
      }

      // Save to disk with gensName and role
      await this._saveCryptoMaterial({
        username,
        signerConfig,
        issuerPublicKey,
        issuerRevocationPublicKey,
        curve,
        enrollmentType: 'idemix',
        gensName,
        role: role
      });
    
      // Cleanup temp directory
      fs.rmSync(tempMspDir, { recursive: true, force: true });
      
      logger.info('✅ Idemix enrollment successful via CLI', { 
        username,
        gensName,
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
        username,
        gensName
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

  /**
   * Save crypto material to disk according to hierarchy
   * Path structure:
   * - Gens (X.509)  : $CRYPTO_PATH/$ORBIS/$REGNUM/$AGER/$GENS_NAME/msp/
   * - Human (Idemix): $CRYPTO_PATH/$ORBIS/$REGNUM/$AGER/$GENS_NAME/$HUMAN_NAME/idemix/
   */
  async _saveCryptoMaterial(data) {
    const { username, enrollmentType, role, gensName } = data;
    
    const cryptoPath = process.env.CRYPTO_PATH;
    let targetDir;
    
    if (!cryptoPath) {
      logger.warn('CRYPTO_PATH not set, skipping crypto material storage');
      return;
    }
    
    try {
      
      if (role === 'gens' && enrollmentType === 'x509') {
        // Gens: $CRYPTO_PATH/$ORBIS/$REGNUM/$AGER/$GENS_NAME/msp/
        targetDir = path.join(
          cryptoPath,
          username,
          'msp'
        );
        
        // Create subdirs
        const signcertsDir = path.join(targetDir, 'signcerts');
        const keystoreDir = path.join(targetDir, 'keystore');
        const cacertsDir = path.join(targetDir, 'cacerts');
        
        fs.mkdirSync(signcertsDir, { recursive: true });
        fs.mkdirSync(keystoreDir, { recursive: true });
        fs.mkdirSync(cacertsDir, { recursive: true });
        
        // Write certificate
        fs.writeFileSync(
          path.join(signcertsDir, 'cert.pem'),
          data.certificate
        );
        
        // Write private key
        const keyFilename = `${username}_sk`;
        fs.writeFileSync(
          path.join(keystoreDir, keyFilename),
          data.privateKey
        );
        
        // Write CA cert
        if (data.rootCertificate) {
          fs.writeFileSync(
            path.join(cacertsDir, 'ca-cert.pem'),
            data.rootCertificate
          );
        }
        
        logger.info('Gens crypto material saved', { 
          username, 
          path: targetDir 
        });
        
      } else if (role === 'human' && enrollmentType === 'idemix') {
        // Human: Need to find parent Gens from certificate
        // This requires reading the registrar certificate that was used
        // For now, we'll extract from request context or env
        
        if (!gensName) {
          throw new Error(`Cannot save Human crypto: gensName not provided for ${username}`);
        }
        
        targetDir = path.join(
          cryptoPath,
          gensName,
          username
        );
        
        // Fabric-compatible structure
        const mspDir = path.join(targetDir, 'msp');
        const userDir = path.join(mspDir, 'user');

        fs.mkdirSync(userDir, { recursive: true });
        fs.mkdirSync(mspDir, { recursive: true });

        // Write Idemix credentials
        fs.writeFileSync(
          path.join(userDir, 'SignerConfig'),
          data.signerConfig
        );
        
        if (data.issuerPublicKey) {
          fs.writeFileSync(
            path.join(mspDir, 'IssuerPublicKey'),
            data.issuerPublicKey
          );
        }
        
        if (data.issuerRevocationPublicKey) {
          fs.writeFileSync(
            path.join(mspDir, 'IssuerRevocationPublicKey'),
            data.issuerRevocationPublicKey
          );
        }
        
        logger.info('Human crypto material saved', { 
          username, 
          gensName,
          path: targetDir 
        });
        
      } else {
        logger.warn('Unknown role or enrollment type, skipping storage', {
          username,
          role,
          enrollmentType,
          gensName
        });
      }
      
    } catch (error) {
      logger.error('Failed to save crypto material', {
        error: error.message,
        stack: error.stack,
        username,
        enrollmentType,
        role,
        gensName,
        cryptoPath: process.env.CRYPTO_PATH,
        targetDir
      });
      // Don't throw - enrollment was successful, storage is optional
    }
  }
}

module.exports = new CertificateService();
