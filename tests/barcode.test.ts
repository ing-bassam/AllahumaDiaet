import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { expandUpcE, hasValidCheckDigit, normalizeBarcode } from '../src/lib/barcode.ts';

describe('hasValidCheckDigit', () => {
  it('akzeptiert gültige EAN-13 und EAN-8', () => {
    assert.equal(hasValidCheckDigit('4006381333931'), true);
    assert.equal(hasValidCheckDigit('96385074'), true);
  });

  it('lehnt Tippfehler ab', () => {
    assert.equal(hasValidCheckDigit('4006381333932'), false);
    assert.equal(hasValidCheckDigit('12345'), false);
  });
});

describe('expandUpcE', () => {
  it('deckt alle vier Kompressionsregeln ab', () => {
    assert.equal(expandUpcE('04252614'), '042100005264'); // letzte Ziffer 0–2
    assert.equal(expandUpcE('01234133'), '012300000413'); // 3
    assert.equal(expandUpcE('01234145'), '012340000015'); // 4
    assert.equal(expandUpcE('01234565'), '012345000065'); // 5–9
  });

  it('lehnt alles ab, was kein achtstelliger UPC-E ist', () => {
    assert.equal(expandUpcE('425261'), null);
    assert.equal(expandUpcE('24252614'), null);
  });
});

describe('normalizeBarcode', () => {
  it('lässt EAN-13 unverändert', () => {
    assert.equal(normalizeBarcode(' 4006381333931 '), '4006381333931');
  });

  it('macht aus UPC-A eine EAN-13', () => {
    assert.equal(normalizeBarcode('036000291452'), '0036000291452');
  });

  it('entfernt die führende Null einer GTIN-14', () => {
    assert.equal(normalizeBarcode('04006381333931'), '4006381333931');
  });

  it('liest GS1-Digital-Link-QR-Codes', () => {
    assert.equal(normalizeBarcode('https://id.gs1.org/01/04006381333931/10/ABC123'), '4006381333931');
    assert.equal(normalizeBarcode('https://example.com/01/04006381333931?x=1'), '4006381333931');
  });

  it('schreibt UPC-E zur UPC-A aus, statt ihn als EAN-8 zu prüfen', () => {
    // Als EAN-8 gelesen hätten die ersten beiden eine falsche Prüfziffer und würden abgewiesen.
    assert.equal(normalizeBarcode('04252614', 'upc_e'), '0042100005264');
    assert.equal(normalizeBarcode('01201303', 'upc_e'), '0012000000133');
    // Dieser ginge zufällig auch als EAN-8 durch, läge dann aber unter einem anderen Schlüssel
    // als der UPC-A-Code desselben Produkts.
    assert.equal(normalizeBarcode('04904403', 'upc_e'), '0049000000443');
    assert.equal(normalizeBarcode('04252615', 'upc_e'), null);
  });

  it('lässt EAN-8 ohne Typangabe unverändert', () => {
    assert.equal(normalizeBarcode('96385074'), '96385074');
    assert.equal(normalizeBarcode('96385074', 'ean8'), '96385074');
  });

  it('ignoriert QR-Codes ohne Produktnummer', () => {
    assert.equal(normalizeBarcode('https://example.com/gewinnspiel'), null);
    assert.equal(normalizeBarcode('4006381333932'), null);
  });
});
