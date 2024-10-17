const express = require('express');
const cors = require('cors');
const fs = require('fs');
const axios = require('axios');
const yaml = require('yaml');
const app = express();
const { exec } = require('child_process');


app.use(cors());
app.use(express.json());

// Lade Konfigurationen aus der YAML-Datei
const config = yaml.parse(fs.readFileSync('/app/config/jedo-ca-api-config.yaml', 'utf8'));

const registerUser = (username, password, affiliation) => {
  return new Promise((resolve, reject) => {
    exec(
      `/app/registerUser.sh ${config.ca_name} ${config.ca_pass} ${config.ca_port} ${config.ca_msp_dir} ${username} ${password} ${affiliation}`,
      (error, stdout, stderr) => {
        if (error) {
          console.error(`Error: ${stderr}`);
          reject({ message: "Registration failed", details: stderr || error.message });
        } else {
          console.log(`Output: ${stdout}`);
          resolve({ message: `Registration successful for ${username}`, output: stdout });
        }
      }
    );
  });
};

const enrollUser = (username, password) => {
  return new Promise((resolve, reject) => {
    const userMspDir = `${config.keys_dir}/${config.channel}/${config.organization}/wallet/${username}/msp`;
    exec(
      `/app/enrollUser.sh ${config.ca_name} ${config.ca_port} ${userMspDir} ${username} ${password}`,
      (error, stdout, stderr) => {
        if (error) {
          console.error(`Error: ${stderr}`);
          reject({ message: "Enrollment failed", details: stderr || error.message });
        } else {
          console.log(`Output: ${stdout}`);
          resolve({ message: `Enrollment successful for ${username}`, output: stdout });
        }
      }
    );
  });
};


// POST Endpoint für die Registrierung
app.post('/register', async (req, res) => {
  const { username, password, affiliation } = req.body;
  try {
    const result = await registerUser(username, password, affiliation);
    res.status(200).send(result);
  } catch (error) {
    console.error("Error during registration:", error);
    res.status(500).send({ error });
  }
});

// POST Endpoint für Enrollment
app.post('/enroll', async (req, res) => {
  const { username, password } = req.body;
  try {
    const result = await enrollUser(username, password);
    res.status(200).send(result);
  } catch (error) {
    console.error("Error during enrollment:", error);
    res.status(500).send({ error });
  }
});

// Starte den Server auf dem API-Port aus der Konfigurationsdatei
const PORT = config.api_port || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
