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







Authorization Header: Bearer eyJhbGciOiJFUzM4NCIsInR5cCI6IkpXVCIsIng1YyI6WyItLS0tLUJFR0lOIENFUlRJRklDQVRFLS0tLS1cbk1JSUNhekNDQWZLZ0F3SUJBZ0lVTHhKQTZXVnN6UXpQYlUwRThZODVmWWRubEpJd0NnWUlLb1pJemowRUF3TXdcbllURUxNQWtHQTFVRUJoTUNTa1F4RERBS0JnTlZCQWdUQTBSbGRqRU5NQXNHQTFVRUNoTUVTa1ZFVHpFY01Bc0dcbkExVUVDeE1FYW1Wa2J6QU5CZ05WQkFzVEJtTnNhV1Z1ZERFWE1CVUdBMVVFQXhNT1kyRXVaV0V1YW1Wa2J5NWtcblpYWXdIaGNOTWpReE1URXpNVGt6TkRVd1doY05NalV4TVRFek1Ua3pORFV3V2pCbU1Rc3dDUVlEVlFRR0V3SktcblJERU1NQW9HQTFVRUNCTURSR1YyTVEwd0N3WURWUVFLRXdSS1JVUlBNUnd3Q3dZRFZRUUxFd1JxWldSdk1BMEdcbkExVUVDeE1HWTJ4cFpXNTBNUnd3R2dZRFZRUURFeE5qWVM1aGJIQnpMbVZoTG1wbFpHOHVaR1YyTUhZd0VBWUhcbktvWkl6ajBDQVFZRks0RUVBQ0lEWWdBRVptSllGL0dUYTExRjdUVno3SlhWd3g1dTIvQnZ4cUkyaVRadUxIT0RcbnNDUUFERnVXa052RXpYQTE3UXh1cXNjWHlpMkQ4OGVCZFRpaXdIbktzSzJuT1dGbWE0ZDlyUmQ3Mk1lTEdlYktcbkJuUmJta1hmQTRWaWxTNXl1Q3VMeFZsSm8yWXdaREFPQmdOVkhROEJBZjhFQkFNQ0FRWXdFZ1lEVlIwVEFRSC9cbkJBZ3dCZ0VCL3dJQkFEQWRCZ05WSFE0RUZnUVVtaGhxU2cvdjFReWFyWlloQ3lsODlkVHB3YkV3SHdZRFZSMGpcbkJCZ3dGb0FVcjlXbHhtTUZ3aWszSUdtazRHbnF6UDlIUGRNd0NnWUlLb1pJemowRUF3TURad0F3WkFJd1JGeGRcbkJTbklFY3h4L3VZMlFFQ0kwRjNoeVM2OTJuVW5DOTBVY2U0WGR3NGJlQkFQK3cyaFduVkJQQXRwSklKcUFqQlpcbkNOc0haOUpqWXB2RDFaNElqbWpyL1NseGt3M2tsTXZjTXZ4bWdFVnFTVmZiLzg0U0k4SVN4RTFBZ3UrOWxERT1cbi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS1cbiJdfQ.eyJzdWIiOiJjYS5hbHBzLmVhLmplZG8uZGV2IiwiaWF0IjoxNzM1NTA0OTIzLCJleHAiOjE3MzU1MDg1MjN9.8YWtFlEdRTYJcel3rQLv-twukimXdTAs-pOH5vBSV3MzjaLAKhFNJtoikNlNFOHBNLmB51bYzs2srhQemfOkAdFsXuHfHz_gPMWsGNj1CM1DIQiiTAiK7dB7hNaFU0b5
Failed to list affiliations: Error: fabric-ca request affiliations failed with errors [[ { code: 20, message: 'Authentication failure' } ]]
    at IncomingMessage.<anonymous> (/app/node_modules/fabric-ca-client/lib/FabricCAClient.js:298:19)
    at IncomingMessage.emit (node:events:531:35)
    at endReadableNT (node:internal/streams/readable:1696:12)
    at process.processTicksAndRejections (node:internal/process/task_queues:82:21) {
  result: '',
  errors: [ { code: 20, message: 'Authentication failure' } ],
  messages: [],
  success: false
}




