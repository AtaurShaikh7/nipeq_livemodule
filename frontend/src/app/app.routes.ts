import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () => import('./portfolio/portfolio.component').then(m => m.PortfolioComponent),
  },
  {
    path: 'showcase',
    loadComponent: () => import('./showcase/showcase.component').then(m => m.ShowcaseComponent),
  },
  { path: '**', redirectTo: '' },
];
