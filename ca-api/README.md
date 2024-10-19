
# Endpoints:
http://localhost:port/register
http://localhost:port/enroll

# Website setting:
API Server URL: http://192.168.0.13:7048
Affiliation: dev.jedo.eu.jenziner
Affiliation: dev.jedo.eu.alps.worb

# Role definition:
- Issuer = !Subject.OU & id.name beginsWith "fsc."
- Owner = Subject.OU & id.name beginsWith "fsc."
- User = id.name !beginsWith "fsc."