curl -X GET http://192.168.0.13:53059/affiliations \
  --header "Authorization: Bearer eyJhbGciOiJFUzM4NCIsInR5cCI6IkpXVCIsIng1YyI6WyItLS0tLUJFR0lOIENFUlRJRklDQVRFLS0tLS1cbk1JSUNhekNDQWZLZ0F3SUJBZ0lVTHhKQTZXVnN6UXpQYlUwRThZODVmWWRubEpJd0NnWUlLb1pJemowRUF3TXdcbllURUxNQWtHQTFVRUJoTUNTa1F4RERBS0JnTlZCQWdUQTBSbGRqRU5NQXNHQTFVRUNoTUVTa1ZFVHpFY01Bc0dcbkExVUVDeE1FYW1Wa2J6QU5CZ05WQkFzVEJtTnNhV1Z1ZERFWE1CVUdBMVVFQXhNT1kyRXVaV0V1YW1Wa2J5NWtcblpYWXdIaGNOTWpReE1URXpNVGt6TkRVd1doY05NalV4TVRFek1Ua3pORFV3V2pCbU1Rc3dDUVlEVlFRR0V3SktcblJERU1NQW9HQTFVRUNCTURSR1YyTVEwd0N3WURWUVFLRXdSS1JVUlBNUnd3Q3dZRFZRUUxFd1JxWldSdk1BMEdcbkExVUVDeE1HWTJ4cFpXNTBNUnd3R2dZRFZRUURFeE5qWVM1aGJIQnpMbVZoTG1wbFpHOHVaR1YyTUhZd0VBWUhcbktvWkl6ajBDQVFZRks0RUVBQ0lEWWdBRVptSllGL0dUYTExRjdUVno3SlhWd3g1dTIvQnZ4cUkyaVRadUxIT0RcbnNDUUFERnVXa052RXpYQTE3UXh1cXNjWHlpMkQ4OGVCZFRpaXdIbktzSzJuT1dGbWE0ZDlyUmQ3Mk1lTEdlYktcbkJuUmJta1hmQTRWaWxTNXl1Q3VMeFZsSm8yWXdaREFPQmdOVkhROEJBZjhFQkFNQ0FRWXdFZ1lEVlIwVEFRSC9cbkJBZ3dCZ0VCL3dJQkFEQWRCZ05WSFE0RUZnUVVtaGhxU2cvdjFReWFyWlloQ3lsODlkVHB3YkV3SHdZRFZSMGpcbkJCZ3dGb0FVcjlXbHhtTUZ3aWszSUdtazRHbnF6UDlIUGRNd0NnWUlLb1pJemowRUF3TURad0F3WkFJd1JGeGRcbkJTbklFY3h4L3VZMlFFQ0kwRjNoeVM2OTJuVW5DOTBVY2U0WGR3NGJlQkFQK3cyaFduVkJQQXRwSklKcUFqQlpcbkNOc0haOUpqWXB2RDFaNElqbWpyL1NseGt3M2tsTXZjTXZ4bWdFVnFTVmZiLzg0U0k4SVN4RTFBZ3UrOWxERT1cbi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS1cbiJdfQ.eyJzdWIiOiJjYS5hbHBzLmVhLmplZG8uZGV2IiwiaWF0IjoxNzM1NTA0OTIzLCJleHAiOjE3MzU1MDg1MjN9.8YWtFlEdRTYJcel3rQLv-twukimXdTAs-pOH5vBSV3MzjaLAKhFNJtoikNlNFOHBNLmB51bYzs2srhQemfOkAdFsXuHfHz_gPMWsGNj1CM1DIQiiTAiK7dB7hNaFU0b5" \
  --cert ./signcerts/cert.pem \
  --key ./keystore/8dd469aea13ab7123c9dc65d74350833d0195354c5972f36b45057513f0ac438_sk \
  --cacert ./tlscacerts/tls-tls-jedo-dev-51031.pem


  curl -v http://192.168.0.13:53059/api/v1/affiliations


  curl -X GET https://ca.alps.ea.jedo.dev:53041/cainfo \
  --cert ./temp/signcerts/cert.pem \
  --key ./temp/keystore/8dd469aea13ab7123c9dc65d74350833d0195354c5972f36b45057513f0ac438_sk \
  --cacert ./temp/tlscacerts/tls-tls-jedo-dev-51031.pem


  curl -X GET https://ca.alps.ea.jedo.dev:53041/api/v1/affiliations \
  --cert ./temp/signcerts/cert.pem \
  --key ./temp/keystore/8dd469aea13ab7123c9dc65d74350833d0195354c5972f36b45057513f0ac438_sk \
  --cacert ./temp/tlscacerts/tls-tls-jedo-dev-51031.pem \
  --user "ca.alps.ea.jedo.dev:Test1"

  -H "Authorization: Bearer eyJhbGciOiJFUzM4NCIsInR5cCI6IkpXVCIsIng1YyI6WyItLS0tLUJFR0lOIENFUlRJRklDQVRFLS0tLS1cbk1JSUNhekNDQWZLZ0F3SUJBZ0lVTHhKQTZXVnN6UXpQYlUwRThZODVmWWRubEpJd0NnWUlLb1pJemowRUF3TXdcbllURUxNQWtHQTFVRUJoTUNTa1F4RERBS0JnTlZCQWdUQTBSbGRqRU5NQXNHQTFVRUNoTUVTa1ZFVHpFY01Bc0dcbkExVUVDeE1FYW1Wa2J6QU5CZ05WQkFzVEJtTnNhV1Z1ZERFWE1CVUdBMVVFQXhNT1kyRXVaV0V1YW1Wa2J5NWtcblpYWXdIaGNOTWpReE1URXpNVGt6TkRVd1doY05NalV4TVRFek1Ua3pORFV3V2pCbU1Rc3dDUVlEVlFRR0V3SktcblJERU1NQW9HQTFVRUNCTURSR1YyTVEwd0N3WURWUVFLRXdSS1JVUlBNUnd3Q3dZRFZRUUxFd1JxWldSdk1BMEdcbkExVUVDeE1HWTJ4cFpXNTBNUnd3R2dZRFZRUURFeE5qWVM1aGJIQnpMbVZoTG1wbFpHOHVaR1YyTUhZd0VBWUhcbktvWkl6ajBDQVFZRks0RUVBQ0lEWWdBRVptSllGL0dUYTExRjdUVno3SlhWd3g1dTIvQnZ4cUkyaVRadUxIT0RcbnNDUUFERnVXa052RXpYQTE3UXh1cXNjWHlpMkQ4OGVCZFRpaXdIbktzSzJuT1dGbWE0ZDlyUmQ3Mk1lTEdlYktcbkJuUmJta1hmQTRWaWxTNXl1Q3VMeFZsSm8yWXdaREFPQmdOVkhROEJBZjhFQkFNQ0FRWXdFZ1lEVlIwVEFRSC9cbkJBZ3dCZ0VCL3dJQkFEQWRCZ05WSFE0RUZnUVVtaGhxU2cvdjFReWFyWlloQ3lsODlkVHB3YkV3SHdZRFZSMGpcbkJCZ3dGb0FVcjlXbHhtTUZ3aWszSUdtazRHbnF6UDlIUGRNd0NnWUlLb1pJemowRUF3TURad0F3WkFJd1JGeGRcbkJTbklFY3h4L3VZMlFFQ0kwRjNoeVM2OTJuVW5DOTBVY2U0WGR3NGJlQkFQK3cyaFduVkJQQXRwSklKcUFqQlpcbkNOc0haOUpqWXB2RDFaNElqbWpyL1NseGt3M2tsTXZjTXZ4bWdFVnFTVmZiLzg0U0k4SVN4RTFBZ3UrOWxERT1cbi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS1cbiJdfQ.eyJzdWIiOiJjYS5hbHBzLmVhLmplZG8uZGV2IiwiaWF0IjoxNzM1NTA0OTIzLCJleHAiOjE3MzU1MDg1MjN9.8YWtFlEdRTYJcel3rQLv-twukimXdTAs-pOH5vBSV3MzjaLAKhFNJtoikNlNFOHBNLmB51bYzs2srhQemfOkAdFsXuHfHz_gPMWsGNj1CM1DIQiiTAiK7dB7hNaFU0b5"



