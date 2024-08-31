import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { QRCodeModule } from 'angularx-qrcode';
import { IonicModule, MenuController, ModalController } from '@ionic/angular';
import { Storage } from '@ionic/storage-angular';
import { AmountInputModal } from '../amount-input/amount-input.modal';


@Component({
  selector: 'app-tab-receiving',
  templateUrl: 'tab_receiving.page.html',
  styleUrls: ['tab_receiving.page.scss'],
  standalone: true,
  imports: [
    CommonModule,
    QRCodeModule,
    IonicModule
  ],
  providers: [Storage],
})

export class TabReceivingPage {
  uuid: string | null = null;
  amount: string | null = null;

  constructor(
    private menu: MenuController, 
    private storage: Storage,
    private modalController: ModalController,
  ) {
    this.initializeApp();
  }

  async ionViewWillEnter() {
    this.uuid = await this.storage.get('uuid');

    if (!this.uuid) {
      this.openMenu();
    } else {
      this.presentAmountInputModal(); 
    }
  }

  async openMenu() {
    const isMenuOpen = await this.menu.isOpen('main-menu');
    console.log('Is menu already open?', isMenuOpen);
    if (!isMenuOpen) {
      await this.menu.open('main-menu');
      console.log('Menu should now be open');
    }
  }

  async presentAmountInputModal() {
    const modal = await this.modalController.create({
      component: AmountInputModal,
      componentProps: { initialAmount: this.amount }
    });

    modal.onDidDismiss().then((result) => {
      if (result.data) {
        this.amount = result.data;
      }
    });

    return await modal.present();
  }

  async initializeApp() {
    await this.storage.create();
  }

}
