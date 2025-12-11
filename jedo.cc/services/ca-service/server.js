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
const caCertPath = path.join('/etc/hyperledger/infrastructure/temp', 'tls-cacert.pem');
const caCert = fs.readFileSync(caCertPath);

// 2) Vorhandene MSP-Zertifikate (von einem früheren Enrollment)
const mspCertPath = path.join('/etc/hyperledger/infrastructure/temp', 'cert.pem');
const mspKeyPath = path.join('/etc/hyperledger/infrastructure/temp', 'key.pkcs8.pem');
const mspCert = fs.readFileSync(mspCertPath, 'utf8');  // public cert
const mspKey = fs.readFileSync(mspKeyPath, 'utf8');    // private key

// 3) Fabric-CA-Server-URL und TLS-Options
const caURL = 'https://ca.alps.ea.jedo.dev:53041';
const caTLSOptions = {
  trustedRoots: [caCert],
  verify: true
};

// 4) MSP-Zugangsdaten (Enrollment) für den Admin o. ä.
const enrollmentID = 'ca.alps.ea.jedo.dev';
const enrollmentSecret = 'Test1';
const caName = 'ca.alps.ea.jedo.dev';
const mspId = 'jedo'; 

// 5) Fabric-CA-Client instanziieren
const ca = new FabricCAServices(caURL, caTLSOptions, caName);


// 8) Funktion zum Abrufen der Affiliations
async function getAffiliations() {
  try {
    // 6) Admin einschreiben (MSP)
    const enrollment = await ca.enroll({
        enrollmentID,
        enrollmentSecret
    });

    // 7) User-Objekt erstellen und enrollen
    const user = new User(enrollmentID);
    await user.setEnrollment(
    enrollment.key,
    enrollment.certificate,
    mspId
    );

    const affiliationService = ca.newAffiliationService();

    const response = await affiliationService.create({
        name: 'jedo.meinTest2',
        force: false
      }, user);
    console.log(`Affiliation response: ${response}`);

    const rootAffiliation = await affiliationService.getAll(user);
    console.log('Affiliation object:', JSON.stringify(rootAffiliation, null, 2));

//    return rootAffiliation.affiliations;
    return JSON.stringify(rootAffiliation, null, 2);
  } catch (error) {
    console.error('Fehler beim Abrufen der Affiliations:', error);
    throw error;
  }
}

// 9) Express-Server starten
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

  const port = process.env.PORT || 53059;
  app.listen(port, () => {
    console.log(`Server running on port ${port}`);
  });
}

// 10) main() ausführen
main().catch((err) => {
  console.error(err);
  process.exit(1);
});
