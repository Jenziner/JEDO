# Verwende das Docker-Image als Basis
FROM docker:latest

# Installiere grundlegende Werkzeuge und Bash
RUN apk add --no-cache bash

# Installiere Node.js und npm
RUN apk add --no-cache nodejs npm

# Setze das Arbeitsverzeichnis auf /app
WORKDIR /app

# Kopiere package.json und package-lock.json, um später Abhängigkeiten zu installieren
COPY package*.json ./

# Kopiere den Rest der App-Dateien ins Arbeitsverzeichnis
COPY . .

# Setze Ausführungsberechtigungen für die Skripte
RUN chmod +x /app/registerUser.sh /app/enrollUser.sh /app/start.sh

# Standardkommando auf /bin/sh gesetzt, damit der Container bleibt
#CMD ["/bin/sh", "-c", "npm install && npm install express cors axios && node server.js &"]
CMD ["sh", "/app/start.sh"]
