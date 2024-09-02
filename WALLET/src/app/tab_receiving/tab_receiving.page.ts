import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { QRCodeModule } from 'angularx-qrcode';
import { IonicModule, NavController } from '@ionic/angular';
import { Storage } from '@ionic/storage-angular';


@Component({
  selector: 'app-tab-receiving',
  templateUrl: 'tab_receiving.page.html',
  styleUrls: ['tab_receiving.page.scss'],
  standalone: true,
  imports: [
    CommonModule,
    QRCodeModule,
    IonicModule
  ],
  providers: [Storage],
})

export class TabReceivingPage {
  uuid: string | null = null;
  qrData: string | null = null;
  @Input() initialAmount: string = '0.00';  
  amount: string | null = null; 
  isFirstInput: boolean = true;
 

  constructor(
    private storage: Storage,
    private navController: NavController,
  ) {
    this.initializeApp();
  }

  async ionViewWillEnter() {
    this.uuid = await this.storage.get('uuid');

    if (!this.uuid) {
      this.redirectToSettings();
    } else {
      this.amount = this.amount || this.initialAmount;
      this.updateQrData();
    }
  }

  async initializeApp() {
    await this.storage.create();
  }

  async redirectToSettings() {
    await this.navController.navigateRoot('/tabs/tab_settings');
  }

  addNumber(num: string) {
    const currentAmount = this.amount || this.initialAmount;

    if (this.isFirstInput) {
      if (num === '.') {
        this.amount = '0.'; // Wenn der Benutzer mit einem Punkt beginnt, füge "0." ein
      } else {
        this.amount = num; // Leert den Betrag und fügt die erste Zahl hinzu
      }
      this.isFirstInput = false; // Setzt das Flag zurück, damit weitere Zahlen angehängt werden
    } else {
      if (num === '.' && currentAmount.includes('.')) {
        return; // Ignoriere den Punkt, wenn bereits ein Punkt vorhanden ist
      }
      this.amount += num; // Füge die Zahl oder den Punkt hinzu
    }
    this.updateQrData();
  }

  removeLast() {
    const currentAmount = this.amount || this.initialAmount;
    
    this.amount = currentAmount.slice(0, -1);    
    if (this.amount.length === 0) {
      this.amount = this.initialAmount; 
      this.isFirstInput = true; 
    }  
    this.updateQrData();
  }

  updateQrData() {
    this.qrData = JSON.stringify({
      uuid: this.uuid,
      amount: this.amount
    });
  }

}
