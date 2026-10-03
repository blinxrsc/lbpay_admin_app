import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_provisioning_service.dart';
import 'qr_scan_screen.dart';

enum _Stage { idle, findingDevice, notFound, connecting, scanningWifi, ready, provisioning, success, failed }

class ConfigNetworkScreen extends StatefulWidget {
  const ConfigNetworkScreen({super.key});

  @override
  State<ConfigNetworkScreen> createState() => _ConfigNetworkScreenState();
}

class _ConfigNetworkScreenState extends State<ConfigNetworkScreen> {
  final _ble = BleProvisioningService();
  final _passwordController = TextEditingController();
  final _manualSsidController = TextEditingController();

  String? _serial;
  BluetoothDevice? _device;
  _Stage _stage = _Stage.idle;
  List<WifiNetwork> _networks = [];
  WifiNetwork? _selectedNetwork;
  bool _manualEntry = false;
  String? _error;

  Future<void> _scanQrThenFind() async {
    final serial = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen(title: 'Scan Device to Configure')),
    );
    if (serial == null) return;

    setState(() {
      _serial = serial;
      _stage = _Stage.findingDevice;
      _error = null;
    });

    final device = await _ble.findDeviceBySerial(serial);
    if (!mounted) return;

    if (device == null) {
      setState(() => _stage = _Stage.notFound);
      return;
    }

    setState(() {
      _device = device;
      _stage = _Stage.connecting;
    });

    try {
      await _ble.connect(device);
      await _scanWifi();
    } catch (e) {
      setState(() {
        _stage = _Stage.failed;
        _error = e.toString();
      });
    }
  }

  Future<void> _scanWifi() async {
    setState(() {
      _stage = _Stage.scanningWifi;
      _error = null;
    });
    try {
      final networks = await _ble.scanWifiNetworks();
      setState(() {
        _networks = networks;
        _stage = _Stage.ready;
      });
    } catch (e) {
      setState(() {
        _stage = _Stage.failed;
        _error = e.toString();
      });
    }
  }

  Future<void> _provision() async {
    final ssid = _manualEntry ? _manualSsidController.text.trim() : _selectedNetwork?.ssid;
    if (ssid == null || ssid.isEmpty) return;

    setState(() => _stage = _Stage.provisioning);
    try {
      await for (final result in _ble.provisionWifi(ssid: ssid, password: _passwordController.text)) {
        if (!mounted) return;
        if (result == ProvisioningResult.connected) {
          setState(() => _stage = _Stage.success);
        } else if (result == ProvisioningResult.failed) {
          setState(() => _stage = _Stage.failed);
        }
      }
    } catch (e) {
      setState(() {
        _stage = _Stage.failed;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    if (_device != null) _ble.disconnect(_device!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Config Network')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_stage == _Stage.idle) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Scan a device to set its WiFi network over Bluetooth.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _scanQrThenFind, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan Device')),
          ],
        ),
      );
    }

    if (_stage == _Stage.findingDevice || _stage == _Stage.connecting || _stage == _Stage.scanningWifi) {
      final label = _stage == _Stage.findingDevice
          ? 'Looking for LB-$_serial over Bluetooth…'
          : _stage == _Stage.connecting
              ? 'Connecting…'
              : 'Asking the device to scan for WiFi networks…';
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(label)]),
      );
    }

    if (_stage == _Stage.notFound) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Device not found. Make sure it is powered on and nearby.', textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _scanQrThenFind, child: const Text('Try Again')),
        ]),
      );
    }

    if (_stage == _Stage.failed) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _scanQrThenFind, child: const Text('Start Over')),
        ]),
      );
    }

    if (_stage == _Stage.success) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle, color: Colors.green, size: 56),
          SizedBox(height: 12),
          Text('Device connected to the new network successfully.', textAlign: TextAlign.center),
        ]),
      );
    }

    // _Stage.ready or _Stage.provisioning
    return ListView(
      children: [
        Text('Networks seen by $_serial:', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ..._networks.map((n) => RadioListTile<WifiNetwork>(
              value: n,
              groupValue: _selectedNetwork,
              onChanged: (v) => setState(() {
                _selectedNetwork = v;
                _manualEntry = false;
              }),
              title: Text(n.ssid),
              secondary: Icon(n.secure ? Icons.lock : Icons.lock_open, size: 18),
              subtitle: Text('${n.rssi} dBm'),
            )),
        RadioListTile<bool>(
          value: true,
          groupValue: _manualEntry ? true : null,
          onChanged: (_) => setState(() => _manualEntry = true),
          title: const Text('Enter network name manually'),
        ),
        if (_manualEntry)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: TextField(controller: _manualSsidController, decoration: const InputDecoration(labelText: 'WiFi SSID')),
          ),
        TextButton.icon(onPressed: _scanWifi, icon: const Icon(Icons.refresh), label: const Text('Rescan')),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'WiFi Password', border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton(
            onPressed: _stage == _Stage.provisioning ? null : _provision,
            child: _stage == _Stage.provisioning
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save & Send to Device'),
          ),
        ),
      ],
    );
  }
}
