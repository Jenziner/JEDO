import { ComponentFixture, TestBed } from '@angular/core/testing';

import { TabAssetsPage } from './tab_assets.page';

describe('TabAssetsPage', () => {
  let component: TabAssetsPage;
  let fixture: ComponentFixture<TabAssetsPage>;

  beforeEach(async () => {
    fixture = TestBed.createComponent(TabAssetsPage);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
