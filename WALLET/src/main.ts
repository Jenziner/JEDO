import { bootstrapApplication } from '@angular/platform-browser';
import { RouteReuseStrategy, provideRouter, withPreloading, PreloadAllModules } from '@angular/router';
import { IonicRouteStrategy, provideIonicAngular } from '@ionic/angular/standalone';

import { routes } from './app/app.routes';
import { AppComponent } from './app/app.component';

import { provideHttpClient, HttpClient } from '@angular/common/http';
import { TranslateLoader, TranslateService, TranslateStore,TranslateCompiler, TranslateParser, TranslateDefaultParser, MissingTranslationHandler, FakeMissingTranslationHandler, USE_DEFAULT_LANG, USE_STORE, USE_EXTEND, DEFAULT_LANGUAGE } from '@ngx-translate/core';
import { TranslateHttpLoader } from '@ngx-translate/http-loader';
import { TranslateMessageFormatCompiler } from 'ngx-translate-messageformat-compiler';



export function HttpLoaderFactory(http: HttpClient) {
  return new TranslateHttpLoader(http, './assets/i18n/', '.json');
}

bootstrapApplication(AppComponent, {
  providers: [
    { provide: RouteReuseStrategy, useClass: IonicRouteStrategy },
    provideIonicAngular(),
    provideRouter(routes, withPreloading(PreloadAllModules)),
    provideHttpClient(), 
    {
      provide: TranslateLoader,
      useFactory: HttpLoaderFactory,
      deps: [HttpClient]
    },
    TranslateService,
    TranslateStore,
    {
      provide: TranslateCompiler,
      useClass: TranslateMessageFormatCompiler, 
    },
    {
      provide: TranslateParser,
      useClass: TranslateDefaultParser, 
    },  
    {
      provide: MissingTranslationHandler,
      useClass: FakeMissingTranslationHandler, 
    },
    {
      provide: USE_DEFAULT_LANG,
      useValue: true, 
    },
    {
      provide: USE_STORE,
      useValue: true, 
    },
    {
      provide: USE_EXTEND,
      useValue: true, 
    },
    {
      provide: DEFAULT_LANGUAGE,
      useValue: 'en', 
    },
  ],
}).then(appRef => {
  const translate = appRef.injector.get(TranslateService);
  translate.setDefaultLang('en');
  
  const browserLang = translate.getBrowserLang() || 'en';
  translate.use(browserLang.match(/en|de|fr/) ? browserLang : 'en');
}).catch(err => console.error(err));