docker exec -it tools.jedo.dev fabric-ca-client affiliation list -u https://ca.alps.ea.jedo.dev:Test1@ca.alps.ea.jedo.dev:53041 
--tls.certfiles tls-root-cert/tls-ca-cert.pem --home /etc/hyperledger/fabric-ca-client 
--mspdir /etc/hyperledger/fabric-ca-client/infrastructure/jedo/ea/alps/ca.alps.ea.jedo.dev/msp


2024-12-29 21:42:51.454 UTC 0001 DEBU [bccsp_sw] openKeyStore -> KeyStore opened at [/etc/hyperledger/fabric-ca-client/infrastructure/jedo/ea/alps/ca.alps.ea.jedo.dev/msp/keystore]...done
2024-12-29 21:42:51.455 UTC 0002 DEBU [bccsp_sw] loadPrivateKey -> Loading private key [1113a0a0cf9021454a9f09a83fb884bebe1bc6ab096295287a4450ca552fd903] at [/etc/hyperledger/fabric-ca-client/infrastructure/jedo/ea/alps/ca.alps.ea.jedo.dev/msp/keystore/1113a0a0cf9021454a9f09a83fb884bebe1bc6ab096295287a4450ca552fd903_sk]...
2024-12-29 21:42:51.460 UTC 0003 DEBU [bccsp_sw] openKeyStore -> KeyStore opened at [/etc/hyperledger/fabric-ca-client/infrastructure/jedo/ea/alps/ca.alps.ea.jedo.dev/msp/keystore]...done
2024-12-29 21:42:51.462 UTC 0004 DEBU [bccsp_sw] loadPrivateKey -> Loading private key [1113a0a0cf9021454a9f09a83fb884bebe1bc6ab096295287a4450ca552fd903] at [/etc/hyperledger/fabric-ca-client/infrastructure/jedo/ea/alps/ca.alps.ea.jedo.dev/msp/keystore/1113a0a0cf9021454a9f09a83fb884bebe1bc6ab096295287a4450ca552fd903_sk]...
affiliation: jedo
   affiliation: jedo.root
   affiliation: jedo.ea
      affiliation: jedo.ea.alps
   affiliation: jedo.as
   affiliation: jedo.af
   affiliation: jedo.na
   affiliation: jedo.sa



