# Alerta Granizo (Flutter + Riverpod)

## 1. Crear el proyecto base
    flutter create --org com.tuapp storm_alert
Reemplazá `pubspec.yaml` y la carpeta `lib/` por las de este zip y corré:
    flutter pub get

## 2. Android
**android/app/src/main/AndroidManifest.xml** (dentro de <manifest>, antes de <application>):

    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

**android/app/build.gradle** (flutter_local_notifications lo necesita):
- `minSdkVersion 21` (o más)
- en `compileOptions`: `coreLibraryDesugaringEnabled true`
- en `dependencies`: `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'`

## 3. iOS (si lo usás)
Info.plist: NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription,
UIBackgroundModes (fetch, processing), BGTaskSchedulerPermittedIdentifiers = storm-check

## 4. Cosas SIN verificar (ajustar si fallan)
- lib/services/smn_service.dart: la API del SMN usa token JWT y sus rutas no son
  públicas/documentadas. Si falla, la app muestra "No pudimos consultar las alertas del SMN".
- lib/services/radar_service.dart: asume que en RainViewer color 0 el píxel = dBZ + 32.
  Probalo con una tormenta real y mirá si "Eco máximo" coincide con el mapa.
- "Vecinos" y "Reportar granizo": solo guardan en el teléfono (no hay servidor).
