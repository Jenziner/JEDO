/**
 * Beispiel-Code: Einmaliges Enrollment + Wallet.
 * - Prüft, ob "admin" (o. ä.) schon in der Wallet liegt.
 * - Wenn nein, enrollt er beim CA + speichert Identity in der Wallet.
 * - Wenn ja, nutzt er die vorhandene Identity zum Abfragen der Affiliations.
 */

const fs = require('fs');
const path = require('path');
const express = require('express');
const bodyParser = require('body-parser');

// Fabric-spezifische Imports
const FabricCAServices = require('fabric-ca-client');
const { Wallets } = require('fabric-network');
const { User } = require('fabric-common');

/** 
 * 1) TLS-Root-Zertifikat fürs CA (Transport-Sicherheit)
 */
const caCertPath = path.join('/etc/hyperledger/infrastructure/temp', 'tls-cacert.pem');
const caCert = fs.readFileSync(caCertPath);

// 2) CA-Infos (URL, Name, TLS-Optionen)
const caURL = 'https://ca.alps.ea.jedo.dev:53041';
const caName = 'ca.alps.ea.jedo.dev';
const caTLSOptions = {
  trustedRoots: [caCert],
  verify: true
};

// 3) Admin-Creds (Enrollment ID/Secret) für einmalige Registrierung
//    Achtung: In Produktion nie im Klartext ablegen!
const enrollmentID = 'ca.alps.ea.jedo.dev';
const enrollmentSecret = 'Test1';

// 4) MSP-ID (z. B. 'Org1MSP' oder hier 'jedo')
const mspId = 'jedo';

// 5) Wallet anlegen (Dateisystem). 
//    Pfad relativ oder absolut, je nach Umgebung.
const walletPath = path.join(__dirname, 'wallet'); // z.B. ./wallet
let wallet;

/**
 * Einmaliges Enrollment, falls Identity "admin" noch nicht in der Wallet liegt.
 */
async function enrollAdminIfNeeded() {
  // Wallet initialisieren
  wallet = await Wallets.newFileSystemWallet(walletPath);

  // Prüfen, ob "admin" schon existert
  const adminIdentity = await wallet.get('ca.alps.ea.jedo.dev');
  if (adminIdentity) {
    console.log('Admin-Identity bereits in der Wallet. Enrollment wird übersprungen.');
    return; 
  }

  console.log('Keine admin-Identity in Wallet gefunden. Führe einmaliges Enrollment durch ...');

  // Fabric-CA-Client instanziieren
  const ca = new FabricCAServices(caURL, caTLSOptions, caName);

  // Enrollment durchführen
  const enrollment = await ca.enroll({
    enrollmentID,
    enrollmentSecret,
    csr: { key: { algo: 'ecdsa', size: 384 } }
  });

  // Identity-Objekt für die Wallet vorbereiten
  const x509Identity = {
    credentials: {
      certificate: enrollment.certificate,
      privateKey: enrollment.key.toBytes()  // -> PEM-String
    },
    mspId: mspId,
    type: 'X.509'
  };

  // In die Wallet legen
  await wallet.put('admin', x509Identity);
  console.log('Admin-Identity erfolgreich in der Wallet gespeichert.');
}

/**
 * Affiliations abrufen mit der "admin"-Identity aus der Wallet
 */
async function getAffiliations() {
  try {
    // Wallet laden (falls nicht schon passiert)
    if (!wallet) {
      wallet = await Wallets.newFileSystemWallet(walletPath);
    }

    // Identity aus der Wallet holen
    const adminIdentity = await wallet.get('admin');
    if (!adminIdentity) {
      throw new Error('Keine admin-Identity in der Wallet gefunden. Bitte zuerst enrollen.');
    }

    // Fabric-CA-Client
    const ca = new FabricCAServices(caURL, caTLSOptions, caName);

    // CryptoSuite anlegen (hier, falls ES256 Standard ausreicht):
    // Falls du ES384 willst, versuche:
    //    const cryptoSuite = FabricCAServices.newCryptoSuite({ keySize: 384 });
    //const cryptoSuite = ca.newCryptoSuite();
    const cryptoSuite = FabricCAServices.newCryptoSuite({
        software: true,
        keySize: 384 // oder 384, wenn du ES384 willst
      });

    // User-Objekt erstellen und mit Key+Cert aus der Wallet befüllen
    const user = new User('admin');
    user.setCryptoSuite(cryptoSuite);
    await user.setEnrollment(
      adminIdentity.credentials.privateKey,
      adminIdentity.credentials.certificate,
      mspId
    );

    // Affiliations abfragen
    const affiliationService = ca.newAffiliationService();
    const rootAffiliation = await affiliationService.getAll(user);
    console.log('Affiliation object:', JSON.stringify(rootAffiliation, null, 2));

    return rootAffiliation.affiliations;
  } catch (error) {
    console.error('Fehler beim Abrufen der Affiliations:', error);
    throw error;
  }
}

/**
 * Haupt-Server-Funktion
 */
async function main() {
  // 1) Einmalige Enrollment-Check: Admin in Wallet?
  await enrollAdminIfNeeded();

  // 2) Express-Server starten
  const app = express();
  app.use(bodyParser.json());

  // Route zum Affiliations-Abfragen
  app.get('/affiliations', async (req, res) => {
    try {
      const affiliations = await getAffiliations();
      res.json({ affiliations });
    } catch (error) {
      res.status(500).json({ error: error.toString() });
    }
  });

  const port = process.env.PORT || 53059;
  app.listen(port, () => {
    console.log(`Server running on port ${port}`);
  });
}

// Start
main().catch((err) => {
  console.error(err);
  process.exit(1);
});
