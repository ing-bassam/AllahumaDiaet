import { randomUUID } from 'expo-crypto';
import { useFocusEffect, useLocalSearchParams, useRouter } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, FlatList, Image, Keyboard, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { USER_AGENT } from '../appInfo';
import { Icon } from '../components/Icon';
import { PrimaryButton } from '../components/PrimaryButton';
import { getFoodItemsByKeys, getFrequentFoods, getRecentFoods, searchLocalFoods, type FoodItem } from '../db/repository';
import { newCustomFoodKey } from '../lib/foodKey';
import { formatInt } from '../lib/format';
import { MIN_LOCAL_QUERY_LENGTH } from '../lib/localSearch';
import { hitKey, SEARCH_RATE_LIMIT, searchProducts, type SearchHit, type SearchResult } from '../lib/openFoodFacts';
import { createRateLimiter } from '../lib/rateLimiter';
import { rememberSearchHit } from '../lib/searchHandoff';
import { colors, radius, spacing } from '../theme';

const LOCAL_LIMIT = 20;
const SUGGESTION_LIMIT = 8;

// Ein Limiter für die ganze App-Sitzung, auch wenn der Screen mehrfach geöffnet wird.
const searchLimiter = createRateLimiter(SEARCH_RATE_LIMIT.limit, SEARCH_RATE_LIMIT.windowMs);

type OnlineState = {
  query: string;
  scope: 'germany' | 'world';
  hits: SearchHit[];
  page: number;
  pageCount: number;
  status: 'idle' | 'loading' | 'loadingMore' | 'done' | 'error';
  /** Fehlermeldung der letzten Anfrage. */
  error: string | null;
  /** Hinweis, z. B. dass weltweit statt nur in Deutschland gesucht wurde. */
  notice: string | null;
};

const IDLE: OnlineState = { query: '', scope: 'germany', hits: [], page: 0, pageCount: 0, status: 'idle', error: null, notice: null };

type Row =
  | { type: 'header'; key: string; title: string }
  | { type: 'food'; key: string; food: FoodItem }
  | { type: 'hit'; key: string; hit: SearchHit }
  | { type: 'status'; key: string; text: string; tone: 'muted' | 'error'; loading?: boolean }
  | { type: 'action'; key: string; label: string; onPress: () => void }
  | { type: 'create'; key: string; label: string };

function messageFor(result: Exclude<SearchResult, { status: 'ok' }>): string {
  switch (result.status) {
    case 'rate_limited':
      return result.retryAfterSeconds
        ? `Zu viele Suchanfragen in kurzer Zeit. Bitte in ${result.retryAfterSeconds} Sekunden erneut versuchen.`
        : 'Zu viele Suchanfragen in kurzer Zeit. Bitte kurz warten und erneut versuchen.';
    case 'timeout':
      return 'Die Suche hat zu lange gedauert. Bitte erneut versuchen.';
    case 'offline':
      return 'Keine Internetverbindung. Lokale Treffer und eigene Lebensmittel funktionieren trotzdem.';
    case 'unavailable':
      return 'Open Food Facts ist gerade nicht erreichbar. Bitte später erneut versuchen.';
  }
}

