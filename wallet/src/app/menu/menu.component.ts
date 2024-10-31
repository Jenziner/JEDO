import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { IonMenu, IonHeader, IonToolbar, IonTitle, IonContent, IonList, IonItem, IonLabel, IonInput, IonButtons, IonButton, IonMenuButton, IonIcon } from '@ionic/angular/standalone';
import { FormsModule } from '@angular/forms';
import { QrScanService } from '../services/qr-scan.service';
import { Storage } from '@ionic/storage-angular';
import { v4 as uuidv4 } from 'uuid';
import { TranslateService, TranslateModule } from '@ngx-translate/core';
import { ModalController } from '@ionic/angular';
import { LanguageSelectorComponent } from '../language-selector/language-selector.component';
import { AlertController, ToastController } from '@ionic/angular';
import { Filesystem, Directory } from '@capacitor/filesystem';
import { Capacitor } from '@capacitor/core';
import JSZip from 'jszip';
import { Injectable } from '@angular/core';
import { Preferences } from '@capacitor/preferences';

import { parseCertificate, getSAN, getSubject } from '../utils/certificate-utils';


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

@Injectable({
  providedIn: 'root'
})

export class MenuComponent  implements OnInit {
  uuid: string | null = null;
  password: string | null = null;
  owner: string | null = null;
  isRegistered: boolean = false;

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
    await this.initializeAppData();
  }


  async initializeAppData() {
    this.isRegistered = false;
    this.password = (await Preferences.get({ key: 'password' })).value;
    const certContent = (await Preferences.get({ key: 'certificateContent' })).value;
    
    if (certContent) {
      const parsedResult = await parseCertificate(certContent);
      if (parsedResult && parsedResult.certificate) {
        const certificate = parsedResult.certificate;
  
        const subject = getSubject(certificate);
        const { O, L, ST, C, CN } = subject;
        this.uuid = `${CN}`;
        this.owner = `${O}.${L}.${C}.jedo.${ST}`;

        this.isRegistered = true;
      }
    }
  }


  async registerWallet() {
    try {
      const qrData = await this.qrScanService.scanQrCode();

      const cameraElement = document.querySelector('.camera-element');
      if (cameraElement) {
        cameraElement.classList.add('camera-layer');
      }

      if (qrData) {
        const parsedResult = await parseCertificate(qrData);
        if (parsedResult && parsedResult.certificate) {
          const certificate = parsedResult.certificate;
      
          const san = getSAN(certificate);
          console.log("Subject Alternative Names (SAN):", san);
      
          const subject = getSubject(certificate);
          console.log("Subject Information:", subject);
        }

        this.uuid = uuidv4();
        this.password = this.generatePassword();
        this.owner = "test";
        await Preferences.set({ key: 'uuid', value: this.uuid });
        await Preferences.set({ key: 'password', value: this.password });
        await Preferences.set({ key: 'owner', value: this.owner });

      }
    } catch (error) {
      console.error('Fehler bei der Registrierung der Wallet:', error);
    }
  }


  async importWalletCert() {
    try {
      const inputElement = document.createElement('input');
      inputElement.type = 'file';
      inputElement.accept = '.zip';
      inputElement.click();

      const filePromise: Promise<File> = new Promise((resolve, reject) => {
        inputElement.addEventListener('change', (event: any) => {
          if (event.target.files.length > 0) {
            resolve(event.target.files[0]);
          } else {
            reject('Keine Datei ausgewählt');
          }
        });
      });

      const file = await filePromise;
      const fileData = await file.arrayBuffer();
      const zip = await JSZip.loadAsync(fileData);
      let certificateContent = '';
      let privateKeyContent = '';
      
      for (const fileName in zip.files) {
        const zipFile = zip.files[fileName];
        if (zipFile.name.endsWith('_cert.pem')) {
          certificateContent = await zipFile.async('string');
          await Preferences.set({ key: 'certificateContent', value: certificateContent });
        } else if (zipFile.name.endsWith('_key.pem')) {
          privateKeyContent = await zipFile.async('string');
          await Preferences.set({ key: 'privateKeyContent', value: privateKeyContent });
        }
      }

      await this.initializeAppData();

    } catch (error) {
      console.error('Fehler beim Importieren der Wallet:', error);
    }
  }


  async exportWalletCert() {
    try {
      const certificateContent = (await Preferences.get({ key: 'certificateContent' })).value;
      const privateKeyContent = (await Preferences.get({ key: 'privateKeyContent' })).value;
      
      if (!certificateContent || !privateKeyContent) {
        throw new Error('Zertifikats- oder Schlüsselinhalt fehlt. Export fehlgeschlagen.');
      }
  
      const zip = new JSZip();
      const certFileName = `${this.uuid}_cert.pem`;
      const keyFileName = `${this.password}_key.pem`;
  
      zip.file(certFileName, certificateContent);
      zip.file(keyFileName, privateKeyContent);
  
      const zipContent = await zip.generateAsync({ type: 'blob' });
  
      const base64Data = await this.convertBlobToBase64(zipContent);
      const zipFileName = `${this.uuid}.zip`;
      await Filesystem.writeFile({
        path: zipFileName,
        data: base64Data,
        directory: Directory.Documents,
      });
  
      console.log('Wallet-Zertifikat wurde erfolgreich exportiert und im Dokumente-Ordner gespeichert');
    } catch (error) {
      console.error('Fehler beim Exportieren der Wallet:', error);
    }
  }


  async generateCredentials() {
    this.uuid = uuidv4();
    this.password = this.generatePassword();
    await Preferences.set({ key: 'uuid', value: this.uuid });
    await Preferences.set({ key: 'password', value: this.password });
  }


  generatePassword(): string {
    // Simple generator, to be changed later
    return Math.random().toString(36).slice(-8);
  }


  async deleteData() {
    await Preferences.remove({ key: 'password' });
    await Preferences.remove({ key: 'certificateContent' });
    await Preferences.remove({ key: 'privateKeyContent' });

    this.uuid = null;
    this.password = null;
    this.owner = null;
    this.isRegistered = false;

    await this.initializeAppData();

  }

  // Utility function to convert Blob to Base64
  async convertBlobToBase64(blob: Blob): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => {
        const base64String = reader.result as string;
        const base64Data = base64String.split(',')[1]; // Strip off the data URL prefix
        resolve(base64Data);
      };
      reader.onerror = () => {
        reject(new Error('Fehler beim Konvertieren der Datei in Base64'));
      };
      reader.readAsDataURL(blob);
    });
  } 

}
  
