import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { IonicModule } from '@ionic/angular';
import { Storage } from '@ionic/storage-angular';
import { MenuComponent } from './menu/menu.component';
import { TabSendingPage } from './tab_sending/tab_sending.page';
@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  standalone: true,
  imports: [
    CommonModule,
    IonicModule,
    MenuComponent,
    TabSendingPage,
  ],
  providers: [Storage]
})

export class AppComponent {
    constructor(
      private storage: Storage,
    ) {
    this.initializeApp();
  }

  async initializeApp() {
    await this.storage.create(); 
  } 

}