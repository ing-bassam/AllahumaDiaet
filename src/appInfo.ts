import Constants from 'expo-constants';

import { buildUserAgent } from './lib/openFoodFacts';

// Anzeigename und Version kommen aus app.json, damit sie nur an einer Stelle gepflegt werden.
export const APP_NAME = Constants.expoConfig?.name ?? 'Hachibu';
export const APP_VERSION = Constants.expoConfig?.version ?? '1.0.0';

export const CONTACT_EMAIL = 'abdel.abu99@gmail.com';

/** Kennung gegenüber Open Food Facts; bewusst unabhängig vom Anzeigenamen. */
const API_CLIENT_NAME = 'AllahumaDiaet';

export const USER_AGENT = buildUserAgent(API_CLIENT_NAME, APP_VERSION, CONTACT_EMAIL);
