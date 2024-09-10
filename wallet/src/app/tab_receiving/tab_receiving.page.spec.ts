import { ComponentFixture, TestBed } from '@angular/core/testing';

import { TabReceivingPage } from './tab_receiving.page';

describe('TabReceivingPage', () => {
  let component: TabReceivingPage;
  let fixture: ComponentFixture<TabReceivingPage>;

  beforeEach(async () => {
    fixture = TestBed.createComponent(TabReceivingPage);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
