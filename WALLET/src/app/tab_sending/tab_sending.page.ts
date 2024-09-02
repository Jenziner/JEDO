import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { IonicModule } from '@ionic/angular';
import { BarcodeScanner } from '@capacitor-community/barcode-scanner';

@Component({
  selector: 'app-tab-sending',
  templateUrl: 'tab_sending.page.html',
  styleUrls: ['tab_sending.page.scss'],
  standalone: true,
  imports: [
    CommonModule,
    IonicModule
  ],
})
export class TabSendingPage {
  scannedUuid: string | null = null;
  scannedAmount: string | null = null;
  scannedError: string | null = null;

  constructor() {}

  async scanQrCode() {
    await BarcodeScanner.checkPermission({ force: true });
    BarcodeScanner.hideBackground();

    const result = await BarcodeScanner.startScan();

    if (result.hasContent) {
      this.processScannedData(result.content);
    } else {
      console.log('No QR code detected');
    }

    BarcodeScanner.showBackground();
    BarcodeScanner.stopScan();
  }

  processScannedData(data: string) {
    try {
      const parsedData = JSON.parse(data);

      if (parsedData.uuid && parsedData.amount) {
        this.scannedUuid = parsedData.uuid;
        this.scannedAmount = parsedData.amount;
      } else {
        this.scannedError = 'Invalid QR code data';
      }
    } catch (e) {
      this.scannedError = 'Error parsing QR code data';
    }
  }
}
