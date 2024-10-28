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

    // 5. SAN-Daten auslesen
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

    if (san) {
      console.log('SAN-Daten gefunden:', san);
    } else {
      console.warn('Keine SAN-Daten im Zertifikat gefunden');
    }

    return { san };
  } catch (error) {
    console.error('Fehler beim Parsen des Zertifikats:', error);
    return null;
  }
}
