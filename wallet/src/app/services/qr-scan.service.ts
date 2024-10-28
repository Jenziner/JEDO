import { Injectable } from '@angular/core';
import { BarcodeScanner } from '@capacitor-community/barcode-scanner';

@Injectable({
  providedIn: 'root',
})
export class QrScanService {
  constructor() {}

  async scanQrCode(): Promise<string> {
    try {
      // Kamera vorbereiten
      await BarcodeScanner.checkPermission({ force: true });

      // Die Kamera öffnen und das Scannen starten
      BarcodeScanner.hideBackground(); // Optionale Methode, um den Hintergrund zu verbergen
      const result = await BarcodeScanner.startScan();

      if (result.hasContent) {
        console.log('QR-Code gescannt:', result.content);
        return result.content;
      } else {
        throw new Error('Keine Daten im QR-Code gefunden.');
      }
    } catch (error) {
      console.error('Fehler beim QR-Code-Scan:', error);
      throw new Error('Fehler beim QR-Code-Scan.');
    } finally {
      BarcodeScanner.showBackground(); // Hintergrund wieder anzeigen
      BarcodeScanner.stopScan(); // Kamera deaktivieren
    }
  }
}