export default function SearchScreen() {
  const db = useSQLiteContext();
  const router = useRouter();
  const insets = useSafeAreaInsets();
  // Tag, auf den ausgewählte Lebensmittel gebucht werden (aus der Startseite).
  const { date } = useLocalSearchParams<{ date?: string }>();

  const [query, setQuery] = useState('');
  const [recent, setRecent] = useState<FoodItem[]>([]);
  const [frequent, setFrequent] = useState<FoodItem[]>([]);
  const [localResults, setLocalResults] = useState<FoodItem[]>([]);
  const [online, setOnline] = useState<OnlineState>(IDLE);
  const [onlineLocal, setOnlineLocal] = useState<Record<string, FoodItem>>({});

  const trimmed = query.trim();
  const queryRef = useRef(trimmed);
  queryRef.current = trimmed;
  const onlineHitsRef = useRef(online.hits);
  onlineHitsRef.current = online.hits;
  // Zählt die Online-Suchen. Der Suchbegriff allein reicht nicht: Wer ihn ändert, zurückändert und
  // erneut sucht, hat zwei laufende Anfragen zum selben Begriff, und die ältere darf nicht gewinnen.
  const searchRun = useRef(0);

  // Vorschläge ohne Eingabe – bei jedem Fokus neu, damit gerade eingetragene Lebensmittel oben stehen.
  useFocusEffect(
    useCallback(() => {
      Promise.all([getRecentFoods(db, SUGGESTION_LIMIT), getFrequentFoods(db, SUGGESTION_LIMIT)]).then(([r, f]) => {
        setRecent(r);
        setFrequent(f);
      });
      // Nach der Rückkehr vom Produkt-Screen: dort korrigierte oder gespeicherte Online-Treffer mit
      // ihren lokalen Werten zeigen.
      const q = queryRef.current;
      const keys = onlineHitsRef.current.map(hitKey);
      if (keys.length > 0) {
        getFoodItemsByKeys(db, keys).then((locals) => {
          if (queryRef.current !== q) return;
          setOnlineLocal((prev) => ({ ...prev, ...Object.fromEntries(locals.map((food) => [food.barcode, food])) }));
        });
      }
    }, [db]),
  );

  // Lokale Treffer sofort beim Tippen (ab 2 Zeichen) und bei jedem Fokus neu: Der Produkt-Screen kann
  // food_item geändert haben, ohne dass sich der Suchbegriff ändert. useFocusEffect läuft auch dann
  // erneut, wenn sich bei fokussiertem Screen der Callback ändert, also bei jedem neuen Suchbegriff.
  useFocusEffect(
    useCallback(() => {
      if (trimmed.length < MIN_LOCAL_QUERY_LENGTH) {
        setLocalResults([]);
        return;
      }
      let cancelled = false;
      searchLocalFoods(db, trimmed, LOCAL_LIMIT).then((items) => {
        if (!cancelled) setLocalResults(items);
      });
      return () => {
        cancelled = true;
      };
    }, [db, trimmed]),
  );

  // Online-Ergebnisse gehören zu genau einem Suchbegriff.
  useEffect(() => {
    if (online.status !== 'idle' && online.query !== trimmed) {
      setOnline(IDLE);
      setOnlineLocal({});
    }
  }, [trimmed, online.query, online.status]);

  const runOnlineSearch = async (page: number) => {
    const q = trimmed;
    if (q.length < MIN_LOCAL_QUERY_LENGTH) return;
    if (page === 1) Keyboard.dismiss();

    const run = ++searchRun.current;
    const isStale = () => searchRun.current !== run || queryRef.current !== q;
    const scope = page === 1 ? 'germany' : online.scope;
    setOnline((prev) => (page === 1 ? { ...IDLE, query: q, status: 'loading' } : { ...prev, status: 'loadingMore', error: null }));

    const { result, scope: usedScope } = await searchProducts({ query: q, page, scope }, USER_AGENT, () => searchLimiter.tryAcquire());
    if (isStale()) return;

    if (result.status !== 'ok') {
      const error = messageFor(result);
      setOnline((prev) => ({ ...prev, status: page === 1 ? 'error' : 'done', error }));
      return;
    }

    // Lokal vorhandene Produkte gewinnen: Ihre gespeicherten (ggf. korrigierten) Werte werden angezeigt.
    const locals = await getFoodItemsByKeys(db, result.page.hits.map(hitKey));
    if (isStale()) return;
    const localMap = Object.fromEntries(locals.map((food) => [food.barcode, food]));

    setOnlineLocal((prev) => (page === 1 ? localMap : { ...prev, ...localMap }));
    setOnline((prev) => {
      const existing = page === 1 ? [] : prev.hits;
      const known = new Set(existing.map(hitKey));
      return {
        query: q,
        scope: usedScope,
        hits: [...existing, ...result.page.hits.filter((hit) => !known.has(hitKey(hit)))],
        page: result.page.page,
        pageCount: result.page.pageCount,
        status: 'done',
        error: null,
        notice: page === 1 ? (usedScope === 'world' ? 'Keine Treffer aus Deutschland – Ergebnisse weltweit.' : null) : prev.notice,
      };
    });
  };

  const openFood = (key: string) =>
    router.push({ pathname: '/product/[barcode]', params: { barcode: key, ...(date ? { date } : null) } });

  const openHit = (hit: SearchHit) => {
    const key = hitKey(hit);
    rememberSearchHit(key, hit);
    openFood(key);
  };

  const createCustomFood = () => {
    router.push({
      pathname: '/product/[barcode]',
      params: { barcode: newCustomFoodKey(randomUUID()), name: trimmed, ...(date ? { date } : null) },
    });
  };

  const rows = useMemo<Row[]>(() => {
    const list: Row[] = [];
    const foods = (prefix: string, items: FoodItem[]) => items.forEach((food) => list.push({ type: 'food', key: `${prefix}-${food.barcode}`, food }));

    if (trimmed.length === 0) {
      if (recent.length === 0 && frequent.length === 0) {
        list.push({ type: 'status', key: 'no-history', text: 'Hier erscheinen deine zuletzt verwendeten und häufig gegessenen Lebensmittel.', tone: 'muted' });
      }
      if (recent.length > 0) {
        list.push({ type: 'header', key: 'h-recent', title: 'Zuletzt verwendet' });
        foods('recent', recent);
      }
      if (frequent.length > 0) {
        list.push({ type: 'header', key: 'h-frequent', title: 'Häufig gegessen' });
        foods('frequent', frequent);
      }
    } else if (trimmed.length < MIN_LOCAL_QUERY_LENGTH) {
      list.push({ type: 'status', key: 'too-short', text: 'Mindestens 2 Zeichen eingeben.', tone: 'muted' });
    } else {
      list.push({ type: 'header', key: 'h-local', title: 'Auf deinem Gerät' });
      if (localResults.length === 0) list.push({ type: 'status', key: 'local-empty', text: 'Keine gespeicherten Treffer.', tone: 'muted' });
      foods('local', localResults);

      list.push({ type: 'header', key: 'h-online', title: 'Open Food Facts' });
      const localKeys = new Set(localResults.map((food) => food.barcode));

      if (online.status === 'idle') {
        list.push({ type: 'action', key: 'online-search', label: 'Online suchen', onPress: () => runOnlineSearch(1) });
      } else if (online.status === 'loading') {
        list.push({ type: 'status', key: 'online-loading', text: 'Suche bei Open Food Facts …', tone: 'muted', loading: true });
      } else if (online.status === 'error') {
        list.push({ type: 'status', key: 'online-error', text: online.error ?? '', tone: 'error' });
        list.push({ type: 'action', key: 'online-retry', label: 'Erneut versuchen', onPress: () => runOnlineSearch(1) });
      } else {
        if (online.notice) list.push({ type: 'status', key: 'online-notice', text: online.notice, tone: 'muted' });
        let shown = 0;
        for (const hit of online.hits) {
          const key = hitKey(hit);
          if (localKeys.has(key)) continue; // steht schon oben
          const local = onlineLocal[key];
          list.push(local ? { type: 'food', key: `online-local-${key}`, food: local } : { type: 'hit', key: `online-${key}`, hit });
          shown++;
        }
        if (online.hits.length === 0) {
          list.push({ type: 'status', key: 'online-empty', text: 'Keine Treffer bei Open Food Facts.', tone: 'muted' });
        } else if (shown === 0) {
          list.push({ type: 'status', key: 'online-dupes', text: 'Alle Treffer sind schon auf deinem Gerät gespeichert.', tone: 'muted' });
        }
        if (online.error) list.push({ type: 'status', key: 'online-more-error', text: online.error, tone: 'error' });
        if (online.status === 'loadingMore') {
          list.push({ type: 'status', key: 'online-more-loading', text: 'Weitere Treffer werden geladen …', tone: 'muted', loading: true });
        } else if (online.page < online.pageCount) {
          list.push({ type: 'action', key: 'online-more', label: 'Mehr laden', onPress: () => runOnlineSearch(online.page + 1) });
        }
      }
    }

    list.push({
      type: 'create',
      key: 'create',
      label: trimmed.length > 0 ? `„${trimmed}“ als eigenes Lebensmittel anlegen` : 'Eigenes Lebensmittel anlegen',
    });
    return list;
    // runOnlineSearch hängt nur von trimmed, online und db ab und wird daher mit diesen Werten neu gebunden.
  }, [trimmed, recent, frequent, localResults, online, onlineLocal]);

  const renderRow = ({ item }: { item: Row }) => {
    switch (item.type) {
      case 'header':
        return <Text style={styles.sectionTitle}>{item.title}</Text>;
      case 'food':
        return (
          <ResultRow
            name={item.food.name}
            brand={item.food.brand}
            caloriesPer100g={item.food.caloriesPer100g}
            imageUrl={item.food.imageUrl}
            onPress={() => openFood(item.food.barcode)}
          />
        );
      case 'hit':
        return item.hit.status === 'found' ? (
          <ResultRow
            name={item.hit.product.name}
            brand={item.hit.product.brand}
            caloriesPer100g={item.hit.product.caloriesPer100g}
            imageUrl={item.hit.product.imageUrl}
            onPress={() => openHit(item.hit)}
          />
        ) : (
          <ResultRow
            name={item.hit.partial.name || 'Unbenanntes Produkt'}
            brand={item.hit.partial.brand}
            caloriesPer100g={null}
            imageUrl={item.hit.partial.imageUrl}
            onPress={() => openHit(item.hit)}
          />
        );
      case 'status':
        return (
          <View style={styles.statusRow}>
            {item.loading && <ActivityIndicator color={colors.primary} />}
            <Text style={[styles.statusText, item.tone === 'error' && styles.errorText]}>{item.text}</Text>
          </View>
        );
      case 'action':
        return <PrimaryButton label={item.label} variant="secondary" onPress={item.onPress} style={styles.action} />;
      case 'create':
        return (
          <Pressable onPress={createCustomFood} style={styles.createRow} accessibilityRole="button">
            <Icon name="plus" color={colors.primary} size={20} />
            <Text style={styles.createText}>{item.label}</Text>
          </Pressable>
        );
    }
  };

  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} hitSlop={12} accessibilityLabel="Zurück" style={styles.backButton}>
          <Icon name="chevronLeft" color={colors.text} />
        </Pressable>
        <View style={styles.inputWrap}>
          <Icon name="search" color={colors.textMuted} size={20} />
          <TextInput
            value={query}
            onChangeText={setQuery}
            autoFocus
            placeholder="Lebensmittel suchen"
            placeholderTextColor={colors.textMuted}
            returnKeyType="search"
            onSubmitEditing={() => runOnlineSearch(1)}
            autoCorrect={false}
            style={styles.input}
            accessibilityLabel="Suchbegriff"
          />
          {query.length > 0 && (
            <Pressable onPress={() => setQuery('')} hitSlop={10} accessibilityLabel="Eingabe löschen">
              <Icon name="close" color={colors.textMuted} size={18} />
            </Pressable>
          )}
        </View>
      </View>

      <FlatList
        data={rows}
        keyExtractor={(row) => row.key}
        renderItem={renderRow}
        keyboardShouldPersistTaps="handled"
        keyboardDismissMode="on-drag"
        contentContainerStyle={{ paddingHorizontal: spacing.md, paddingBottom: insets.bottom + spacing.xl }}
      />
    </View>
  );
}

