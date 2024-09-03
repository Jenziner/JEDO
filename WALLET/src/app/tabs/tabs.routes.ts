import { Routes } from '@angular/router';
import { TabsPage } from './tabs.page';

export const routes: Routes = [
  {
    path: 'tabs',
    component: TabsPage,
    children: [
      {
        path: 'tab_sending',
        loadComponent: () =>
          import('../tab_sending/tab_sending.page').then((m) => m.TabSendingPage),
      },
      {
        path: 'tab_receiving',
        loadComponent: () =>
          import('../tab_receiving/tab_receiving.page').then((m) => m.TabReceivingPage),
      }, 
      // tab_test and tab_assets are DEBUG only
      {
        path: 'tab_test',
        loadComponent: () =>
          import('../tab_test/tab_test.page').then((m) => m.TabTestPage),
      },
      {
        path: 'tab_assets',
        loadComponent: () =>
          import('../tab_assets/tab_assets.page').then((m) => m.TabAssetsPage),
      },
      {
        path: '',
        redirectTo: 'tab_sending',
        pathMatch: 'full',
      },
    ],
  },
  {
    path: '',
    redirectTo: '/tabs',
    pathMatch: 'full',
  },
];
