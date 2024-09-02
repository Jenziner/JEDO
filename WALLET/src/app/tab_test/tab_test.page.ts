import { Component, OnInit } from '@angular/core';


// for Fabric API Test
import { AssetService } from '../services/asset.service';
import { CommonModule } from '@angular/common';
import { IonicModule } from '@ionic/angular';

@Component({
  selector: 'app-tab-test',
  templateUrl: 'tab_test.page.html',
  styleUrls: ['tab_test.page.scss'],
  standalone: true,
  imports: [CommonModule, IonicModule]
})


export class TabTestPage implements OnInit {
//  asset: any;

//  constructor(private assetService: AssetService) {}
constructor() {}

  ngOnInit() {
    console.log('TabTestPage loaded');
//    this.loadAsset('asset1'); // Beispiel für das Laden eines bestimmten Assets
  }

//  loadAsset(assetId: string) {
//    this.assetService.getAsset(assetId).subscribe(
//      (data) => {
//        console.log('Asset loaded:', data);
//        this.asset = data;
//      },
//      (error) => {
//        console.error('Error loading asset', error);
//      }
//    );
//  }
}
