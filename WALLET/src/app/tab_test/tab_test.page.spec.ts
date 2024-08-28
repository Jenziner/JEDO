import { ComponentFixture, TestBed } from '@angular/core/testing';

import { TabTestPage } from './tab_test.page';

describe('TabTestPage', () => {
  let component: TabTestPage;
  let fixture: ComponentFixture<TabTestPage>;

  beforeEach(async () => {
    fixture = TestBed.createComponent(TabTestPage);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
