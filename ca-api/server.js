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

// Funktion zum Laden der Admin-Identität
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

// Funktion zum Registrieren eines neuen Benutzers
const registerUser = async (username, password, affiliation) => {
  try {
    const adminUser = await loadAdminIdentity();

    await caService.register({
      enrollmentID: username,
      enrollmentSecret: password,
      role: 'client',
      affiliation
    }, adminUser);

    console.log(`Successfully registered user: ${username}`);
    return { message: `Registration successful for ${username}`, output: `Password: ${password}` };
  } catch (error) {
    console.error(`Error during registration: ${error}`);
    throw { message: "Registration failed", details: error.message };
  }
};

// Funktion zum Einschreiben eines Benutzers
const enrollUser = async (username, password) => {
  try {
    const enrollment = await caService.enroll({
      enrollmentID: username,
      enrollmentSecret: password,
      attr_reqs: [{ name: 'hf.Affiliation' }, { name: 'hf.EnrollmentID' }],
      csrHosts: [`${config.ca_name}`]
    });

    // Speichern in das MSP-Verzeichnis
    const userMspDir = path.join(config.keys_dir, config.channel, config.organization, 'wallet', username, 'msp');
    const signcertsDir = path.join(userMspDir, 'signcerts');
    const keystoreDir = path.join(userMspDir, 'keystore');

    fs.mkdirSync(signcertsDir, { recursive: true });
    fs.mkdirSync(keystoreDir, { recursive: true });

    const certPath = path.join(signcertsDir, 'cert.pem');
    const keyPath = path.join(keystoreDir, 'key.pem');

    fs.writeFileSync(certPath, enrollment.certificate);
    fs.writeFileSync(keyPath, enrollment.key.toBytes());
    
    console.log(`Successfully enrolled user: ${username}`);
    console.log(`Enrollment paths: certPath=${certPath}, keyPath=${keyPath}`);

    return { certPath, keyPath };
  } catch (error) {
    console.error(`Error during enrollment: ${error}`);
    throw { message: "Enrollment failed", details: error.message };
  }
};

// GET Endpoint für die Version
app.get('/version', (req, res) => {
  res.status(200).json({
    version: API_VERSION,
    releaseDate: RELEASE_DATE,
    serverName: SERVER_NAME
  });
});

// POST Endpoint für die Registrierung
app.post('/register', async (req, res) => {
  const { username, password } = req.body;
  try {
    // Benutzer registrieren
    const registerResult = await registerUser(username, password, 'org1.department1');
    
    // Benutzer einschreiben und Zertifikate erstellen
    const { certPath, keyPath } = await enrollUser(username, password);

    if (!certPath || !keyPath) {
      throw new Error('Certificate or key file path is missing.');
    }
    // Erstelle ZIP-Datei mit Zertifikaten
    const zipFilePath = `/tmp/${username}_certs.zip`;
    const output = createWriteStream(zipFilePath);
    const archive = archiver('zip', { zlib: { level: 9 } });

    output.on('close', () => {
      res.download(zipFilePath, `${username}_certs.zip`);
    });

    archive.on('error', (err) => {
      throw err;
    });

    archive.pipe(output);
    archive.file(certPath, { name: 'cert.pem' });
    archive.file(keyPath, { name: 'key.pem' });
    archive.finalize();
  } catch (error) {
    res.status(500).send({ error: error.message });
  }
});

// Starte den Server auf dem API-Port aus der Konfigurationsdatei
const PORT = config.api_port || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
