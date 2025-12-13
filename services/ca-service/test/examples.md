# Request Examples
## Register Gens:
curl -X POST http://localhost:3001/certificates/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "gens001",
    "secret": "SecurePass123",
    "role": "gens",
    "affiliation": "jedo.alps.worb",
    "attrs": {
      "email": "gens001@example.com"
    }
  }'

## Enroll Gens
curl -X POST http://localhost:3001/certificates/enroll \
  -H "Content-Type: application/json" \
  -d '{
    "username": "gens001",
    "secret": "SecurePass123",
    "role": "gens"
  }'

## Direct Register (ohne Gateway)
curl -X POST http://localhost:3001/certificates/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test001",
    "secret": "TestPass123",
    "role": "gens",
    "affiliation": "jedo.alps.worb"
  }'

## CA-Service via Gateway (pathRewrite!)
curl -X POST http://localhost:3000/api/v1/ca/certificates/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test002",
    "secret": "TestPass456",
    "role": "gens",
    "affiliation": "jedo.alps.worb"
  }'