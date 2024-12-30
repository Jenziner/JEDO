#!/bin/sh

# Installiere fehlende Module, um sicherzustellen, dass alle Abhängigkeiten da sind
npm install express cors axios archiver fabric-ca-client node-forge jsonwebtoken

# Installiere OpenSSL, um sicherzustellen, dass es zur Verfügung steht
apk add --no-cache openssl

# Starte den API-Server im Hintergrund
node server.js
