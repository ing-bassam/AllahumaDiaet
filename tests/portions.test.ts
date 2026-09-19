import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { MAX_PORTION_G, portionPresets, validPortionGrams } from '../src/lib/portions.ts';

describe('portionPresets', () => {
  it('bietet die Packung zuerst an, wenn die Größe bekannt ist', () => {
    assert.deepEqual(
      portionPresets(250).map((p) => p.label),
      ['1 Packung (250 g)', '100 g', '1 Esslöffel (15 g)', '1 Teelöffel (5 g)'],
    );
    assert.equal(portionPresets(12.5)[0].label, '1 Packung (12,5 g)');
  });

  it('lässt die Packung ohne Größe weg', () => {
    assert.equal(portionPresets(null).length, 3);
    assert.equal(portionPresets(0).length, 3);
  });

  it('lässt eine Packung weg, die sich gar nicht speichern ließe', () => {
    // z. B. ein 6 × 1,5-l-Gebinde: Die Menge läge über der Obergrenze und „Speichern“ bliebe gesperrt.
    assert.equal(portionPresets(MAX_PORTION_G)[0].grams, MAX_PORTION_G);
    assert.equal(portionPresets(MAX_PORTION_G + 1).length, 3);
    assert.equal(portionPresets(Number.POSITIVE_INFINITY).length, 3);
  });
});

describe('validPortionGrams', () => {
  it('akzeptiert Mengen über 0 bis zur Obergrenze', () => {
    assert.equal(validPortionGrams(150), 150);
    assert.equal(validPortionGrams(MAX_PORTION_G), MAX_PORTION_G);
    assert.equal(validPortionGrams(0), null);
    assert.equal(validPortionGrams(MAX_PORTION_G + 1), null);
    assert.equal(validPortionGrams(null), null);
  });
});
