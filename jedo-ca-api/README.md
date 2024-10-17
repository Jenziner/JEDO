Prerequisites:
1. Node.js
2. Express.js

Todo:
1. Make scripts executable ```console
chmod +x registerUser.sh enrollUser.sh
```
2. Run ```console
node server.js
```

Endpoints:
http://localhost:3000/register
http://localhost:3000/enroll




With Docker:
1. Run console ```console
docker exec -it api.ca.jenziner.jedo.test /bin/bash
```
2. Run server ```console
node server.js
```
3. Run test```console
curl -X POST http://api.ca.jenziner.jedo.test:7048/register -H "Content-Type: application/json" \
-d '{"username": "testuser", "password": "testpass", "affiliation": "org1"}'
```

npm install
npm install express
npm install cors
npm install axios

node server.js

Open in Brower: JEDO/jedo-ca-api/register.html
(API Server URL: http://192.168.0.13:7048)


curl -X POST http://172.25.1.6:7048/register -H "Content-Type: application/json" -d '{"username": "ich", "password": "testpass", "affiliation": "org1"}'
Registration successful: Password: testpass

curl -X POST http://172.25.1.6:7048/enroll -H "Content-Type: application/json" -d '{"username": "ich", "password": "testpass"}'
