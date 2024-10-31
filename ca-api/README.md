# Installation:
Run from /jedo# ./ca-api/ca-api.sh

# Endpoints:
http://localhost:port/register
http://localhost:port/enroll

# Website setting:
API Server URL: http://192.168.0.13:7048
Affiliation: dev.jedo.eu.jenziner
Affiliation: dev.jedo.eu.alps.worb

# Role definition:
- CA = --id.attrs "jedo.role=CA"
- Issuer = --id.attrs "jedo.role=issuer"
- Owner = --id.attrs "jedo.role=owner"
- User = --id.attrs "jedo.role=user"




# ToDel
CA:
openssl x509 -in /mnt/user/appdata/jedo/keys/eu.jedo.dev/_infrastructure/ca.jenziner.eu.jedo.dev/msp/signcerts/cert.pem -text -noout

Issuer - generiert via API:
openssl x509 -in /mnt/user/appdata/jedo/keys/eu.jedo.dev/alps.eu.jedo.dev/issuer/IssuerA22/fsc/msp/signcerts/cert.pem -text -noout

Owner:
openssl x509 -in /mnt/user/appdata/jedo/keys/eu.jedo.dev/alps.eu.jedo.dev/owner/OwnerA23/fsc/msp/signcerts/cert.pem -text -noout



/mnt/user/appdata/jedo/keys/eu.jedo.dev/alps.eu.jedo.dev/worb.alps.eu.jedo.dev/owner/msp/signcerts/cert.pem




fscdir /etc/hyperledger/keys/$L.$ST.$C/$O.$L.$ST.$C/$ISSUER_NAME/fsc/msp
mspdir /etc/hyperledger/keys/$L.$ST.$C/$O.$L.$ST.$C/$ISSUER_NAME/msp

CSR_NAMES="C=$C,ST=$ST,L=$L,O=$O"


docker exec ca.jenziner.eu.jedo.dev fabric-ca-client affiliation list 