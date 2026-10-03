# LB Admin App (Flutter scaffold)

Renamed from the earlier "LB Technician" scaffold. Bottom navigation with
four tabs:

1. **Dashboard** — outlet count, device count, live online ratio, all
   scoped to what the logged-in user can access.
2. **Outlet** — list of accessible outlets → tap into one → devices
   installed there with live online/offline + availability.
3. **Device Install** — the three QR-driven flows:
   - **Quick Start** — scan → shows machine + prices → pick a mode → sends
     a paid credit pulse → polls the firmware's real ack (received →
     completed/busy/rejected) so the technician sees genuine confirmation,
     not an optimistic guess. Reminder baked into the UI copy: the machine
     is pulse-controlled, not API-controlled — a completed pulse credits
     the machine like a coin, it doesn't start the cycle by itself.
   - **Config Network** — scan → BLE-connects to `LB-<serial>` → asks the
     *device* to scan WiFi (not the phone — the ESP32 is 2.4 GHz only, and
     the phone's own WiFi list would include networks it can never join)
     → pick from the list or enter manually → send SSID/password over BLE.
   - **Config Parameter** — scan → fetch → edit prices, pulse timing, coin
     signal settings, and the `pulse_active_low` output-polarity toggle →
     save (auto-pushes CONFIG to the device) or just resend current
     settings.
4. **Profile** — name, role, permissions, and whether the account can see
   every outlet or only assigned ones, plus logout.

**Item 5 (role/outlet binding)** isn't a separate feature to build — it's
already enforced by the backend, the same way as the web admin: every
device/outlet endpoint checks `User::canAccessOutlet()` /
`canAccessAllOutlets()` (the existing `outlet_user` pivot), plus
`devices_outlet.manage` / `devices_outlet.edit` permission checks. Assign
outlets to a user the same way you already do for the web admin — nothing
new to configure.

## 1. Generate the platform folders

This environment can't run the Flutter SDK, so `android/`/`ios/` aren't
included:

```bash
flutter create --org com.yourcompany lb_admin_app_shell
# copy this project's lib/, pubspec.yaml, and README over the shell's
```

## 2. Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan device QR codes.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to configure WiFi on laundry machine controllers.</string>
```

Both `mobile_scanner` and `flutter_blue_plus` also want runtime permission
requests on Android 12+/iOS — check each package's current README, since
that guidance shifts between versions and isn't something I can verify
from here.

## 3. Point the app at your backend

Edit `lib/services/app_config.dart` → `apiBaseUrl`.

## 4. Firmware requirement

Config Network's WiFi-scan feature needs **firmware v1.5.4 or later** —
earlier versions don't have the BLE scan characteristic and will fail
silently when the app asks for a scan. The BLE UUIDs in
`lib/services/ble_provisioning_service.dart` must match the firmware's
`#define BLE_*_UUID` values exactly.

## Known gaps

- No offline caching — every screen re-fetches on open.
- No token refresh/expiry handling — an expired Sanctum token just shows
  as a generic 401 error string.
- Outlet/device lists don't paginate — fine for a modest fleet, would need
  it for a very large one.
- No automated tests.
