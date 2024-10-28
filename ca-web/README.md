# CA-WEB
The CA-WEB can be used to generate certificates for the JEDO ecosystem. 

To start, simply open the index.html in a browser.

## Issuer
An Issuer represents an entire region. Prior to generate just a certificate, make sure all other requirements are fulfilled.
1. Load a certificate of a ca-admin with proper rights. If the certificate is valid, the CA-Web shows the Role "CA" from the certificate as well as additional data to find the CA-API-Server
2. Enter the name of the region, a username for the Isure (typically iss.dns.name.of.region) and the password
3. Click "Execute" searchtes the CA-Server and reguests the generation of a new certificate. If successsfull, it will be downloaded

## Owner
An Owner represents an organisation within a region. Prior to generate a new owner, make sure the representative is trustworthy. Do not create Owner-Certificates under preassure, suspicious circumstances or for illigal actions.
1. Load a certificate of an issuer of the requested region. If the certificate is valid, the CA-Web shows the Role "Issuer" from the certificate as well as a QR-Code with the certificate-details.
2. Do not create the certificate with the CA-WEB! It is only used to generate the QR-Code for self-registration of the Issuer. You may create an Owner-Certificate, but only for testing.
3. Check, if a valid JEDO-WALLET-App is used by the new Owner
4. Use only the cam-function of the JEDO-WALLET to scan the QR-Code. Do not use any other camera app to avoid missuse of the Issuer-Certificate.
5. The new Owner should start the registration within the JEDO-WALLET

## User
An User represents any human with a JEDO-WALLET. To add a new User to an organisation, the JEDO-WALLET should be used. When you load an Owner-Certificate, you may create a User-Certificate, but only for testing.