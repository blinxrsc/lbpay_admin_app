import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/ble_provisioning_service.dart';

class WifiProvisionScreen extends StatefulWidget {
  final String serial;
  const WifiProvisionScreen({super.key, required this.serial});

  @override
  State<WifiProvisionScreen> createState() => _WifiProvisionScreenState();
}

enum _Stage { idle, scanning, found, notFound, provisioning, success, failed }

class _WifiProvisionScreenState extends State<WifiProvisionScreen> {
  final _ble = BleProvisioningService();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  _Stage _stage = _Stage.idle;
  BluetoothDevice? _foundDevice;

  Future<void> _scan() async {
    setState(() => _stage = _Stage.scanning);
    final device = await _ble.findDeviceBySerial(widget.serial);
    if (!mounted) return;
    setState(() {
      _foundDevice = device;
      _stage = device == null ? _Stage.notFound : _Stage.found;
    });
  }

  Future<void> _provision() async {
    if (_foundDevice == null) return;
    setState(() => _stage = _Stage.provisioning);

    try {
      await for (final result in _ble.provisionWifi(
        _foundDevice!,
        ssid: _ssidController.text.trim(),
        password: _passwordController.text,
      )) {
        if (!mounted) return;
        if (result == ProvisioningResult.connected) {
          setState(() => _stage = _Stage.success);
        } else if (result == ProvisioningResult.failed) {
          setState(() => _stage = _Stage.failed);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _stage = _Stage.failed);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Provisioning error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WiFi Setup — ${widget.serial}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Make sure you are standing near "LB-${widget.serial}". '
              'The device advertises over Bluetooth whether or not it currently has WiFi.',
            ),
            const SizedBox(height: 16),
            if (_stage == _Stage.idle || _stage == _Stage.notFound)
              FilledButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Find Device'),
              ),
            if (_stage == _Stage.scanning) const Center(child: CircularProgressIndicator()),
            if (_stage == _Stage.notFound)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Device not found. Make sure it is powered on and nearby, then try again.',
                    style: TextStyle(color: Colors.red)),
              ),
            if (_stage == _Stage.found || _stage == _Stage.provisioning || _stage == _Stage.failed) ...[
              const SizedBox(height: 8),
              const Text('Device found. Enter the WiFi network to configure:'),
              const SizedBox(height: 12),
              TextField(
                controller: _ssidController,
                decoration: const InputDecoration(labelText: 'WiFi SSID', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'WiFi Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _stage == _Stage.provisioning ? null : _provision,
                child: _stage == _Stage.provisioning
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Send to Device'),
              ),
              if (_stage == _Stage.failed)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Could not connect with those credentials. Double-check and try again.',
                      style: TextStyle(color: Colors.red)),
                ),
            ],
            if (_stage == _Stage.success)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(child: Text('Device connected to the new network successfully.')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
