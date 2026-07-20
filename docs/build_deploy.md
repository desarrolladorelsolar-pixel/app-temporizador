# 🚀 Build e Instalación

## Requisitos previos

- Flutter SDK instalado (versión 3.2.x o superior)
- Android SDK con `platform-tools` en el PATH
- Dispositivo Android conectado con depuración USB activada

---

## Comandos de desarrollo

### Instalar dependencias
```bash
cd temporizador
flutter pub get
```

### Correr en modo debug (instalación rápida para pruebas)
```bash
flutter run -d DEVICE_ID
```

### Ver dispositivos disponibles
```bash
flutter devices
```

---

## Generar APK de release

```bash
flutter build apk --release
```

El APK se genera en:
```
build/app/outputs/flutter-apk/app-release.apk
```

Tamaño aproximado: **~23 MB**

---

## Instalar APK en dispositivo vía USB

```bash
# Instalar (si no hay versión previa o si la firma coincide)
/Users/esteban/Library/Android/sdk/platform-tools/adb -s DEVICE_ID install -r app-release.apk

# Si hay conflicto de firma (ej: tenía versión debug), desinstalar primero:
/Users/esteban/Library/Android/sdk/platform-tools/adb -s DEVICE_ID uninstall com.example.temporizador_cocina
/Users/esteban/Library/Android/sdk/platform-tools/adb -s DEVICE_ID install app-release.apk
```

> ⚠️ Desinstalar borra los datos de la app (empleados, freidoras, etc.).
> Solo es necesario la primera vez que se cambia de debug a release.

---

## Subir a GitHub

```bash
cd temporizador
git add .
git commit -m "descripción del cambio"
git push
```

---

## Keystore de release

El keystore `elsolar-release.keystore` está en `android/app/` y está excluido del repositorio (`.gitignore`).

**Guardarlo en lugar seguro** — si se pierde, no se puede actualizar la app con la misma firma.

Credenciales en `android/key.properties`:
```
storePassword=elsolar2024
keyPassword=elsolar2024
keyAlias=elsolar
storeFile=elsolar-release.keystore
```

---

## Configuración Android

| Parámetro | Valor |
|---|---|
| `applicationId` | `com.example.temporizador_cocina` |
| `minSdkVersion` | 21 (Android 5.0+) |
| `targetSdkVersion` | 34 (Android 14) |
| `compileSdkVersion` | 34 |
| `minifyEnabled` | true (release) |
| `shrinkResources` | true (release) |
| Kotlin version | 1.8.22 |

---

## ID del dispositivo Samsung (Sucursal)

```
520053faf4ebb429
```

Comando rápido para instalar directamente:
```bash
cd /Users/esteban/Documents/App_temporizador_elsolar/temporizador
flutter build apk --release && \
  /Users/esteban/Library/Android/sdk/platform-tools/adb -s 520053faf4ebb429 \
  install -r build/app/outputs/flutter-apk/app-release.apk
```
