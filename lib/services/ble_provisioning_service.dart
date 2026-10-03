import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Must match the `#define BLE_*_UUID` values in the ESP32 firmware exactly.
class BleUuids {
  static final service = Guid('d804b643-6ce7-4e81-9e8e-1b25f0e12345');
  static final wifiWrite = Guid('d804b643-6ce7-4e81-9e8e-1b25f0e12346');
  static final wifiStatus = Guid('d804b643-6ce7-4e81-9e8e-1b25f0e12347');
  static final wifiScan = Guid('d804b643-6ce7-4e81-9e8e-1b25f0e12348'); // v1.5.4+
}

class WifiNetwork {
  final String ssid;
  final int rssi;
  final bool secure;
  WifiNetwork({required this.ssid, required this.rssi, required this.secure});

  factory WifiNetwork.fromJson(Map<String, dynamic> j) =>
      WifiNetwork(ssid: j['s'], rssi: j['r'] ?? -100, secure: j['e'] == 1);
}

enum ProvisioningResult { connecting, connected, failed }

class BleProvisioningService {
  BluetoothCharacteristic? _statusChar;
  BluetoothCharacteristic? _scanChar;
  BluetoothCharacteristic? _writeChar;

  /// Scans for a device advertising as "LB-<serial>" — the QR-scanned
  /// serial fully identifies the target, so the technician never has to
  /// pick from a generic BLE device list.
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

  Future<void> connect(BluetoothDevice device) async {
    await device.connect(timeout: const Duration(seconds: 10));
    final services = await device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid == BleUuids.service,
      orElse: () => throw Exception('LB provisioning service not found on this device'),
    );
    _writeChar = service.characteristics.firstWhere((c) => c.uuid == BleUuids.wifiWrite);
    _statusChar = service.characteristics.firstWhere((c) => c.uuid == BleUuids.wifiStatus);
    _scanChar = service.characteristics.firstWhere((c) => c.uuid == BleUuids.wifiScan);
    await _statusChar!.setNotifyValue(true);
  }

  /// Asks the DEVICE to scan (not the phone) — it's the ESP32 that needs to
  /// join the network, and it's 2.4 GHz only, so the phone's own WiFi list
  /// would show networks it can never join and signal strength for the
  /// wrong location entirely.
  Future<List<WifiNetwork>> scanWifiNetworks({Duration timeout = const Duration(seconds: 15)}) async {
    if (_scanChar == null || _statusChar == null) {
      throw Exception('Not connected — call connect() first');
    }

    final statusStream = _statusChar!.onValueReceived.map((b) => utf8.decode(b));
    final doneOrFailed = statusStream.firstWhere(
      (s) => s == 'scan_done' || s.startsWith('scan_failed'),
      orElse: () => 'scan_failed:timeout',
    );

    await _scanChar!.write(utf8.encode('scan'), withoutResponse: false);

    final result = await doneOrFailed.timeout(timeout, onTimeout: () => 'scan_failed:timeout');
    if (result.startsWith('scan_failed')) {
      throw Exception('WiFi scan failed on the device ($result)');
    }

    final raw = await _scanChar!.read();
    final list = jsonDecode(utf8.decode(raw)) as List;
    final nets = list.map((e) => WifiNetwork.fromJson(e as Map<String, dynamic>)).toList();
    nets.sort((a, b) => b.rssi.compareTo(a.rssi));
    return nets;
  }

  Stream<ProvisioningResult> provisionWifi({required String ssid, required String password}) async* {
    if (_writeChar == null || _statusChar == null) {
      throw Exception('Not connected — call connect() first');
    }

    final statusStream = _statusChar!.onValueReceived.map((bytes) => utf8.decode(bytes));
    final payload = jsonEncode({'ssid': ssid, 'password': password});
    await _writeChar!.write(utf8.encode(payload), withoutResponse: false);

    yield ProvisioningResult.connecting;

    await for (final raw in statusStream.timeout(
      const Duration(seconds: 20),
      onTimeout: (sink) => sink.add('failed:timeout'),
    )) {
      if (raw == 'connecting') {
        yield ProvisioningResult.connecting;
      } else if (raw == 'connected') {
        yield ProvisioningResult.connected;
        return;
      } else if (raw.startsWith('failed')) {
        yield ProvisioningResult.failed;
        return;
      }
      // 'scan_done'/'scan_failed*' notifications can also arrive on this
      // same characteristic if a scan overlaps — ignored here, handled by
      // scanWifiNetworks()'s own listener instead.
    }
  }

  Future<void> disconnect(BluetoothDevice device) async {
    await device.disconnect();
    _writeChar = null;
    _statusChar = null;
    _scanChar = null;
  }
}
