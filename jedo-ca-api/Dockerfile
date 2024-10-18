# Verwende ein leichtgewichtiges Node.js-Image als Basis
FROM node:lts-alpine

# Setze das Arbeitsverzeichnis auf /app
WORKDIR /app

# Kopiere package.json und package-lock.json, um die Abhängigkeiten zu installieren
COPY package*.json ./

# Installiere die notwendigen Node.js-Abhängigkeiten
RUN npm install

# Kopiere den Rest der App-Dateien ins Arbeitsverzeichnis
COPY . .

# Setze Ausführungsberechtigungen für das Start-Skript
RUN chmod +x /app/start.sh

# Exponiere den Port, auf dem der API-Server läuft
EXPOSE 3000

# Starte den API-Server
#CMD ["node", "server.js"]
CMD ["sh", "/app/start.sh"]

