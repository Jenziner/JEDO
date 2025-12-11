/**
 * Beispiel-Code für einen einfachen API-Server mit Node.js,
 * der Affiliations vom Fabric-CA-Server abfragt (TLS-gesichert).
 */

const fs = require('fs');
const path = require('path');
const express = require('express');
const FabricCAServices = require('fabric-ca-client');
const bodyParser = require('body-parser');
const { User } = require('fabric-common');

// 1) TLS-Root-Zertifikat lesen
//    Passen den Pfad an, sodass er auf deine tls-cacert.pem verweist
//    (die Datei ist deine Root-CA für TLS).
const caCertPath = path.join('/etc/hyperledger/infrastructure/temp', 'tls-cacert.pem');
const caCert = fs.readFileSync(caCertPath);

// 2) Vorhandene MSP-Zertifikate (von einem früheren Enrollment)
//    Diese Dateien liegen ebenfalls im gleichen Verzeichnis.
const mspCertPath = path.join('/etc/hyperledger/infrastructure/temp', 'cert.pem');
const mspKeyPath = path.join('/etc/hyperledger/infrastructure/temp', 'key.pkcs8.pem');
const mspCert = fs.readFileSync(mspCertPath, 'utf8');  // public cert
const mspKey = fs.readFileSync(mspKeyPath, 'utf8');    // private key

// 3) Fabric-CA-Server-URL und TLS-Options
//    Hier legen wir fest, dass wir dem TLS-Server vertrauen und ihn verifizieren.
const caURL = 'https://ca.alps.ea.jedo.dev:53041';
const caTLSOptions = {
  trustedRoots: [caCert],
  verify: true
};



// TEMP
// test_parse.js
// const fs = require('fs');
const { KEYUTIL } = require('jsrsasign'); // jsrsasign ist via fabric-common meist vorhanden

const keyData = fs.readFileSync('/etc/hyperledger/infrastructure/temp/key.pem', 'utf8');

try {
  const keyObj = KEYUTIL.getKey(keyData);
  console.log('keyObj:', keyObj);
} catch (e) {
  console.error('Parse error:', e);
}




// 4) MSP-Zugangsdaten (Enrollment) für den Admin o. ä.
//    Die Namen sind nur Beispiele – normalerweise hast du z. B. "admin" statt "ca.alps.ea.jedo.dev"
// alt: const enrollmentID = 'ca.alps.ea.jedo.dev';
// alt: const enrollmentSecret = 'Test1';
const caName = 'ca.alps.ea.jedo.dev';
const mspId = 'jedo'; // oder z.B. 'Org1MSP' oder 'JedoMSP'

// Beispiel: FabricCAClient + CryptoSuite
function createCAClient() {
    // Du kannst hier oder weiter unten das CryptoSuite erzeugen
    const ca = new FabricCAServices(
      caURL,
      { trustedRoots: [caCert], verify: true },
      caName
    );
  
    return ca;
  }
  
// 5) Funktion zum Abrufen der Affiliations
async function getAffiliations() {
  try {
    // Fabric-CA-Client instanziieren
// alt2:    const ca = new FabricCAServices(caURL, caTLSOptions, caName);

    // Admin einschreiben (MSP), falls kein Wallet genutzt wird
// alt:     const enrollment = await ca.enroll({
// alt:       enrollmentID,
// alt:       enrollmentSecret
// alt:     });

    // Hier erstellen wir ein User-Objekt
// alt:     const user = new User(enrollmentID);
    /*
    setEnrollment erwartet:
        1) den private key (im PEM- oder PKCS#8-Format)
        2) das X.509-Zertifikat
        3) die MSP-ID (z.B. 'Org1MSP' oder wie auch immer deine Organisation heißt)
    */
// alt:     await user.setEnrollment(
// alt:     enrollment.key,
// alt:     enrollment.certificate,
// alt:     'jedo' // Anpassen an deine Organisation
// alt:     );

    // User aus bereits vorhandenen MSP-Zertifikaten erstellen
    // (keine neue Einschreibung!)
// alt2:    const user = new User('my-existing-user');  // beliebiger Name für dein User-Objekt



  // A) CA-Client holen
  const ca = createCAClient();

  // B) Eigenes CryptoSuite für P-384
  //    Entweder rufst du ca.newCryptoSuite(opts) auf, oder direkt FabricCAServices.newCryptoSuite(opts).
  const cryptoSuite = FabricCAServices.newCryptoSuite({
    software: true,   // meist true
    keySize: 384      // P-384
  });
  // Falls du ein KeyStore verwenden möchtest:
  // cryptoSuite.setCryptoKeyStore(
  //   FabricCAServices.newCryptoKeyStore({ path: '/some/secure/path' })
  // );

  // C) User-Objekt anlegen und CryptoSuite zuweisen
  const user = new User('my-existing-user');
  user.setCryptoSuite(cryptoSuite);

    await user.setEnrollment(
      mspKey,       // Private Key (PEM-Format)
      mspCert,      // Zertifikat (PEM-Format)
      mspId         // MSP-ID deiner Organisation
    );

    // Mit dem enrollment jetzt den AffiliationService nutzen
    const affiliationService = ca.newAffiliationService();

    // Auf neueren Fabric-Versionen kann es nötig sein,
    // die Identity explizit zu übergeben (z. B. identity: adminIdentity).
    // Für ein einfaches getAll() kann das ggf. noch ohne Identity klappen.
    const rootAffiliation = await affiliationService.getAll(user);
    
    console.log('Affiliation object:', JSON.stringify(rootAffiliation, null, 2));

    return rootAffiliation.affiliations;
  } catch (error) {
    console.error('Fehler beim Abrufen der Affiliations:', error);
    throw error;
  }
}

// 6) Express-Server starten
async function main() {
  const app = express();
  app.use(bodyParser.json());

  // Route: GET /affiliations
  app.get('/affiliations', async (req, res) => {
    try {
      const affiliations = await getAffiliations();
      res.json({ affiliations });
    } catch (error) {
      res.status(500).json({ error: error.toString() });
    }
  });

  // Port anpassen nach Bedarf
  const port = process.env.PORT || 53059;
  app.listen(port, () => {
    console.log(`Server running on port ${port}`);
  });
}

// 7) main() ausführen
main().catch((err) => {
  console.error(err);
  process.exit(1);
});
