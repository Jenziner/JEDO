import * as asn1js from "asn1js";
import * as pkijs from "pkijs";
import * as forge from "node-forge";

export async function parseCertificate(certPem: string) {
  try {
    // 1. Base64-Teil des Zertifikats extrahieren
    const base64Cert = certPem
      .replace('-----BEGIN CERTIFICATE-----', '')
      .replace('-----END CERTIFICATE-----', '')
      .replace(/\s+/g, ''); // Entfernt alle Whitespaces

    // 2. Base64-Dekodierung in ArrayBuffer umwandeln
    const certBuffer = forge.util.decode64(base64Cert);
    const certArrayBuffer = new Uint8Array(certBuffer.length);
    for (let i = 0; i < certBuffer.length; i++) {
      certArrayBuffer[i] = certBuffer.charCodeAt(i);
    }

    // 3. ASN.1 Dekodieren
    const asn1 = asn1js.fromBER(certArrayBuffer.buffer);
    if (asn1.offset === -1) {
      throw new Error("Fehler beim Parsen des ASN.1 Datenformats.");
    }

    // 4. Zertifikatsobjekt erstellen
    const certificate = new pkijs.Certificate({ schema: asn1.result });

    return { certificate };
  } catch (error) {
    console.error('Fehler beim Parsen des Zertifikats:', error);
    return null;
  }
}

export function getSAN(certificate: pkijs.Certificate): string {
  let san = '';
  const dnsNames: string[] = [];
  const ipAddresses: string[] = [];

  if (certificate.extensions) {
    certificate.extensions.forEach(ext => {
      if (ext.extnID === "2.5.29.17" && ext.parsedValue && ext.parsedValue.altNames) {
        ext.parsedValue.altNames.forEach((altName: any) => {
          // Prüfen, ob der AltName ein DNS-Name ist
          if (altName.type === 2) {
            dnsNames.push(altName.value);
          }
          // Prüfen, ob der AltName ein IP-Adress-OCTET ist
          else if (altName.type === 7) {
            const ip = convertOctetStringToIP(altName.value.valueBlock.valueHex);
            if (ip) {
              ipAddresses.push(ip);
            }
          }
        });
      }
    });
  } else {
    console.warn("Keine Extensions im Zertifikat gefunden.");
  }

  if (dnsNames.length > 0) {
    san += `DNS: ${dnsNames.join(", ")}`;
  }

  if (ipAddresses.length > 0) {
    if (san) san += ", ";
    san += `IP Address: ${ipAddresses.join(", ")}`;
  }

  if (!san) {
    console.warn('Keine SAN-Daten im Zertifikat gefunden');
  }
  return san;
}

export function getSubject(certificate: pkijs.Certificate): Record<string, string> {
  const subjectData: Record<string, string> = { C: '', ST: '', L: '', O: '', OU: '', CN: '' };
  certificate.subject.typesAndValues.forEach(typeAndValue => {
    switch (typeAndValue.type) {
      case '2.5.4.6':  // C (Country Name)
        subjectData['C'] = typeAndValue.value.valueBlock.value;
        break;
      case '2.5.4.8':  // ST (State or Province Name)
        subjectData['ST'] = typeAndValue.value.valueBlock.value;
        break;
      case '2.5.4.7':  // L (Locality Name)
        subjectData['L'] = typeAndValue.value.valueBlock.value;
        break;
      case '2.5.4.10': // O (Organization Name)
        subjectData['O'] = typeAndValue.value.valueBlock.value;
        break;
      case '2.5.4.11': // OU (Organizational Unit Name)
        subjectData['OU'] = typeAndValue.value.valueBlock.value;
        break;
      case '2.5.4.3':  // CN (Common Name)
        subjectData['CN'] = typeAndValue.value.valueBlock.value;
        break;
    }
  });
  
  return subjectData;
}


export function getAPIPort(certificate: pkijs.Certificate): string {
  let apiPort = 'Unknown';

  if (certificate.extensions) {
    // Schleife durch alle Extensions des Zertifikats
    certificate.extensions.forEach(ext => {
      // Prüfe, ob die Extension den erwarteten ID-String (OID) enthält
      if (ext.extnID === '1.2.3.4.5.6.7.8.1') {
        try {
          // Die Daten aus der Extension sind in einem ASN.1 Format. Wir nehmen an, dass es ein UTF8String oder ein ähnlicher Typ ist.
          const valueHexArray = new Uint8Array(ext.extnValue.valueBlock.valueHex);
          
          // Uint8Array in number[] konvertieren
          const jsonString = String.fromCharCode(...valueHexArray);

          // Versuchen, die JSON-Attribute aus der Extension zu parsen
          const parsedData = JSON.parse(jsonString);

          // Wenn das Attribut 'jedo.apiPort' existiert, den Wert extrahieren
          if (parsedData.attrs && parsedData.attrs['jedo.apiPort']) {
            apiPort = parsedData.attrs['jedo.apiPort'];
          }
        } catch (error) {
          console.error('Fehler beim Extrahieren der API-Port-Informationen:', error);
        }
      }
    });
  } else {
    console.warn('Keine Extensions im Zertifikat gefunden.');
  }

  if (apiPort === 'Unknown') {
    console.warn('API-Port nicht im Zertifikat gefunden.');
  }
  
  return apiPort;
}


function convertOctetStringToIP(octetString: ArrayBuffer): string {
  const bytes = new Uint8Array(octetString);
  if (bytes.length === 4) {
    return `${bytes[0]}.${bytes[1]}.${bytes[2]}.${bytes[3]}`;
  } else {
    console.warn("Unerwartete Länge für IP-OCTET STRING:", bytes);
    return '';
  }
}