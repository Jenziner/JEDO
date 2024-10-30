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
  if (certificate.extensions) {
    certificate.extensions.forEach(ext => {
      if (ext.extnID === "2.5.29.17" && ext.parsedValue && ext.parsedValue.altNames) {
        san = ext.parsedValue.altNames.map((altName: any) => altName.value).join(", ");
      }
    });
  } else {
    console.warn("Keine Extensions im Zertifikat gefunden.");
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