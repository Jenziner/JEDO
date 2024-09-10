import { Component, EnvironmentInjector, inject, OnInit } from '@angular/core';
import { IonTabs, IonTabBar, IonTabButton, IonIcon, IonLabel } from '@ionic/angular/standalone';
import { addIcons } from 'ionicons';
import { wallet, send, camera, backspace, menu } from 'ionicons/icons';
import { QRCodeModule } from 'angularx-qrcode';
import { Router } from '@angular/router';

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

  constructor(private router: Router) {
    addIcons({ wallet, send, camera, backspace, menu });
  }

  //used in DEBUG to open other tabs not shown in the tabs
  goToTab(tabName: string) {
    this.router.navigate([`/tabs/${tabName}`]);
  }
}