curl -X GET https://ca.alps.ea.jedo.dev:53041/api/v1/affiliations \
  --cert ./temp/signcerts/cert.pem \
  --key ./temp/keystore/8dd469aea13ab7123c9dc65d74350833d0195354c5972f36b45057513f0ac438_sk \
  --cacert ./temp/tlscacerts/tls-tls-jedo-dev-51031.pem \
  -u "ca.alps.ea.jedo.dev:Test1"




cert=$(awk 'NF {sub(/\\n/, ""); printf "%s",$0;}' ./temp/cert.pem | sed -e 's/-----BEGIN CERTIFICATE-----//' -e 's/-----END CERTIFICATE-----//')
cert_base64=$(echo -n "$cert" | base64 | tr -d '\n')
body=""
data_to_sign="${cert_base64}${body}"
signature=$(echo -n "$data_to_sign" | openssl dgst -sha256 -sign ./temp/key.pem | base64 | tr -d '\n')
token="${cert_base64}.${signature}"
curl -X GET https://ca.alps.ea.jedo.dev:53041/api/v1/affiliations \
  --cert ./temp/signcerts/cert.pem \
  --key ./temp/keystore/8dd469aea13ab7123c9dc65d74350833d0195354c5972f36b45057513f0ac438_sk \
  --cacert ./temp/tlscacerts/tls-tls-jedo-dev-51031.pem \
  -H "Authorization: token ${token}"


