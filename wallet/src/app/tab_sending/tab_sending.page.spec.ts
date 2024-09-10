import { ComponentFixture, TestBed } from '@angular/core/testing';

import { TabSendingPage } from './tab_sending.page';

describe('TabSendingPage', () => {
  let component: TabSendingPage;
  let fixture: ComponentFixture<TabSendingPage>;

  beforeEach(async () => {
    fixture = TestBed.createComponent(TabSendingPage);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
