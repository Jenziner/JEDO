import { Component } from '@angular/core';
import { IonApp, IonRouterOutlet } from '@ionic/angular/standalone';
import { MenuComponent } from './menu/menu.component';
import { TabSendingPage } from './tab_sending/tab_sending.page';


@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  standalone: true,
  imports: [IonApp, IonRouterOutlet,MenuComponent,TabSendingPage],
})


export class AppComponent {
  constructor() {}

}
