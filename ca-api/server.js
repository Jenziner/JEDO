const express = require('express');
const cors = require('cors');
const fs = require('fs');
const yaml = require('yaml');
const FabricCAServices = require('fabric-ca-client');
const { Wallets } = require('fabric-network');
const path = require('path');
const archiver = require('archiver');
const { createWriteStream } = require('fs');
const app = express();
const { execSync } = require('child_process');
const { Certificate, verify } = require('crypto');

app.use(cors());
app.use(express.json());

// Lade Konfigurationen aus der YAML-Datei
const config = yaml.parse(fs.readFileSync('/app/config/jedo-ca-api-config.yaml', 'utf8'));

// Feste Werte für den Version-Endpoint
const API_VERSION = '1.0.0';  // Version als Konstante
const RELEASE_DATE = '2024-10-20';  // Datum als Konstante
const SERVER_NAME = 'JEDO CA-Server';  // Servername als Konstante

// Dynamisch den Dateinamen des CA-Zertifikats im Verzeichnis /app/admin/cacerts ermitteln
const caCertDir = '/app/admin/cacerts';
const caCertFile = fs.readdirSync(caCertDir).find(file => file.endsWith('.pem'));
const tlsCertPath = path.join(caCertDir, caCertFile);

// TLS-Optionen für die CA-Verbindung mit Zertifikatsprüfung
const tlsOptions = {
  trustedRoots: [fs.readFileSync(tlsCertPath)],
  verify: false
};

// Setze den CA-Service mit den TLS-Optionen
const caService = new FabricCAServices(config.ca_url, tlsOptions);


// //////////////////////////////////////////////
// Funktion zum Laden der Admin-Identität
// //////////////////////////////////////////////
const loadAdminIdentity = async () => {
  const wallet = await Wallets.newFileSystemWallet('/app/adminWallet');
  let adminIdentity = await wallet.get('admin');
  
  if (!adminIdentity) {
    const certPath = path.join('/app/admin', 'signcerts', 'cert.pem');
    const keyDir = path.join('/app/admin', 'keystore');
    const keyFile = fs.readdirSync(keyDir).find(file => file.endsWith('_sk'));
    const certificate = fs.readFileSync(certPath).toString();
    const privateKey = fs.readFileSync(path.join(keyDir, keyFile)).toString();

    adminIdentity = {
      credentials: {
        certificate,
        privateKey
      },
      mspId: config.organization,
      type: 'X.509'
    };
    await wallet.put('admin', adminIdentity);
  }
  
  const identityProvider = wallet.getProviderRegistry().getProvider(adminIdentity.type);
  const adminUser = await identityProvider.getUserContext(adminIdentity, 'admin');
  return adminUser;
};


