import { Component } from '@angular/core';
import { TranslateService, TranslateModule } from '@ngx-translate/core';
import { IonHeader, IonToolbar, IonTitle, IonContent, IonList, IonItem, IonLabel, IonButtons, IonButton, IonIcon } from '@ionic/angular/standalone';
import { ModalController } from '@ionic/angular';
import { CommonModule } from '@angular/common';


@Component({
  selector: 'app-language-selector',
  templateUrl: './language-selector.component.html',
  styleUrls: ['./language-selector.component.scss'],
  standalone: true,
  imports: [
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonList,
  IonItem,
  IonLabel,
  IonButtons,
  IonButton,
  IonIcon,
  TranslateModule,
  CommonModule,
]
})
export class LanguageSelectorComponent {
  languages = [
    { code: 'en', name: 'English', flag: 'flag' },
    { code: 'de', name: 'Deutsch', flag: 'flag' },
    // Weitere Sprachen hier hinzufügen
  ];

  constructor(private translate: TranslateService, private modalCtrl: ModalController) {}

  changeLanguage(languageCode: string) {
    this.translate.use(languageCode);
    this.modalCtrl.dismiss();
  }

  dismiss() {
    this.modalCtrl.dismiss();
  }
}