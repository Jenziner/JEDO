const forge = require('node-forge');

// //////////////////////////////////////////////
// Function to create CSR (Certificate Signing Request) in PEM-Format
const generateCsr = ({ cn, names, altNames = [] }) => {
  const keys = forge.pki.rsa.generateKeyPair(2048);
  const csr = forge.pki.createCertificationRequest();
  csr.publicKey = keys.publicKey;

  // set CN in subject directly
  csr.setSubject(
    [
      ...names.map(name => {
        const [key, value] = Object.entries(name)[0];
        return {
          shortName: key,
          value: value
        };
      }),
      { shortName: 'CN', value: cn } 
    ]
  );

  // set SAN (Subject Alternative Names)
  if (altNames.length > 0) {
    csr.setAttributes([
      {
        name: 'extensionRequest',
        extensions: [
          {
            name: 'subjectAltName',
            altNames: altNames.map(altName => {
              if (altName.type === 2) {  // DNS name
                return { type: altName.type, value: altName.value };
              } else if (altName.type === 7) {  // IP address
                return { type: altName.type, ip: altName.ip };
              }
            })
          }
        ]
      }
    ]);
  };

  csr.sign(keys.privateKey);
  
  // Convert CSR to PEM
  const pem = forge.pki.certificationRequestToPem(csr);
  const privateKeyPem = forge.pki.privateKeyToPem(keys.privateKey);

  return {
    csrPem: pem,
    privateKeyPem: privateKeyPem
  };};

module.exports = {
  generateCsr
};
