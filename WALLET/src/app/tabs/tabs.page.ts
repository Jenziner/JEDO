import { Component, EnvironmentInjector, inject, OnInit } from '@angular/core';
import { IonTabs, IonTabBar, IonTabButton, IonIcon, IonLabel } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { settings, wallet, send, camera, backspace, menu, triangle, ellipse } from 'ionicons/icons';
import { QRCodeModule } from 'angularx-qrcode';

@Component({
  selector: 'app-tabs',
  templateUrl: 'tabs.page.html',
  styleUrls: ['tabs.page.scss'],
  standalone: true,
  imports: [
    IonTabs, 
    IonTabBar, 
    IonTabButton, 
    IonIcon, 
    IonLabel,
    QRCodeModule,
  ],
})

export class TabsPage {
  public environmentInjector = inject(EnvironmentInjector);

  constructor() {
    addIcons({ settings, wallet, send, camera, backspace, menu, triangle, ellipse });
  }
}
