import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { IonMenu, IonHeader, IonToolbar, IonTitle, IonContent, IonList, IonItem, IonLabel, IonInput, IonButtons, IonButton, IonMenuButton, IonIcon } from '@ionic/angular/standalone';
import { FormsModule } from '@angular/forms';
import { QrScanService } from '../services/qr-scan.service';
import { parseCertificate } from '../utils/certificate-utils';
import { Storage } from '@ionic/storage-angular';
import { v4 as uuidv4 } from 'uuid';
import { TranslateService, TranslateModule } from '@ngx-translate/core';
import { ModalController } from '@ionic/angular';
import { LanguageSelectorComponent } from '../language-selector/language-selector.component';
import { AlertController, ToastController } from '@ionic/angular';



//used in DEBUG to open other tabs not shown in the tabs
import { TabsPage } from '../tabs/tabs.page';

@Component({
  selector: 'app-menu',
  templateUrl: './menu.component.html',
  styleUrls: ['./menu.component.scss'],
  standalone: true,
  imports: [
    CommonModule,
    IonMenu,
    IonHeader,
    IonToolbar,
    IonTitle,
    IonContent,
    IonList,
    IonItem,
    IonLabel,
    IonInput,
    IonButtons,
    IonButton,
    IonMenuButton,
    IonIcon,
    FormsModule,
    TranslateModule,
  ],
  providers: [Storage, TabsPage,],
})

export class MenuComponent  implements OnInit {
  uuid: string | null = null;
  password: string | null = null;
  isRegistered: boolean = false;
  isGenerated: boolean = false;
  isImportMode: boolean = false;

  constructor(
    private storage: Storage, 
    private translate: TranslateService,
    private tabsPage: TabsPage,
    private modalCtrl: ModalController,
    private qrScanService: QrScanService,
    private alertController: AlertController,
    private toastController: ToastController
  ) { 
    this.init();
    translate.setDefaultLang('en');
  }

  async openLanguageSelector() {
    const modal = await this.modalCtrl.create({
      component: LanguageSelectorComponent
    });

    return await modal.present();
  }

  async init() {
    await this.storage.create();
  }

  async ngOnInit() {
    this.uuid = await this.storage.get('uuid');
    this.password = await this.storage.get('password');
    this.isRegistered = !!this.uuid && !!this.password;
    this.isGenerated = !!this.uuid;
  }

  async registerWallet() {
    console.log('registerWallet gestartet');
    try {
      const qrData = await this.qrScanService.scanQrCode();
      console.log('QR-Code Scan abgeschlossen. Daten:', qrData);

      const cameraElement = document.querySelector('.camera-element');
      if (cameraElement) {
        cameraElement.classList.add('camera-layer');
      }

      if (qrData) {
        // Prüfen, ob die QR-Daten ein Zertifikat darstellen
        const cert = await parseCertificate(qrData);
        if (cert) {
          const san = cert.san;
          console.log(`SAN-Daten gefunden: ${san}`);
        } else {
          console.warn('Keine SAN-Daten gefunden.');
        }

        // Benutzernamen und Passwort generieren
        this.generateCredentials();
        console.log(`Benutzername: ${this.uuid}, Passwort: ${this.password}`);

        // Toast zur Anzeige der Ergebnisse
      } else {
        console.error('Keine Daten gescannt.');
        await this.showToast('Keine Daten gescannt.');
      }
    } catch (error) {
      console.error('Fehler bei der Registrierung der Wallet:', error);
    }
  }

  async generateCredentials() {
    if (!this.isGenerated) {
      this.uuid = uuidv4();
      this.password = this.generatePassword();
      await this.storage.set('uuid', this.uuid);
      await this.storage.set('password', this.password);
      this.isGenerated = true;
    }
  }

  generatePassword(): string {
    // Simple generator, to be changed later
    return Math.random().toString(36).slice(-8);
  }

  enableImportMode() {
    this.isImportMode = true;
  }

  async saveImportedData() {
    if (this.uuid && this.password) {
      await this.storage.set('uuid', this.uuid);
      await this.storage.set('password', this.password);
      this.isGenerated = true;
      this.isImportMode = false;
    }
  }

  async deleteData() {
    await this.storage.remove('uuid');
    await this.storage.remove('password');
    this.uuid = null;
    this.password = null;
    this.isGenerated = false;
  }

  async showAlert(header: string, message: string) {
    const alert = await this.alertController.create({
      header,
      message,
      buttons: ['OK'],
    });

    await alert.present();
  }

  async showToast(message: string) {
    const toast = await this.toastController.create({
      message,
      duration: 3000,
      position: 'top'
    });

    await toast.present();
  }


  //used in DEBUG to open other tabs not shown in the tabs
    navigateToTab(tabName: string) {
      this.tabsPage.goToTab(tabName);
    }
  
}