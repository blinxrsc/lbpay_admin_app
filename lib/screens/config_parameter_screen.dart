import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'qr_scan_screen.dart';

class ConfigParameterScreen extends StatefulWidget {
  final ApiService api;
  const ConfigParameterScreen({super.key, required this.api});

  @override
  State<ConfigParameterScreen> createState() => _ConfigParameterScreenState();
}

class _ConfigParameterScreenState extends State<ConfigParameterScreen> {
  DeviceDetail? _device;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  final Map<String, TextEditingController> _controllers = {};
  bool _pulsePullUp = true;
  bool _coinSignalIdleHigh = true;
  bool _pulseActiveLow = true;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scanAndLoad() async {
    final serial = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen(title: 'Scan Device to Configure')),
    );
    if (serial == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _device = null;
    });
    try {
      final device = await widget.api.fetchDevice(serial);
      _setControllersFrom(device.parameters);
      setState(() => _device = device);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setControllersFrom(DeviceParameters p) {
    final values = <String, String>{
      'washer_cold_price': p.washerColdPrice.toString(),
      'washer_warm_price': p.washerWarmPrice.toString(),
      'washer_hot_price': p.washerHotPrice.toString(),
      'dryer_low_price': p.dryerLowPrice.toString(),
      'dryer_med_price': p.dryerMedPrice.toString(),
      'dryer_hi_price': p.dryerHiPrice.toString(),
      'pulse_price': p.pulsePrice.toString(),
      'pulse_add_min': p.pulseAddMin.toString(),
      'pulse_width': p.pulseWidth.toString(),
      'pulse_delay': p.pulseDelay.toString(),
      'coin_signal_width': p.coinSignalWidth.toString(),
      'max_vend_price': p.maxVendPrice?.toString() ?? '',
      'coin_signal_sensitivity': p.coinSignalSensitivity.toString(),
    };
    values.forEach((key, value) {
      _controllers.putIfAbsent(key, () => TextEditingController()).text = value;
    });
    _pulsePullUp = p.pulsePullUp;
    _coinSignalIdleHigh = p.coinSignalIdleHigh;
    _pulseActiveLow = p.pulseActiveLow;
  }

  DeviceParameters _readForm() {
    double d(String key) => double.tryParse(_controllers[key]!.text) ?? 0;
    int i(String key) => int.tryParse(_controllers[key]!.text) ?? 0;
    return DeviceParameters(
      washerColdPrice: d('washer_cold_price'),
      washerWarmPrice: d('washer_warm_price'),
      washerHotPrice: d('washer_hot_price'),
      dryerLowPrice: d('dryer_low_price'),
      dryerMedPrice: d('dryer_med_price'),
      dryerHiPrice: d('dryer_hi_price'),
      pulsePrice: d('pulse_price'),
      pulseAddMin: i('pulse_add_min'),
      pulseWidth: i('pulse_width'),
      pulseDelay: i('pulse_delay'),
      coinSignalWidth: i('coin_signal_width'),
      maxVendPrice: _controllers['max_vend_price']!.text.trim().isEmpty ? null : d('max_vend_price'),
      pulsePullUp: _pulsePullUp,
      coinSignalIdleHigh: _coinSignalIdleHigh,
      coinSignalSensitivity: i('coin_signal_sensitivity'),
      pulseActiveLow: _pulseActiveLow,
    );
  }

  Future<void> _save() async {
    if (_device == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final params = _readForm();
    final cyclePrices = [
      params.washerColdPrice, params.washerWarmPrice, params.washerHotPrice,
      params.dryerLowPrice, params.dryerMedPrice, params.dryerHiPrice,
    ].where((p) => p > 0);

    if (cyclePrices.isNotEmpty && params.pulsePrice >= cyclePrices.reduce((a, b) => a < b ? a : b)) {
      setState(() => _error = 'Pulse price must be lower than your cheapest cycle price.');
      return;
    }
    try {
      final updated = await widget.api.updateParameters(_device!.serialNumber, _readForm());
      _setControllersFrom(updated);
      messenger.showSnackBar(const SnackBar(content: Text('Saved and sent to the device.')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resend() async {
    if (_device == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.api.sendConfig(_device!.serialNumber);
      messenger.showSnackBar(const SnackBar(content: Text('Current settings re-sent to the device.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Config Parameter'),
        actions: [
          if (_device != null) IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _scanAndLoad, tooltip: 'Scan another device'),
        ],
      ),
      body: _device == null ? _buildEmptyState() : _buildForm(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.tune, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Scan a device to view and edit its parameters.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          FilledButton.icon(
            onPressed: _loading ? null : _scanAndLoad,
            icon: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Device'),
          ),
        ]),
      ),
    );
  }

  Widget _buildForm() {
    final outlet = _device!.outlet;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_device!.serialNumber, style: Theme.of(context).textTheme.titleMedium),
        Text('${outlet?.outletName ?? '—'} · ${outlet?.machineType ?? ''} #${outlet?.machineNum ?? ''}', style: const TextStyle(color: Colors.grey)),
        const Divider(height: 32),
        Text('Cycle Prices (RM)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _field('washer_cold_price', 'Washer Cold'),
        _field('washer_warm_price', 'Washer Normal'),
        _field('washer_hot_price', 'Washer Hot'),
        _field('dryer_low_price', 'Dryer Low'),
        _field('dryer_med_price', 'Dryer Medium'),
        _field('dryer_hi_price', 'Dryer High'),
        const Divider(height: 32),
        Text('Pulse & Vend Settings', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _field('pulse_price', 'Pulse Price (RM per pulse)'),
        _field('pulse_add_min', 'Pulse → Added Minutes'),
        _field('pulse_width', 'Pulse Width (ms)'),
        _field('pulse_delay', 'Pulse Delay (ms)'),
        _field('max_vend_price', 'Max Vend Price (RM, optional)'),
        SwitchListTile(
          title: const Text('Pulse Pull Up'),
          subtitle: const Text('Off = Pull Down'),
          value: _pulsePullUp,
          onChanged: (v) => setState(() => _pulsePullUp = v),
        ),
        SwitchListTile(
          title: const Text('Pulse Active Low'),
          subtitle: const Text('Output polarity to the machine — flip this if REMOTE_START runs but the machine never credits'),
          value: _pulseActiveLow,
          onChanged: (v) => setState(() => _pulseActiveLow = v),
        ),
        const Divider(height: 32),
        Text('Coin Signal Settings', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _field('coin_signal_width', 'Coin Signal Width (ms)'),
        _field('coin_signal_sensitivity', 'Coin Signal Sensitivity (debounce, ms)'),
        SwitchListTile(
          title: const Text('Coin Signal Idle High'),
          subtitle: const Text('Off = Idle Low'),
          value: _coinSignalIdleHigh,
          onChanged: (v) => setState(() => _coinSignalIdleHigh = v),
        ),
        const SizedBox(height: 16),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload),
          label: const Text('Save & Send to Device'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _resend, child: const Text('Resend Current Settings')),
      ],
    );
  }

  Widget _field(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controllers[key],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}
