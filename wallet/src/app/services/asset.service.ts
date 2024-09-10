import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class AssetService {
  private apiUrl = 'http://localhost:3000'; // URL zur REST-API

  constructor(private http: HttpClient) {}

  getAsset(assetId: string): Observable<any> {
    return this.http.get<any>(`${this.apiUrl}/asset/${assetId}`);
  }
}
