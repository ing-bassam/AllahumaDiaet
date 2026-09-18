// Quellen für die Berechnungen in der App. Sie stehen im Screen „Info & Rechtliches“ und werden
// im Onboarding genannt, damit nachvollziehbar ist, woher die Werte stammen (App-Store-Richtlinie 1.4.1).

export type Source = {
  title: string;
  /** Vollständige Fundstelle, so wie sie in der App steht. */
  detail: string;
  url: string;
};

/** Kurzbeschreibung des Rechenwegs, wie er in src/lib/nutrition.ts umgesetzt ist. */
export const CALCULATION_STEPS = [
  'Grundumsatz nach Mifflin-St. Jeor: 10 × Gewicht in kg + 6,25 × Größe in cm − 5 × Alter, dann + 5 bei Männern und − 161 bei Frauen.',
  'Gesamtumsatz: Grundumsatz × PAL-Faktor deines Aktivitätslevels (1,4 bis 2,3).',
  'Tagesziel: Gesamtumsatz − 500 kcal beim Abnehmen, + 300 kcal beim Zunehmen, sonst der Gesamtumsatz. Das Ziel liegt nie unter deinem Grundumsatz.',
  'Makronährstoffe: Anteil am Tagesziel, umgerechnet mit 4 kcal je Gramm Protein und Kohlenhydrate und 9 kcal je Gramm Fett.',
];

export const CALCULATION_SOURCES: Source[] = [
  {
    title: 'Grundumsatz',
    detail:
      'Mifflin MD, St Jeor ST, Hill LA, Scott BJ, Daugherty SA, Koh YO: A new predictive equation for resting energy expenditure in healthy individuals. The American Journal of Clinical Nutrition 1990;51(2):241–247.',
    url: 'https://doi.org/10.1093/ajcn/51.2.241',
  },
  {
    title: 'Aktivitätsfaktor (PAL)',
    detail:
      'Deutsche Gesellschaft für Ernährung: Referenzwerte für die Energiezufuhr. PAL-Werte reichen von 1,2 bei ausschließlich sitzender Lebensweise bis 2,4 bei körperlich sehr anstrengender Arbeit.',
    url: 'https://www.dge.de/wissenschaft/referenzwerte/energie/',
  },
  {
    title: 'Energiedefizit beim Abnehmen',
    detail:
      'S3-Leitlinie „Prävention und Therapie der Adipositas“ (Deutsche Adipositas-Gesellschaft und weitere Fachgesellschaften, Fassung 2024, AWMF-Register 050-001): empfohlen wird ein tägliches Defizit von etwa 500 kcal.',
    url: 'https://register.awmf.org/de/leitlinien/detail/050-001',
  },
  {
    title: 'Umrechnung der Nährwerte',
    detail:
      'Verordnung (EU) Nr. 1169/2011 über die Information der Verbraucher über Lebensmittel, Anhang XIV: 4 kcal je Gramm Protein und Kohlenhydrate, 9 kcal je Gramm Fett.',
    url: 'https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=CELEX:32011R1169',
  },
];

export const MEDICAL_DISCLAIMER =
  'Die Berechnungen sind Richtwerte für gesunde Erwachsene und ersetzen keine ärztliche oder ernährungsfachliche Beratung. Bei Erkrankungen, in Schwangerschaft und Stillzeit oder bei Beschwerden sprich bitte mit deiner Ärztin oder deinem Arzt.';