// //////////////////////////////////////////////
// Funktion zum Auslesen von Zertifikatstext und Bestimmen der Rolle und des Subjects
// //////////////////////////////////////////////
const extractRoleAndSubjectFromCert = (certText) => {
  const command = `echo "${certText}" | openssl x509 -text -noout`;
  const certInfo = execSync(command).toString();
  const roleMatch = certInfo.match(/jedo\.role":"(CA|issuer|owner)"/);
  const subjectMatch = certInfo.match(/Subject: (.*)/);

  if (!roleMatch) {
    throw new Error('Role not found in certificate');
  }
  if (!subjectMatch) {
    throw new Error('Subject not found in certificate');
  }

  const role = roleMatch[1];
  const subject = subjectMatch[1];

  // Subject details extraction (C, ST, L, O, OU)
  const subjectDetails = {};
  const ouList = [];
  const compareList = [];

  subject.split(/, |\s\+\s/).forEach(part => {
    const [key, value] = part.split('=');
    const trimmedKey = key.trim();
    const trimmedValue = value ? value.trim() : '';

    if (trimmedKey === 'OU') {
      ouList.push(trimmedValue);
    } else {
      subjectDetails[trimmedKey] = trimmedValue;
      compareList.push(trimmedValue.toLowerCase());
    }
  });

  // Entferne redundante OU-Einträge und die OU "client"
  const relevantOUList = ouList.filter(ou => {
    return !compareList.includes(ou.toLowerCase()) && ou.toLowerCase() !== 'client';
  });

  // Setze die gefilterte OU, falls vorhanden
  subjectDetails.OU = relevantOUList.length === 1 ? relevantOUList[0] : 'N/A';

  // Berechne die Affiliation
  const { C, ST, L, O } = subjectDetails;
  const affiliation = O && O !== 'N/A' ? `${ST}.jedo.${C}.${L}.${O}` : `${ST}.jedo.${C}.${L}`;

  return { role, subjectDetails, affiliation };
};



// //////////////////////////////////////////////
// Function to add Affiliation
// //////////////////////////////////////////////
async function addAffiliation(affiliation, caService) {
  const adminUser = await loadAdminIdentity();

  try {
    const affiliationService = caService.newAffiliationService();
    
    await affiliationService.create({
      name: affiliation
    }, adminUser);

    console.log(`Affiliation '${affiliation}' added successfully.`);
  } catch (error) {
    console.error(`Failed to add affiliation '${affiliation}':`, error);
  }
}


// //////////////////////////////////////////////
// Function to register FSC-User
// //////////////////////////////////////////////
async function registerFscUser(enrollmentID, enrollmentSecret, role, affiliation, caService, config) {
  const adminUser = await loadAdminIdentity();

  await caService.register({
      enrollmentID: enrollmentID,
      enrollmentSecret: enrollmentSecret,
      role: 'client',
      affiliation: affiliation,
      attrs: [
          { name: 'jedo.apiPort', value: String(config.api_port), type: 'string', ecert: true },
          { name: 'jedo.role', value: role, type: 'string', ecert: true }
      ]
  }, adminUser);
}


// //////////////////////////////////////////////
// Function to register Wallet-User
// //////////////////////////////////////////////
async function registerWalletUser(enrollmentID, enrollmentSecret, role, affiliation, caService, config) {
  const adminUser = await loadAdminIdentity();

  await caService.register({
      enrollmentID: enrollmentID,
      enrollmentSecret: enrollmentSecret,
      role: 'client',
      affiliation: affiliation,
      attrs: [
        { name: 'jedo.apiPort', value: String(config.api_port), type: 'string', ecert: true },
        { name: 'jedo.role', value: role, type: 'string', ecert: true }
    ]
// TODO
// --enrollment.type idemix --idemix.curve gurvy.Bn254
    }, adminUser);
}


// //////////////////////////////////////////////
// Function to enroll User
// //////////////////////////////////////////////
async function enrollUser(enrollmentID, enrollmentSecret, csrPem, caService) {
  const fscEnrollment = await caService.enroll({
      enrollmentID: enrollmentID,
      enrollmentSecret: enrollmentSecret,
      csr: csrPem,
      attr_reqs: [
          { name: 'jedo.apiPort' },
          { name: 'jedo.role' }
      ]
  });

  return fscEnrollment;
}


// //////////////////////////////////////////////
// Function to store certificate and keyfile
// //////////////////////////////////////////////
function storeCert(enrollment, privateKeyPem, mspDir) {
  // Create MSP-Folder-Path
  const signcertsDir = path.join(mspDir, 'signcerts');
  const keystoreDir = path.join(mspDir, 'keystore');

  // Create directories
  fs.mkdirSync(signcertsDir, { recursive: true });
  fs.mkdirSync(keystoreDir, { recursive: true });

  // Store certificate and keyfile
  fs.writeFileSync(path.join(signcertsDir, 'cert.pem'), enrollment.certificate);
  fs.writeFileSync(path.join(keystoreDir, 'key.pem'), privateKeyPem);
}


// //////////////////////////////////////////////
// Function to store certificate and keyfile
// //////////////////////////////////////////////
async function createCertsZip(username, signcertsDir, keystoreDir, res) {
  const zipFilePath = `/tmp/${username}_certs.zip`;
  const output = fs.createWriteStream(zipFilePath);
  const archive = archiver('zip', { zlib: { level: 9 } });

  return new Promise((resolve, reject) => {
      output.on('close', () => {
          // Send Zip as download
          res.download(zipFilePath, `${username}_certs.zip`, (err) => {
              if (err) {
                  console.error("Download error:", err);
                  res.status(500).send({ error: "Failed to download certificates." });
                  reject(err);
              } else {
                  resolve();
              }
          });
      });

      archive.on('error', (err) => {
          reject(err);
      });

      archive.pipe(output);
      archive.file(path.join(signcertsDir, 'cert.pem'), { name: 'cert.pem' });
      archive.file(path.join(keystoreDir, 'key.pem'), { name: 'key.pem' });
      archive.finalize();
  });
}


// //////////////////////////////////////////////
// Funktion zum Erstellen eines Issuer
// //////////////////////////////////////////////
const createIssuer = async (region, username, password, affiliation, subjectDetails, res) => {
  console.log(`${username}: Creating Issuer with affiliation: ${affiliation}`);
  const { generateCsr } = require('./utils');

  try {
    // Generate FSC User
    const fscUsername = `fsc.${username}`;
    await registerFscUser(fscUsername, password, 'issuer', affiliation, caService, config);
    console.log(`${username}: FSC User registered successfully.`);

    // Generate CSR
    const { csrPem: fscCsrPem, privateKeyPem: fscPrivateKeyPem } = await generateCsr({
        cn: fscUsername,
      names: [
        { C: subjectDetails.C },
        { ST: subjectDetails.ST },
        { L: region },
      ],
      altNames: [
        { type: 2, value: config.ca_name }, // type 2: DNS
        { type: 2, value: config.api_name },
        { type: 7, ip: config.api_IP }, // type 7: IP
        { type: 7, ip: config.unraid_IP }        
      ]
    });
    console.log(`${username}: PrivateKeyPem for FSC User generated successfully`);
    
    // Enroll FSC User
    const fscEnrollment = await enrollUser(fscUsername, password, fscCsrPem, caService);
    console.log(`${username}: FSC User enrolled successfully.`);

    // Store FSC User certificates
    const fscMspDir = path.join(
      config.keys_dir, 
      `${subjectDetails.C}.jedo.${subjectDetails.ST}`, 
      `${region}.${subjectDetails.C}.jedo.${subjectDetails.ST}`, 
      '_issuer', 
      `${username}`, 
      'fsc', 
      'msp'
    );
    storeCert(fscEnrollment, fscPrivateKeyPem, fscMspDir);
    console.log(`${username}: Files stored successfully.`);

    // Generate Wallet User
    await registerWalletUser(username, password, 'issuer', affiliation, caService, config);
    console.log(`${username}: Wallet User registered successfully.`);

    // Generate CSR
    const { csrPem: walletCsrPem, privateKeyPem: walletPrivateKeyPem } = await generateCsr({
        cn: username,
      names: [
        { C: subjectDetails.C },
        { ST: subjectDetails.ST },
        { L: region },
      ]
    });
    console.log(`${username}: PrivateKeyPem for Wallet User generated successfully`);
    
    // Enroll Wallet User
    const walletEnrollment = await enrollUser(username, password, walletCsrPem, caService);
    console.log(`${username}: Wallet User enrolled successfully.`);

    // Store Wallet User certificates
    const walletMspDir = path.join(
      config.keys_dir, 
      `${subjectDetails.C}.jedo.${subjectDetails.ST}`, 
      `${region}.${subjectDetails.C}.jedo.${subjectDetails.ST}`, 
      `_issuer`, 
      `${username}`, 
      `wallet`,
      `msp`
    );
    storeCert(walletEnrollment, walletPrivateKeyPem, walletMspDir);
    console.log(`${username}: Files stored successfully.`);

    // Create ZIP with FSC User certificates only
    const signcertsDir = path.join(fscMspDir, 'signcerts');
    const keystoreDir = path.join(fscMspDir, 'keystore');
    await createCertsZip(fscUsername, signcertsDir, keystoreDir, res);
    console.log(`${username}: ZIP created and sent successfully.`);

    console.log(`${username}: Issuer created successfully`);
  
  } catch (error) {
    console.error(`${username}: Error creating Issuer: ${error.message}`);
    console.error('Full error details:', error);
    res.status(500).send({ error: `Failed to create Issuer ${username}: ${error.message}` });
  }
};


// //////////////////////////////////////////////
// Funktion zum Erstellen eines Owner
// //////////////////////////////////////////////
const createOwner = async (username, password, affiliation, subjectDetails, res) => {
  console.log(`${username}: Creating Owner with affiliation: ${affiliation}`);
  const { generateCsr } = require('./utils');

  try {
    // Add affiliation
    addAffiliation(`${affiliation}.${username}`, caService);

    // Generate FSC User
    const fscUsername = `fsc.${username}`;
    await registerFscUser(fscUsername, password, 'owner', affiliation, caService, config);
    console.log(`${username}: FSC User registered successfully.`);

    // Generate CSR
    const { csrPem: fscCsrPem, privateKeyPem: fscPrivateKeyPem } = await generateCsr({
        cn: fscUsername,
      names: [
        { C: subjectDetails.C },
        { ST: subjectDetails.ST },
        { L: subjectDetails.L },
        { O: username },
      ],
      altNames: [
        { type: 2, value: config.ca_name }, // type 2: DNS
        { type: 2, value: config.api_name },
        { type: 7, ip: config.api_IP }, // type 7: IP
        { type: 7, ip: config.unraid_IP }        
      ]
    });
    console.log(`${username}: PrivateKeyPem for FSC User generated successfully`);
    
    // Enroll FSC User
    const fscEnrollment = await enrollUser(fscUsername, password, fscCsrPem, caService);
    console.log(`${username}: FSC User enrolled successfully.`);

    // Store FSC User certificates
    const fscMspDir = path.join(
      config.keys_dir, 
      `${subjectDetails.C}.jedo.${subjectDetails.ST}`, 
      `${subjectDetails.L}.${subjectDetails.C}.jedo.${subjectDetails.ST}`, 
      `_owner`, 
      `${username}`, 
      `fsc`, 
      `msp`
    );
    storeCert(fscEnrollment, fscPrivateKeyPem, fscMspDir);
    console.log(`${username}: Files stored successfully.`);

    // Generate Wallet User
    await registerWalletUser(username, password, 'owner', affiliation, caService, config);
    console.log(`${username}: Wallet User registered successfully.`);

    // Generate CSR
    const { csrPem: walletCsrPem, privateKeyPem: walletPrivateKeyPem } = await generateCsr({
        cn: username,
      names: [
        { C: subjectDetails.C },
        { ST: subjectDetails.ST },
        { L: subjectDetails.L },
        { O: username },
      ]
    });
    console.log(`${username}: PrivateKeyPem for Wallet User generated successfully`);
    
    // Enroll Wallet User
    const walletEnrollment = await enrollUser(username, password, walletCsrPem, caService);
    console.log(`${username}: Wallet User enrolled successfully.`);

    // Store Wallet User certificates
    const walletMspDir = path.join(
      config.keys_dir, 
      `${subjectDetails.C}.jedo.${subjectDetails.ST}`, 
      `${subjectDetails.L}.${subjectDetails.C}.jedo.${subjectDetails.ST}`, 
      `_owner`, 
      `${username}`, 
      `wallet`,
      `msp`
    );
    storeCert(walletEnrollment, walletPrivateKeyPem, walletMspDir);
    console.log(`${username}: Files stored successfully.`);

    // Create ZIP with FSC User certificates only
    const signcertsDir = path.join(fscMspDir, 'signcerts');
    const keystoreDir = path.join(fscMspDir, 'keystore');
    await createCertsZip(fscUsername, signcertsDir, keystoreDir, res);
    console.log(`${username}: ZIP created and sent successfully.`);

    console.log(`${username}: Owner created successfully`);
  
  } catch (error) {
    console.error(`${username}: Error creating Owner: ${error.message}`);
    console.error('Full error details:', error);
    res.status(500).send({ error: `Failed to create Owner ${username}: ${error.message}` });
  }
};


// //////////////////////////////////////////////
// Funktion zum Erstellen eines User
// //////////////////////////////////////////////
const createUser = async (username, password, affiliation, subjectDetails, res) => {
  console.log(`${username}: Creating User with affiliation: ${affiliation}`);
  const { generateCsr } = require('./utils');

  try {
    // Generate Wallet User
    await registerWalletUser(username, password, 'user', affiliation, caService, config);
    console.log(`${username}: Wallet User registered successfully.`);

    // Generate CSR
    const { csrPem: walletCsrPem, privateKeyPem: walletPrivateKeyPem } = await generateCsr({
        cn: username,
      names: [
        { C: subjectDetails.C },
        { ST: subjectDetails.ST },
        { L: subjectDetails.L },
        { O: subjectDetails.O }
      ]
    });
    console.log(`${username}: PrivateKeyPem for Wallet User generated successfully`);
    
    // Enroll Wallet User
    const walletEnrollment = await enrollUser(username, password, walletCsrPem, caService);
    console.log(`${username}: Wallet User enrolled successfully.`);

    // Store Wallet User certificates
    const walletMspDir = path.join(
      config.keys_dir, 
      `${subjectDetails.C}.jedo.${subjectDetails.ST}`, 
      `${subjectDetails.L}.${subjectDetails.C}.jedo.${subjectDetails.ST}`,
      `_owner`,
      `${subjectDetails.O}`, 
      `_user`, 
      `${username}`, 
      `msp`
    );
    storeCert(walletEnrollment, walletPrivateKeyPem, walletMspDir);
    console.log(`${username}: Files stored successfully.`);

    // Create ZIP with FSC User certificates only
    const signcertsDir = path.join(walletMspDir, 'signcerts');
    const keystoreDir = path.join(walletMspDir, 'keystore');
    await createCertsZip(username, signcertsDir, keystoreDir, res);
    console.log(`${username}: ZIP created and sent successfully.`);

    console.log(`${username}: User created successfully`);
  
  } catch (error) {
    console.error(`${username}: Error creating User: ${error.message}`);
    console.error('Full error details:', error);
    res.status(500).send({ error: `Failed to create User ${username}: ${error.message}` });
  }
};



// //////////////////////////////////////////////
// GET Endpoint für die Version
// //////////////////////////////////////////////
app.get('/version', (req, res) => {
  res.status(200).json({
    version: API_VERSION,
    releaseDate: RELEASE_DATE,
    serverName: SERVER_NAME
  });
});


// //////////////////////////////////////////////
// POST Endpoint für die Registrierung
// //////////////////////////////////////////////
app.post('/register', async (req, res) => {
  const { region, username, password, certText } = req.body;
  try {
    // Extrahiere die Rolle und den Subject aus dem Zertifikat
    const { role, subjectDetails, affiliation } = extractRoleAndSubjectFromCert(certText);

    // Registriere Benutzer je nach Rolle
    if (role === 'CA') {
      await createIssuer(region, username, password, affiliation, subjectDetails, res);
    } else if (role === 'issuer') {
      await createOwner(username, password, affiliation, subjectDetails, res);
    } else if (role === 'owner') {
      await createUser(username, password, affiliation, subjectDetails, res);
    }

  } catch (error) {
    console.error(`Error in /register endpoint: ${error.message}`);
    res.status(500).send({ error: error.message });
  }
});


// //////////////////////////////////////////////
// Starte den Server auf dem API-Port aus der Konfigurationsdatei
// //////////////////////////////////////////////
const PORT = config.api_port || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
