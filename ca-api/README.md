
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
openssl x509 -in /mnt/user/appdata/jedo/keys/eu.jedo.dev/alps.eu.jedo.dev/worb.alps.eu.jedo.dev/owner/msp/signcerts/cert.pem -text -noout

/mnt/user/appdata/jedo/keys/eu.jedo.dev/alps.eu.jedo.dev/worb.alps.eu.jedo.dev/owner/msp/signcerts/cert.pem





