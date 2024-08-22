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
      {
        path: '',
        redirectTo: '/tabs/tab_sending',
        pathMatch: 'full',
      },
    ],
  },
  {
    path: '',
    redirectTo: '/tabs/tab_sending',
    pathMatch: 'full',
  },
];
