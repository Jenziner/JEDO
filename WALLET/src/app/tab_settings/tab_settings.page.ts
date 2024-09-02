import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { IonHeader, IonToolbar, IonTitle, IonContent, IonList, IonItem, IonLabel, IonInput, IonButtons, IonButton, IonIcon } from '@ionic/angular/standalone';
import { Storage } from '@ionic/storage-angular';
import { v4 as uuidv4 } from 'uuid';

@Component({
  selector: 'app-tab-settings',
  templateUrl: 'tab_settings.page.html',
  styleUrls: ['tab_settings.page.scss'],
  standalone: true,
  imports: [
    CommonModule,
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
    IonIcon,
    FormsModule,
  ],
  providers: [Storage],
})

export class TabSettingsPage {
  uuid: string | null = null;
  password: string | null = null;
  isGenerated: boolean = false;
  isImportMode: boolean = false;

  constructor(private storage: Storage) { 
    this.init();
  }

  async init() {
    await this.storage.create();
  }

  async ngOnInit() {
    this.uuid = await this.storage.get('uuid');
    this.password = await this.storage.get('password');
    this.isGenerated = !!this.uuid;
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

}
