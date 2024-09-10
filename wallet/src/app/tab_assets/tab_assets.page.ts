import { Component, OnInit } from '@angular/core';
//import { IonHeader, IonToolbar, IonTitle, IonContent, IonButton } from '@ionic/angular/standalone';

// for Fabric API Test
import { AssetService } from '../services/asset.service';
//import { provideHttpClient } from '@angular/common/http';
import { HttpClientModule } from '@angular/common/http';
//import { CommonModule } from '@angular/common';
import { IonicModule } from '@ionic/angular';

@Component({
  selector: 'app-tab-assets',
  templateUrl: 'tab_assets.page.html',
  styleUrls: ['tab_assets.page.scss'],
  standalone: true,
  imports: [IonicModule, HttpClientModule],
  providers: [ AssetService],
})
export class TabAssetsPage implements OnInit {
  asset: any;

//  constructor() {}
  constructor(private assetService: AssetService) {}

  ngOnInit() {
    console.log('TabAssetsPage loaded');
    this.loadAsset('asset1'); // Beispiel für das Laden eines bestimmten Assets
  }

  loadAsset(assetId: string) {
    this.assetService.getAsset(assetId).subscribe(
      (data) => {
        console.log('Asset loaded:', data);
        this.asset = data;
      },
      (error) => {
        console.error('Error loading asset', error);
      }
    );
  }
}
