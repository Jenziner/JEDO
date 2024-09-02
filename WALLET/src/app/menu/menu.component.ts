import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { IonMenu, IonHeader, IonToolbar, IonTitle, IonContent, IonList, IonItem, IonLabel, IonInput, IonButtons, IonButton, IonMenuButton, IonIcon, IonGrid, IonRow, IonCol, NavController } from '@ionic/angular/standalone';
import { FormsModule } from '@angular/forms';
import { Storage } from '@ionic/storage-angular';
import { v4 as uuidv4 } from 'uuid';

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
  ],
  providers: [Storage],
})

export class MenuComponent  implements OnInit {
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