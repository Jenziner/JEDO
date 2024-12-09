###############################################################
#!/bin/bash
#
# Temporary script.
#
#
###############################################################



# Search for certificate with serial: 29e3a9...

# find /mnt/user/appdata/jedo-dev -type f -name "*.pem" -exec sh -c '
#     for file do
#         if openssl x509 -in "$file" -noout -serial | grep -qi "29e3a9"; then
#             echo "Zertifikat gefunden: $file"
#         fi
#     done
# ' sh {} +



GENESIS_FILE="genesis.json"  # JSON-Datei mit dem Genesis-Block
SERIAL_TO_FIND="600117104757965892184400372521796404119450156427"

# Extrahiere alle Base64-Zertifikate
echo "Los gehts"
jq -r '
  .data.data[0].payload.data.config.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters[].client_tls_cert,
  .data.data[0].payload.data.config.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters[].server_tls_cert,
  .data.data[0].payload.data.config.channel_group.groups.Application.groups.ea.values.MSP.value.config.root_certs[],
  .data.data[0].payload.data.config.channel_group.groups.Application.groups.ea.values.MSP.value.config.intermediate_certs[]
' "$GENESIS_FILE" | while read -r CERT_BASE64; do
  # Decode the certificate
  echo "$CERT_BASE64" | base64 -d > cert.pem
  
  # Check the serial number
  CERT_SERIAL=$(openssl x509 -noout -serial -in cert.pem | cut -d= -f2)
  
  # Compare with the desired serial
  if [[ "$CERT_SERIAL" == "$SERIAL_TO_FIND" ]]; then
    echo "Found matching certificate:"
    openssl x509 -in cert.pem -text -noout
  fi
done