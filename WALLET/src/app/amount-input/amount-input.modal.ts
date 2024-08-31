import { Component, Input } from '@angular/core';
import { ModalController, IonicModule } from '@ionic/angular';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-amount-input-modal',
  templateUrl: './amount-input.modal.html',
  styleUrls: ['./amount-input.modal.scss'],
  standalone: true,
  imports: [
    CommonModule, 
    IonicModule,  
  ]

})
export class AmountInputModal {
  @Input() initialAmount: string = '0.00';  
  amount: string;
  isFirstInput: boolean = true;

  constructor(private modalController: ModalController) {
    this.amount = this.initialAmount;
  }

  addNumber(num: string) {
    if (this.isFirstInput) {
      if (num === '.') {
        this.amount = '0.'; // Wenn der Benutzer mit einem Punkt beginnt, füge "0." ein
      } else {
        this.amount = num; // Leert den Betrag und fügt die erste Zahl hinzu
      }
      this.isFirstInput = false; // Setzt das Flag zurück, damit weitere Zahlen angehängt werden
    } else {
      if (num === '.' && this.amount.includes('.')) {
        return; // Ignoriere den Punkt, wenn bereits ein Punkt vorhanden ist
      }
      this.amount += num; // Füge die Zahl oder den Punkt hinzu
    }
  }

  removeLast() {
    this.amount = this.amount.slice(0, -1);    
    if (this.amount.length === 0) {
      this.amount = '0.00'; 
      this.isFirstInput = true; 
    }
  }

  confirmAmount() {
    this.modalController.dismiss(this.amount);
  }

  cancel() {
    this.modalController.dismiss(null);
  }
}
