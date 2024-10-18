#!/bin/sh

# Installiere fehlende Module, um sicherzustellen, dass alle Abhängigkeiten da sind
npm install express cors axios archiver fabric-ca-client

# Starte den API-Server im Hintergrund
node server.js
