import { Stack } from 'expo-router';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SQLiteProvider } from 'expo-sqlite';
import { StatusBar } from 'expo-status-bar';

import { DATABASE_NAME, migrateDbIfNeeded } from '../db/schema';
import { colors } from '../theme';

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
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
    </GestureHandlerRootView>
  );
}
