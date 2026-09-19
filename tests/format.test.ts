import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { defaultMealType, formatDecimal, formatInt, localDateKey, parseDecimal, toInputText } from '../src/lib/format.ts';

describe('format', () => {
  it('formatiert Zahlen deutsch', () => {
    assert.equal(formatInt(2150), '2.150');
    assert.equal(formatInt(980), '980');
    assert.equal(formatDecimal(12.54), '12,5');
    assert.equal(formatDecimal(12), '12');
    // Tausenderpunkt auch mit Nachkommastelle, wie bei ganzen Zahlen.
    assert.equal(formatDecimal(1234.5), '1.234,5');
    assert.equal(formatDecimal(-1234.5), '-1.234,5');
    assert.equal(formatDecimal(999.96), '1.000');
  });

  it('liest Eingaben mit Komma und Punkt', () => {
    assert.equal(parseDecimal('12,5'), 12.5);
    assert.equal(parseDecimal('12.5'), 12.5);
    assert.equal(parseDecimal(''), null);
    assert.equal(parseDecimal(','), null);
    assert.equal(parseDecimal('abc'), null);
  });

  it('erzeugt Eingabetext, den parseDecimal wieder korrekt liest', () => {
    assert.equal(toInputText(1000), '1000');
    assert.equal(parseDecimal(toInputText(1000)), 1000);
    assert.equal(parseDecimal(toInputText(72.5)), 72.5);
  });

  it('nutzt das lokale Datum', () => {
    assert.equal(localDateKey(new Date(2026, 8, 15, 0, 30)), '2026-09-15');
  });

  it('schlägt die Mahlzeit nach Uhrzeit vor', () => {
    assert.equal(defaultMealType(new Date(2026, 8, 15, 7)), 'breakfast');
    assert.equal(defaultMealType(new Date(2026, 8, 15, 12)), 'lunch');
    assert.equal(defaultMealType(new Date(2026, 8, 15, 16)), 'snack');
    assert.equal(defaultMealType(new Date(2026, 8, 15, 19)), 'dinner');
    assert.equal(defaultMealType(new Date(2026, 8, 15, 23)), 'snack');
  });
});
