import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  draftFromPer100g,
  draftToPer100g,
  EMPTY_DRAFT,
  isUsablePortion,
  mergeEditedFields,
  parseDraft,
  type NutrientDraft,
} from '../src/lib/nutritionDraft.ts';

const skyr = { calories: 63, protein: 11, carbs: 4, fat: 0.2 };

describe('nutritionDraft', () => {
  it('zeigt Werte pro 100 g mit Komma', () => {
    assert.deepEqual(draftFromPer100g(skyr, 'per100g', null), { calories: '63', protein: '11', carbs: '4', fat: '0,2' });
  });

  it('zeigt Werte pro Portion', () => {
    assert.deepEqual(draftFromPer100g(skyr, 'portion', 250), { calories: '158', protein: '27,5', carbs: '10', fat: '0,5' });
  });

  it('fällt ohne Portionsgröße auf pro 100 g zurück', () => {
    assert.deepEqual(draftFromPer100g(skyr, 'portion', null), draftFromPer100g(skyr, 'per100g', null));
  });

  it('liest vollständige Felder und lehnt unvollständige ab', () => {
    assert.deepEqual(parseDraft({ calories: '63', protein: '11', carbs: '4', fat: '0,2' }), skyr);
    assert.equal(parseDraft({ ...EMPTY_DRAFT, calories: '63' }), null);
  });

  it('rechnet Portionswerte auf 100 g um', () => {
    assert.deepEqual(draftToPer100g({ calories: '50', protein: '5', carbs: '2,5', fat: '1' }, 'portion', 50), {
      calories: 100,
      protein: 10,
      carbs: 5,
      fat: 2,
    });
    assert.equal(draftToPer100g({ calories: '50', protein: '5', carbs: '2,5', fat: '1' }, 'portion', 0), null);
  });

  it('prüft Portionsgrößen', () => {
    assert.equal(isUsablePortion(30), true);
    assert.equal(isUsablePortion(0), false);
    assert.equal(isUsablePortion(null), false);
  });
});

describe('mergeEditedFields', () => {
  const stored = { calories: 63, protein: 11.37, carbs: 4, fat: 0.2 };
  const edited = (...fields: (keyof NutrientDraft)[]) => new Set(fields);

  it('lässt unbearbeitete Felder unverändert, auch wenn die Anzeige pro Portion gerundet ist', () => {
    // Pro 30 g zeigt das Fettfeld „0,1“. Zurückgerechnet wären das 0,33 g statt der gespeicherten 0,2 g.
    const draft = { ...draftFromPer100g(stored, 'portion', 30), calories: '21' };
    const parsed = draftToPer100g(draft, 'portion', 30);
    assert.ok(parsed);
    assert.deepEqual(mergeEditedFields(stored, parsed, edited('calories')), { ...stored, calories: 70 });
  });

  it('übernimmt alle bearbeiteten Felder', () => {
    const parsed = { calories: 70, protein: 12, carbs: 5, fat: 0.3 };
    assert.deepEqual(mergeEditedFields(stored, parsed, edited('calories', 'fat')), { ...stored, calories: 70, fat: 0.3 });
  });

  it('nimmt ohne Ausgangswerte die Feldwerte', () => {
    const parsed = { calories: 52, protein: 0.3, carbs: 14, fat: 0.2 };
    assert.deepEqual(mergeEditedFields(null, parsed, edited('calories')), parsed);
  });
});
