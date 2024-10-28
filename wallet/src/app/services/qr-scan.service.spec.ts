import { TestBed } from '@angular/core/testing';

import { QrScanService } from './qr-scan.service';

describe('QrScanService', () => {
  let service: QrScanService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(QrScanService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });
});
