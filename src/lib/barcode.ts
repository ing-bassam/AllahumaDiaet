// Wandelt gescannte oder eingetippte Codes in eine einheitliche GTIN um,
// damit derselbe Artikel lokal immer unter demselben Schlüssel liegt.

const GTIN_LENGTHS = new Set([8, 12, 13, 14]);

export function hasValidCheckDigit(code: string): boolean {
  if (!/^\d+$/.test(code) || !GTIN_LENGTHS.has(code.length)) return false;
  const digits = code.split('').map(Number);
  const check = digits.pop()!;
  // Von rechts gewichtet: 3, 1, 3, 1, ...
  const sum = digits.reverse().reduce((acc, d, i) => acc + d * (i % 2 === 0 ? 3 : 1), 0);
  return (10 - (sum % 10)) % 10 === check;
}

function canonicalGtin(code: string): string {
  // UPC-A (12) und GTIN-14 mit führender Null auf EAN-13 bringen.
  if (code.length === 12) return `0${code}`;
  if (code.length === 14 && code.startsWith('0')) return code.slice(1);
  return code;
}

/**
 * Schreibt einen achtstelligen UPC-E (Zahlensystem, sechs Ziffern, Prüfziffer) zur zwölfstelligen
 * UPC-A aus. Die Prüfziffer gilt für die ausgeschriebene Form, nicht für die acht Ziffern.
 */
export function expandUpcE(code: string): string | null {
  if (!/^[01]\d{7}$/.test(code)) return null;
  const [system, d1, d2, d3, d4, d5, d6, check] = code;
  let body: string;
  if (d6 <= '2') body = `${d1}${d2}${d6}0000${d3}${d4}${d5}`;
  else if (d6 === '3') body = `${d1}${d2}${d3}00000${d4}${d5}`;
  else if (d6 === '4') body = `${d1}${d2}${d3}${d4}00000${d5}`;
  else body = `${d1}${d2}${d3}${d4}${d5}0000${d6}`;
  return `${system}${body}${check}`;
}

/**
 * Liefert die normalisierte GTIN oder `null`, wenn der Inhalt kein Produktcode ist.
 * Unterstützt reine Ziffern-Codes und QR-Codes im GS1-Digital-Link-Format
 * (z. B. https://id.gs1.org/01/04012345678901).
 *
 * `type` ist der vom Scanner gemeldete Barcode-Typ. Er ist nötig, weil ein UPC-E genauso acht
 * Ziffern hat wie eine EAN-8, aber anders geprüft wird.
 */
export function normalizeBarcode(raw: string, type?: string): string | null {
  const value = raw.trim();

  if (type === 'upc_e') {
    const upcA = expandUpcE(value);
    return upcA && hasValidCheckDigit(upcA) ? canonicalGtin(upcA) : null;
  }

  if (/^\d+$/.test(value)) {
    return hasValidCheckDigit(value) ? canonicalGtin(value) : null;
  }

  const digitalLink = value.match(/\/01\/(\d{14})(?:[/?#]|$)/);
  if (digitalLink && hasValidCheckDigit(digitalLink[1])) {
    return canonicalGtin(digitalLink[1]);
  }

  return null;
}
