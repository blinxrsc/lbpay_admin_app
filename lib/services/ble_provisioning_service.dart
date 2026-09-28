import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Must match the UUIDs `#define`d in the v1.4 ESP32 firmware exactly.
class BleUuids {
  static final service = Guid('d804b643-6ce7-4e81-9e8e-1b25f0e12345');
  static final wifiWrite = Guid('d804b643-6ce7-4e81-9e8e-1b25f0e12346');
  static final wifiStatus = Guid('d804b643-6ce7-4e81-9e8e-1b25f0e12347');
}

enum ProvisioningResult { connecting, connected, failed }

class BleProvisioningService {
  /// Scans for a device advertising as "LB-<serial>" (see firmware
  /// setupBleProvisioning()) so the technician never has to pick from a
  /// generic BLE list — the QR-scanned serial fully identifies the target.
  Future<BluetoothDevice?> findDeviceBySerial(String serial, {Duration timeout = const Duration(seconds: 10)}) async {
    final targetName = 'LB-$serial';
    final completer = Completer<BluetoothDevice?>();

    final subscription = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == targetName && !completer.isCompleted) {
          completer.complete(r.device);
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: timeout);
    final found = await completer.future.timeout(timeout, onTimeout: () => null);
    await FlutterBluePlus.stopScan();
    await subscription.cancel();
    return found;
  }

  /// Connects, writes the new WiFi credentials to the write characteristic,
  /// and listens on the notify characteristic for "connecting" / "connected"
  /// / "failed:<reason>" reported back by the firmware.
  Stream<ProvisioningResult> provisionWifi(
    BluetoothDevice device, {
    required String ssid,
    required String password,
  }) async* {
    await device.connect(timeout: const Duration(seconds: 10));

    final services = await device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid == BleUuids.service,
      orElse: () => throw Exception('LB provisioning service not found on this device'),
    );

    final writeChar = service.characteristics.firstWhere((c) => c.uuid == BleUuids.wifiWrite);
    final statusChar = service.characteristics.firstWhere((c) => c.uuid == BleUuids.wifiStatus);

    await statusChar.setNotifyValue(true);

    final statusStream = statusChar.onValueReceived.map((bytes) => utf8.decode(bytes));

    final payload = jsonEncode({'ssid': ssid, 'password': password});
    await writeChar.write(utf8.encode(payload), withoutResponse: false);

    yield ProvisioningResult.connecting;

    await for (final raw in statusStream.timeout(
      const Duration(seconds: 20),
      onTimeout: (sink) => sink.add('failed:timeout'),
    )) {
      if (raw == 'connecting') {
        yield ProvisioningResult.connecting;
      } else if (raw == 'connected') {
        yield ProvisioningResult.connected;
        await device.disconnect();
        return;
      } else if (raw.startsWith('failed')) {
        yield ProvisioningResult.failed;
        await device.disconnect();
        return;
      }
    }
  }
}
