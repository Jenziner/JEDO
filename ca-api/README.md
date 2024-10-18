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





docker ps -a | grep api.ca.jenziner.jedo.test

docker logs api.ca.jenziner.jedo.test

docker exec api.ca.jenziner.jedo.test ls -l /app/admin


chmod -R 777 ./../jedo-network/keys


$KEYS_DIR/$TOKEN_NETWORK_NAME/$USER_OWNER/wallet/$USER_NAME/msp


docker exec api.ca.jenziner.jedo.test ls -l /app/admin/cacerts/


tls-ca-jenziner-jedo-test-7040.pem
docker exec api.ca.jenziner.jedo.test openssl x509 -in /app/admin/cacerts/tls-ca-jenziner-jedo-test-7040.pem -noout -text
docker exec api.ca.jenziner.jedo.test openssl verify -CAfile <root-ca-cert.pem> /app/admin/cacerts/tls-ca-jenziner-jedo-test-7040.pem.pem

docker exec api.ca.jenziner.jedo.test openssl verify -CAfile /etc/hyperledger/keys/tls.ca.jedo.test/ca-cert.pem /app/admin/cacerts/tls-ca-jenziner-jedo-test-7040.pem

/etc/hyperledger/keys/tls.ca.jedo.test/ca-cert.pem

curl --cacert /app/admin/cacerts/tls-ca-jenziner-jedo-test-7040.pem https://tls.ca.jedo.test:7040

docker exec api.ca.jenziner.jedo.test curl --capath /etc/hyperledger/keys/tls.ca.jedo.test/combined-ca-cert.pem https://tls.ca.jenziner.jedo.test:7040


docker exec api.ca.jenziner.jedo.test cat /etc/hyperledger/keys/tls.ca.jedo.test/ca-cert.pem /app/admin/cacerts/tls-ca-jenziner-jedo-test-7040.pem > /etc/hyperledger/keys/tls.ca.jedo.test/combined-ca-cert.pem
