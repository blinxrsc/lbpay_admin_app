# LB Technician App (Flutter scaffold)

Covers the four functions requested:
1. Scan a device's QR code to identify it.
2. Set/change its WiFi SSID + password over Bluetooth (works even if the
   device has no internet yet — that's the whole point).
3. Pull the device's current pulse/price parameters from the Laravel backend.
4. Update those parameters, and trigger a remote start for a given price.

This is a working **scaffold**, not a finished, store-ready app: the logic
and API/BLE wiring are real and complete, but there's no `android/`/`ios/`
platform folder here yet, no app icon, and only minimal error-state polish.

## 1. Generate the platform folders

This environment can't run the Flutter SDK, so the `android/`/`ios/`
directories aren't included. Create them and drop this `lib/` and
`pubspec.yaml` in:

```bash
flutter create --org com.yourcompany lb_technician_app_shell
# then copy this project's lib/ and pubspec.yaml over the shell's,
# overwriting the shell's own lib/main.dart and pubspec.yaml
```

## 2. Add required permissions

**Android** — in `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA" /> <!-- QR scanning -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<!-- Only needed on Android 11 (API 30) and below, where BLE scanning still requires location: -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
```

**iOS** — in `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan device QR codes.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to configure WiFi on laundry machine controllers.</string>
```

`mobile_scanner` and `flutter_blue_plus` both also need you to request these
permissions at runtime (Android 12+/iOS both enforce this) — check each
package's own README for the current recommended approach (e.g. via
`permission_handler`), since that detail shifts between package versions
and I can't verify the current guidance without pub.dev access from here.

## 3. Point the app at your backend

Edit `lib/services/app_config.dart` and set `apiBaseUrl` to your real
domain, e.g. `https://lbpaylinker.com/api`.

## 4. Backend setup (Laravel side — separate patch already provided)

The API endpoints this app calls (`/technician/login`, `/technician/devices/{serial}`,
etc.) require Laravel Sanctum, which isn't installed yet in `lbpayweb`:

```bash
composer require laravel/sanctum
php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider"
php artisan migrate
```

No further Sanctum config is needed beyond that for pure mobile bearer-token
auth (the stateful/cookie SPA setup in Sanctum's docs is for browser apps,
not this use case).

## 5. Firmware

The BLE UUIDs in `lib/services/ble_provisioning_service.dart` must match
the ESP32 firmware's `#define BLE_SERVICE_UUID` / `BLE_WIFI_WRITE_UUID` /
`BLE_WIFI_STATUS_UUID` exactly — they're already aligned with the v1.4
firmware provided alongside this app. If you regenerate the UUIDs on either
side, update both.

## Known gaps / next steps

- No offline caching — every screen re-fetches from the API each time.
- The "Quick Start" price chips use whatever price is currently loaded;
  if you edit prices and don't save first, quick-start still uses the
  last *saved* price, not your unsaved edit. Worth a "you have unsaved
  changes" guard if this bites technicians in practice.
- No token refresh/expiry handling — a revoked/expired Sanctum token just
  surfaces as a generic 401 error string right now.
- No automated tests.
