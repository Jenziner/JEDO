import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { IonicModule } from '@ionic/angular';
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
    TabSendingPage
  ],
})

export class AppComponent {
  constructor() {}

}