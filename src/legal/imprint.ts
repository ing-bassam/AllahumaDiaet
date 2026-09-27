import { CONTACT_EMAIL } from '../appInfo';

// Angaben für das Impressum (§ 5 DDG). Die Webseite nutzt dieselben Daten in docs/impressum.md.
export const IMPRINT = {
  name: 'Karim Abu Elkheir',
  street: 'Bergmannstraße 3',
  postalCodeAndCity: '10961 Berlin',
  country: 'Deutschland',
  email: CONTACT_EMAIL,
  // TODO: Telefonnummer bewusst nicht im öffentlichen Repository. Prüfen, ob sie nötig ist; sonst leer lassen.
  phone: null as string | null,
} as const;

const PAGES_BASE_URL = 'https://ing-bassam.github.io/AllahumaDiaet';

export const LEGAL_URLS = {
  // Werden über GitHub Pages aus dem Ordner docs/ veröffentlicht.
  privacyPolicy: `${PAGES_BASE_URL}/datenschutz.html`,
  imprint: `${PAGES_BASE_URL}/impressum.html`,
  support: `${PAGES_BASE_URL}/support.html`,
  openFoodFacts: 'https://world.openfoodfacts.org',
  odbl: 'https://opendatacommons.org/licenses/odbl/1.0/',
  ccBySa: 'https://creativecommons.org/licenses/by-sa/3.0/deed.de',
} as const;
