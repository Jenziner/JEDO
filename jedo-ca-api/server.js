const express = require('express');
const cors = require('cors');
const fs = require('fs');
const yaml = require('yaml');
const FabricCAServices = require('fabric-ca-client');
const { Wallets, X509Identity } = require('fabric-network');
const { User } = require('fabric-common');
const path = require('path');
const archiver = require('archiver');
const { createReadStream, createWriteStream } = require('fs');
const app = express();

app.use(cors());
app.use(express.json());

// Lade Konfigurationen aus der YAML-Datei
const config = yaml.parse(fs.readFileSync('/app/config/jedo-ca-api-config.yaml', 'utf8'));

// Dynamisch den Dateinamen des CA-Zertifikats im Verzeichnis /app/admin/cacerts ermitteln
const caCertDir = '/app/admin/cacerts';
const caCertFile = fs.readdirSync(caCertDir).find(file => file.endsWith('.pem'));
const tlsCertPath = path.join(caCertDir, caCertFile);

// TLS-Optionen für die CA-Verbindung mit Zertifikatsprüfung
const tlsOptions = {
  trustedRoots: [fs.readFileSync(tlsCertPath)],
  verify: false // Falls du später auf true umstellen möchtest
};

// Setze den CA-Service mit den neuen TLS-Optionen
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
      csrHosts: [`tls.${config.ca_name}`]
    });

    // Speichern in das MSP-Verzeichnis
    const userMspDir = path.join(config.keys_dir, config.channel, config.organization, 'wallet', username, 'msp');
    const signcertsDir = path.join(userMspDir, 'signcerts');
    const keystoreDir = path.join(userMspDir, 'keystore');

    fs.mkdirSync(signcertsDir, { recursive: true });
    fs.mkdirSync(keystoreDir, { recursive: true });

    fs.writeFileSync(path.join(signcertsDir, 'cert.pem'), enrollment.certificate);
    fs.writeFileSync(path.join(keystoreDir, 'key.pem'), enrollment.key.toBytes());

    console.log(`Successfully enrolled user: ${username}`);
    return { message: `Enrollment successful for ${username}`, output: enrollment.certificate, signcertsDir, keystoreDir };
  } catch (error) {
    console.error(`Error during enrollment: ${error}`);
    throw { message: "Enrollment failed", details: error.message };
  }
};

// POST Endpoint für die Registrierung
app.post('/register', async (req, res) => {
  const { username, password, affiliation } = req.body;
  try {
    const result = await registerUser(username, password, affiliation);
    res.status(200).send(result);
  } catch (error) {
    console.error("Error during registration:", error);
    res.status(500).send({ error });
  }
});

// POST Endpoint für Enrollment
app.post('/enroll', async (req, res) => {
  const { username, password } = req.body;
  try {
    const { signcertsDir, keystoreDir } = await enrollUser(username, password);

    // Erstelle die Zip-Datei mit Zertifikaten und Schlüssel
    const zipFilePath = `/tmp/${username}_certs.zip`;
    const output = createWriteStream(zipFilePath);
    const archive = archiver('zip', { zlib: { level: 9 } });
    
    output.on('close', () => {
      // Sende die Zip-Datei als Download
      res.download(zipFilePath, `${username}_certs.zip`, (err) => {
        if (err) {
          console.error("Download error:", err);
          res.status(500).send({ error: "Failed to download certificates." });
        }
      });
    });

    archive.on('error', (err) => {
      throw err;
    });

    archive.pipe(output);
    
    // Füge die Zertifikate und den privaten Schlüssel hinzu
    archive.file(path.join(signcertsDir, 'cert.pem'), { name: 'cert.pem' });
    archive.file(path.join(keystoreDir, 'key.pem'), { name: 'key.pem' });
    archive.finalize();

  } catch (error) {
    console.error("Error during enrollment:", error);
    res.status(500).send({ error: error.message || error.toString() });
  }
});

// Starte den Server auf dem API-Port aus der Konfigurationsdatei
const PORT = config.api_port || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