cert=$(awk 'NF {sub(/\\n/, ""); printf "%s",$0;}' ./temp/cert.pem | sed -e 's/-----BEGIN CERTIFICATE-----//' -e 's/-----END CERTIFICATE-----//' | tr -d '\n')
cert_base64=$(echo -n "$cert" | base64 | tr -d '\n')
body=""
data_to_sign="${cert_base64}${body}"
signature=$(echo -n "$data_to_sign" | openssl dgst -sha256 -sign ./temp/key.pem | base64 | tr -d '\n')
token="${cert_base64}.${signature}"
curl -X GET https://ca.alps.ea.jedo.dev:53041/api/v1/affiliations \
  --cert ./temp/signcerts/cert.pem \
  --key ./temp/keystore/8dd469aea13ab7123c9dc65d74350833d0195354c5972f36b45057513f0ac438_sk \
  --cacert ./temp/tlscacerts/tls-tls-jedo-dev-51031.pem \
  -H "Authorization: token ${token}"



cert=$(awk 'NF {printf "%s\\n", $0}' ./temp/cert.pem)
body=""
data_to_sign="${cert}${body}"
echo -n "Zu signieren: $data_to_sign"
signature=$(echo -n "$data_to_sign" | openssl dgst -sha256 -sign ./temp/key.pem | base64 | tr -d '\n')
token="${cert}.${signature}"
curl -X GET https://ca.alps.ea.jedo.dev:53041/api/v1/affiliations \
  --cert ./temp/signcerts/cert.pem \
  --key ./temp/keystore/8dd469aea13ab7123c9dc65d74350833d0195354c5972f36b45057513f0ac438_sk \
  --cacert ./temp/tlscacerts/tls-tls-jedo-dev-51031.pem \
  -H "Authorization: token ${token}"



cert=$(awk 'NF {sub(/\\n/, ""); printf "%s",$0;}' ./temp/cert.pem | sed -e 's/-----BEGIN CERTIFICATE-----//' -e 's/-----END CERTIFICATE-----//' | tr -d '\n')
data_to_sign="${cert}"
signature=$(echo -n "$data_to_sign" | openssl dgst -sha256 -sign ./temp/key.pem | base64 | tr -d '\n')
token="${cert}.${signature}"
curl -X GET https://ca.alps.ea.jedo.dev:53041/api/v1/affiliations \
  --cert ./temp/signcerts/cert.pem \
  --key ./temp/keystore/8dd469aea13ab7123c9dc65d74350833d0195354c5972f36b45057513f0ac438_sk \
  --cacert ./temp/tlscacerts/tls-tls-jedo-dev-51031.pem \
  -H "Authorization: token ${token}"



cert=$(cat ./temp/cert.pem)
cert_base64=$(echo -n "$cert" | base64 | tr -d '\n' | tr '/+' '_-' | tr -d '=')
echo "$cert_base64" | openssl x509 -text -noout
echo "Inhalt: $cert_base64"
data_to_sign="${cert_base64}"
signature=$(echo -n "$data_to_sign" | openssl dgst -sha256 -sign ./temp/key.pem | base64 | tr -d '\n' | tr '/+' '_-' | tr -d '=')
token="${cert_base64}.${signature}"
curl -X GET https://ca.alps.ea.jedo.dev:53041/api/v1/affiliations \
  --cert ./temp/signcerts/cert.pem \
  --key ./temp/keystore/8dd469aea13ab7123c9dc65d74350833d0195354c5972f36b45057513f0ac438_sk \
  --cacert ./temp/tlscacerts/tls-tls-jedo-dev-51031.pem \
  -H "Authorization: token ${token}"


docker logs ca.alps.ea.jedo.dev