import { Stack } from 'expo-router';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SQLiteProvider } from 'expo-sqlite';
import { StatusBar } from 'expo-status-bar';
import { Component, Fragment, type ReactNode } from 'react';

import { LoadError } from '../components/LoadError';
import { DATABASE_NAME, migrateDbIfNeeded } from '../db/schema';
import { colors } from '../theme';

type BoundaryState = { failed: boolean; attempt: number };

/**
 * Schlägt das Öffnen oder Migrieren der Datenbank fehl, wirft SQLiteProvider den Fehler beim Rendern.
 * Ohne diese Grenze bliebe die App dann bei jedem Start leer. „Erneut versuchen“ baut den Provider
 * neu auf und öffnet die Datenbank damit noch einmal.
 */
class StartupErrorBoundary extends Component<{ children: ReactNode }, BoundaryState> {
  state: BoundaryState = { failed: false, attempt: 0 };

  static getDerivedStateFromError(): Partial<BoundaryState> {
    return { failed: true };
  }

  retry = () => this.setState((s) => ({ failed: false, attempt: s.attempt + 1 }));

  render() {
    if (this.state.failed) return <LoadError title="Hachibu konnte nicht starten" onRetry={this.retry} />;
    return <Fragment key={this.state.attempt}>{this.props.children}</Fragment>;
  }
}

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <StartupErrorBoundary>
        <SQLiteProvider databaseName={DATABASE_NAME} onInit={migrateDbIfNeeded}>
          <StatusBar style="dark" />
          <Stack
            screenOptions={{
              headerStyle: { backgroundColor: colors.background },
              headerShadowVisible: false,
              headerTintColor: colors.text,
              contentStyle: { backgroundColor: colors.background },
              headerBackTitle: 'Zurück',
            }}
          >
            <Stack.Screen name="index" options={{ headerShown: false }} />
            <Stack.Screen name="onboarding" options={{ title: 'Dein Profil' }} />
            <Stack.Screen name="about" options={{ title: 'Info & Rechtliches' }} />
            <Stack.Screen name="scan" options={{ presentation: 'fullScreenModal', headerShown: false, animation: 'fade' }} />
            <Stack.Screen name="search" options={{ headerShown: false }} />
            {/* Eigene Kopfzeile, damit die Tastatur den Speichern-Button nicht verdeckt. */}
            <Stack.Screen name="product/[barcode]" options={{ headerShown: false }} />
            {/*
              Bewusst kein formSheet: react-native-screens meldet im Sheet keine Tastatur-Ereignisse
              (RNSScreen.mm: "TODO: register for UIKeyboard notifications"). Dort bleibt jede
              Tastaturbehandlung kaputt. Als normaler Screen, der von unten hereingleitet, sieht es
              aehnlich aus und die Tastatur verhaelt sich wie im Produkt-Screen.
            */}
            <Stack.Screen name="entry/[id]" options={{ headerShown: false, animation: 'slide_from_bottom' }} />
          </Stack>
        </SQLiteProvider>
      </StartupErrorBoundary>
    </GestureHandlerRootView>
  );
}