type ResultRowProps = {
  name: string;
  brand: string;
  /** `null` = Nährwerte fehlen, Zeile wird ausgegraut. */
  caloriesPer100g: number | null;
  imageUrl: string | null;
  onPress: () => void;
};

function ResultRow({ name, brand, caloriesPer100g, imageUrl, onPress }: ResultRowProps) {
  const incomplete = caloriesPer100g === null;
  const detail = incomplete ? 'Nährwerte fehlen' : `${formatInt(caloriesPer100g)} kcal pro 100 g`;

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.row, incomplete && styles.rowIncomplete, pressed && { backgroundColor: colors.surfacePressed }]}
      accessibilityRole="button"
      accessibilityLabel={[name, brand, detail].filter(Boolean).join(', ')}
    >
      {imageUrl ? (
        <Image source={{ uri: imageUrl }} style={styles.thumb} resizeMode="contain" />
      ) : (
        <View style={[styles.thumb, styles.thumbPlaceholder]}>
          <Icon name="scan" color={colors.border} size={18} />
        </View>
      )}
      <View style={styles.rowText}>
        <Text style={styles.rowName} numberOfLines={1}>
          {name}
        </Text>
        {brand ? (
          <Text style={styles.rowBrand} numberOfLines={1}>
            {brand}
          </Text>
        ) : null}
      </View>
      <Text style={[styles.rowKcal, incomplete && styles.rowKcalMissing]}>{detail}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.background },
  header: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs, paddingHorizontal: spacing.sm, paddingVertical: spacing.sm },
  backButton: { width: 40, height: 44, alignItems: 'center', justifyContent: 'center' },
  inputWrap: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    backgroundColor: colors.surface,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
    paddingHorizontal: 12,
  },
  input: { flex: 1, fontSize: 17, color: colors.text, paddingVertical: 12 },
  sectionTitle: { fontSize: 13, fontWeight: '700', color: colors.textMuted, textTransform: 'uppercase', marginTop: spacing.lg, marginBottom: spacing.sm },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    backgroundColor: colors.surface,
    borderRadius: radius.md,
    padding: spacing.sm,
    marginBottom: spacing.sm,
  },
  rowIncomplete: { opacity: 0.55 },
  thumb: { width: 44, height: 44, borderRadius: radius.sm, backgroundColor: colors.background },
  thumbPlaceholder: { alignItems: 'center', justifyContent: 'center' },
  rowText: { flex: 1 },
  rowName: { fontSize: 15, fontWeight: '600', color: colors.text },
  rowBrand: { fontSize: 13, color: colors.textMuted },
  rowKcal: { fontSize: 13, fontWeight: '600', color: colors.text, fontVariant: ['tabular-nums'], maxWidth: 110, textAlign: 'right' },
  rowKcalMissing: { color: colors.textMuted, fontWeight: '500' },
  statusRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, paddingVertical: spacing.sm },
  statusText: { flex: 1, fontSize: 14, color: colors.textMuted, lineHeight: 20 },
  errorText: { color: colors.danger },
  action: { marginVertical: spacing.sm },
  createRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, paddingVertical: spacing.md, marginTop: spacing.md },
  createText: { flex: 1, fontSize: 15, fontWeight: '600', color: colors.primary },
});
