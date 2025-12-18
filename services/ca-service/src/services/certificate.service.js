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
      await this._enrollBootstrapAdminCLI();

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

  /**
   * Enroll bootstrap admin via CLI to create msp-bootstrap directory
   * This is needed for affiliation management and other admin operations
   * @private
   */
  async _enrollBootstrapAdminCLI() {
    try {
      const adminUsername = process.env.FABRIC_CA_ADMIN_USER;
      const adminPass = process.env.FABRIC_CA_ADMIN_PASS;
      const caUrl = process.env.FABRIC_CA_URL.replace('https://', '');
      const caName = process.env.FABRIC_CA_NAME;
      const tlsCertPath = process.env.FABRIC_CA_TLS_CERT_PATH;
      
      // Build msp-bootstrap path
      const caBasePath = path.join(
        '/app/infrastructure',
        process.env.FABRIC_ORBIS_NAME,
        process.env.FABRIC_REGNUM_NAME,
        process.env.FABRIC_AGER_NAME,
        process.env.FABRIC_CA_NAME
      );
      const mspBootstrapDir = path.join(caBasePath, 'msp-bootstrap');
      
      // Check if already enrolled
      const signcertsDir = path.join(mspBootstrapDir, 'signcerts');
      if (fs.existsSync(signcertsDir) && fs.readdirSync(signcertsDir).length > 0) {
        logger.info('Bootstrap admin CLI credentials already exist', { mspBootstrapDir });
        return;
      }
      
      logger.info('Enrolling bootstrap admin via CLI for msp-bootstrap', { 
        adminUsername,
        mspBootstrapDir 
      });
      
      // Ensure directory exists
      fs.mkdirSync(mspBootstrapDir, { recursive: true });
      
      const command = `fabric-ca-client enroll \
        -u https://${adminUsername}:${adminPass}@${caUrl} \
        --caname ${caName} \
        --tls.certfiles ${tlsCertPath} \
        --mspdir ${mspBootstrapDir}`;
      
      logger.debug('Executing bootstrap admin enroll CLI', { 
        command: command.replace(adminPass, '***')
      });
      
      execSync(command, { 
        encoding: 'utf8', 
        stdio: 'pipe',
        env: {
          ...process.env,
          PATH: '/usr/local/bin:/usr/bin:/bin'
        }
      });
      
      logger.info('Bootstrap admin CLI enrollment successful', { mspBootstrapDir });
      
      // Verify enrollment
      if (!fs.existsSync(signcertsDir) || fs.readdirSync(signcertsDir).length === 0) {
        throw new Error('Bootstrap admin enrollment failed: no certificate generated');
      }
      
    } catch (error) {
      logger.error('Failed to enroll bootstrap admin via CLI', { 
        error: error.message,
        stderr: error.stderr?.toString()
      });
      throw new Error(`Bootstrap admin CLI enroll failed: ${error.message}`);
    }
  }

  /**
   * Register Gens identity with affiliation creation
   * Uses Ager Admin (bootstrap) as registrar
   */
  async registerGens(gensData) {
    const { username, secret, affiliation, attrs = {} } = gensData;
    
    try {
      logger.info('Registering Gens', { username, affiliation });
      
      // Step 1: Add affiliation if not exists
      await this._addAffiliationCLI(affiliation);
      
      // Step 2: Register Gens via CLI with Ager-Admin as Registrar
      await this._registerViaCLI({
        username,
        secret,
        affiliation,
        registrarUser: process.env.FABRIC_CA_ADMIN_USER,
        registrarPass: process.env.FABRIC_CA_ADMIN_PASS,
        mspdir: null, // Use default bootstrap msp
        attrs: [
          'role=gens:ecert',
          'hf.Registrar.Roles=client',
          'hf.Registrar.Attributes=role',
          'hf.Revoker=true'
        ]
      });
      
      logger.info('Gens registered successfully', { username, affiliation });
      return { username, secret };
      
    } catch (error) {
      logger.error('Gens registration failed', { 
        error: error.message,
        username,
        affiliation 
      });
      throw error;
    }
  }

  /**
   * Register Human identity under Gens affiliation
   * Uses Gens as registrar (requires Gens credentials)
   */
  async registerHuman(humanData) {
    const { 
      username, 
      secret, 
      affiliation, 
      gensUsername, 
      gensPassword 
    } = humanData;
    
    const tempMspDir = `/tmp/gens-admin-${Date.now()}`;
    
    try {
      logger.info('Registering Human', { 
        username, 
        affiliation, 
        registrar: gensUsername 
      });
      
      // Step 1: Enroll Gens temporarily for admin operation
      await this._enrollGensForAdmin(gensUsername, gensPassword, tempMspDir);
      
      // Step 2: Register Human via CLI with Gens as Registrar
      await this._registerViaCLI({
        username,
        secret,
        affiliation,
        registrarUser: gensUsername,
        registrarPass: gensPassword,
        mspdir: tempMspDir,
        attrs: [
          'role=human:ecert'
        ]
      });
      
      logger.info('Human registered successfully', { 
        username, 
        affiliation,
        registrar: gensUsername 
      });
      
      return { username, secret };
      
    } catch (error) {
      logger.error('Human registration failed', { 
        error: error.message,
        username,
        registrar: gensUsername 
      });
      throw error;
    } finally {
      // Cleanup temp msp directory
      try {
        if (fs.existsSync(tempMspDir)) {
          fs.rmSync(tempMspDir, { recursive: true, force: true });
          logger.debug('Temp MSP directory cleaned up', { tempMspDir });
        }
      } catch (cleanupError) {
        logger.warn('Failed to cleanup temp MSP directory', { 
          error: cleanupError.message,
          tempMspDir 
        });
      }
    }
  }

  /**
   * Add affiliation to CA via CLI
   * Uses Ager Admin (bootstrap) credentials
   * @private
   */
  async _addAffiliationCLI(affiliation) {
    try {
      logger.info('Adding affiliation to CA', { affiliation });
      
      const caUrl = process.env.FABRIC_CA_URL.replace('https://', '');
      const adminUser = process.env.FABRIC_CA_ADMIN_USER;
      const adminPass = process.env.FABRIC_CA_ADMIN_PASS;
      const caName = process.env.FABRIC_CA_NAME;
      const tlsCertPath = process.env.FABRIC_CA_TLS_CERT_PATH;
      
      // Build CA MSP directory path for bootstrap admin
      const caBasePath = path.join(
        '/app/infrastructure',
        process.env.FABRIC_ORBIS_NAME,
        process.env.FABRIC_REGNUM_NAME,
        process.env.FABRIC_AGER_NAME,
        process.env.FABRIC_CA_NAME
      );
      const mspBootstrapDir = path.join(caBasePath, 'msp-bootstrap');
      
      // VERIFY msp-bootstrap exists
      if (!fs.existsSync(mspBootstrapDir)) {
        throw new Error(`msp-bootstrap directory not found: ${mspBootstrapDir}. Run _enrollBootstrapAdminCLI() first.`);
      }
      
      // Verify signcerts exist
      const signcertsDir = path.join(mspBootstrapDir, 'signcerts');
      if (!fs.existsSync(signcertsDir) || fs.readdirSync(signcertsDir).length === 0) {
        throw new Error(`Bootstrap admin not enrolled: ${signcertsDir}. Run _enrollBootstrapAdminCLI() first.`);
      }
      
      logger.debug('Using msp-bootstrap for affiliation add', { 
        mspBootstrapDir,
        signcertsExists: fs.existsSync(signcertsDir)
      });
    
      const command = `fabric-ca-client affiliation add ${affiliation} \
        -u https://${adminUser}:${adminPass}@${caUrl} \
        --caname ${caName} \
        --tls.certfiles ${tlsCertPath} \
        --mspdir ${mspBootstrapDir}`;
      
      logger.debug('Executing affiliation add CLI', { 
        affiliation,
        command: command.replace(adminPass, '***') 
      });
      
      execSync(command, { 
        encoding: 'utf8', 
        stdio: 'pipe',
        env: {
          ...process.env,
          PATH: '/usr/local/bin:/usr/bin:/bin'
        }
      });
      
      logger.info('Affiliation added successfully', { affiliation });
      
    } catch (error) {
      // Check if affiliation already exists (not an error)
      if (error.message && error.message.includes('Affiliation already exists')) {
        logger.warn('Affiliation already exists', { affiliation });
        return;
      }
      
      logger.error('Failed to add affiliation', { 
        error: error.message,
        stderr: error.stderr?.toString(),
        affiliation 
      });
      throw new Error(`Affiliation add failed: ${error.message}`);
    }
  }

  /**
   * Generic CLI-based registration
   * @private
   */
  async _registerViaCLI(options) {
    const { 
      username, 
      secret, 
      affiliation, 
      registrarUser, 
      registrarPass,
      mspdir,
      attrs = [] 
    } = options;
    
    try {
      logger.debug('Registering user via CLI', { 
        username, 
        affiliation,
        registrar: registrarUser 
      });
      
      const caUrl = process.env.FABRIC_CA_URL.replace('https://', '');
      const caName = process.env.FABRIC_CA_NAME;
      const tlsCertPath = process.env.FABRIC_CA_TLS_CERT_PATH;
      
      // Determine MSP directory
      let mspDirectory;
      if (mspdir) {
        // Use provided temp directory (for Human with Gens registrar)
        mspDirectory = mspdir;
      } else {
        // Use bootstrap directory (for Gens with Ager registrar)
        const caBasePath = path.join(
          '/app/infrastructure',
          process.env.FABRIC_ORBIS_NAME,
          process.env.FABRIC_REGNUM_NAME,
          process.env.FABRIC_AGER_NAME,
          process.env.FABRIC_CA_NAME
        );
        mspDirectory = path.join(caBasePath, 'msp-bootstrap');
      }
      
      // Build attributes string for CLI
      const attrsString = attrs.map(attr => `"${attr}"`).join(',');
      
      const command = `fabric-ca-client register \
        -u https://${registrarUser}:${registrarPass}@${caUrl} \
        --caname ${caName} \
        --tls.certfiles ${tlsCertPath} \
        --mspdir ${mspDirectory} \
        --id.name ${username} \
        --id.secret ${secret} \
        --id.type client \
        --id.affiliation ${affiliation} \
        ${attrsString ? `--id.attrs '${attrsString}'` : ''}`;
      
      logger.debug('Executing register CLI', { 
        username,
        command: command.replace(registrarPass, '***').replace(secret, '***')
      });
      
      const output = execSync(command, { 
        encoding: 'utf8', 
        stdio: 'pipe',
        env: {
          ...process.env,
          PATH: '/usr/local/bin:/usr/bin:/bin'
        }
      });
      
      logger.debug('Registration CLI completed', { username, output });
      
    } catch (error) {
      logger.error('CLI registration failed', { 
        error: error.message,
        stderr: error.stderr?.toString(),
        stdout: error.stdout?.toString(),
        username 
      });
      throw new Error(`Registration failed: ${error.message}`);
    }
  }

  /**
   * Temporarily enroll Gens for admin operations (Human registration)
   * Creates msp-bootstrap directory for Gens
   * @private
   */
  async _enrollGensForAdmin(gensUsername, gensPassword, tempMspDir) {
    try {
      logger.debug('Enrolling Gens for admin operation', { 
        gensUsername,
        tempMspDir 
      });
      
      const caUrl = process.env.FABRIC_CA_URL.replace('https://', '');
      const caName = process.env.FABRIC_CA_NAME;
      const tlsCertPath = process.env.FABRIC_CA_TLS_CERT_PATH;
      
      // Ensure temp directory exists
      fs.mkdirSync(tempMspDir, { recursive: true });
      
      const command = `fabric-ca-client enroll \
        -u https://${gensUsername}:${gensPassword}@${caUrl} \
        --caname ${caName} \
        --tls.certfiles ${tlsCertPath} \
        --mspdir ${tempMspDir}`;
      
      logger.debug('Executing Gens admin enroll CLI', { 
        gensUsername,
        command: command.replace(gensPassword, '***')
      });
      
      execSync(command, { 
        encoding: 'utf8', 
        stdio: 'pipe',
        env: {
          ...process.env,
          PATH: '/usr/local/bin:/usr/bin:/bin'
        }
      });
      
      logger.debug('Gens admin enrollment successful', { 
        gensUsername,
        tempMspDir 
      });
      
    } catch (error) {
      logger.error('Gens admin enrollment failed', { 
        error: error.message,
        stderr: error.stderr?.toString(),
        gensUsername 
      });
      throw new Error(`Gens admin enroll failed: ${error.message}`);
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
