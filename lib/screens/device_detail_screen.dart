import 'package:flutter/material.dart';

import '../models/device.dart';
import '../services/api_service.dart';
import 'wifi_provision_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final ApiService api;
  final String serial;
  const DeviceDetailScreen({super.key, required this.api, required this.serial});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  DeviceDetail? _device;
  bool _loading = true;
  String? _error;

  // Editable copies of the fields, keyed by parameter name, so text fields
  // don't fight the loaded state.
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final device = await widget.api.fetchDevice(widget.serial);
      _setControllersFrom(device.parameters);
      setState(() => _device = device);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setControllersFrom(DeviceParameters p) {
    final values = p.toJson();
    values.forEach((key, value) {
      _controllers.putIfAbsent(key, () => TextEditingController()).text = value.toString();
    });
  }

  DeviceParameters _readControllers() {
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
    );
  }

  Future<void> _saveParameters() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await widget.api.updateParameters(widget.serial, _readControllers());
      _setControllersFrom(updated);
      messenger.showSnackBar(const SnackBar(content: Text('Parameters saved and pushed to the device.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _startMachine(String type, double price) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pulses = await widget.api.startMachine(widget.serial, type: type, price: price);
      messenger.showSnackBar(SnackBar(content: Text('Start sent — $pulses pulse(s) queued.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Start failed: $e')));
    }
  }

  Future<void> _promptAndStart(String type, double defaultPrice) async {
    final controller = TextEditingController(text: defaultPrice.toStringAsFixed(2));
    final price = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start $type'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Price (RM)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (price != null && price > 0) {
      await _startMachine(type, price);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.serial),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            tooltip: 'WiFi Provisioning',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => WifiProvisionScreen(serial: widget.serial)),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final device = _device!;
    final outlet = device.outlet;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Outlet: ${outlet?.outletName ?? '—'}', style: Theme.of(context).textTheme.titleMedium),
                Text('Machine: ${outlet?.machineType ?? '—'} #${outlet?.machineNum ?? '—'}'),
                Row(
                  children: [
                    Icon(
                      outlet?.isOnline == true ? Icons.circle : Icons.circle_outlined,
                      size: 12,
                      color: outlet?.isOnline == true ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(outlet?.isOnline == true ? 'Online' : 'Offline'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Quick Start', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _startChip('Washer Cold', 'washer_cold', device.parameters.washerColdPrice),
            _startChip('Washer Warm', 'washer_warm', device.parameters.washerWarmPrice),
            _startChip('Washer Hot', 'washer_hot', device.parameters.washerHotPrice),
            _startChip('Dryer Low', 'dryer_low', device.parameters.dryerLowPrice),
            _startChip('Dryer Med', 'dryer_med', device.parameters.dryerMedPrice),
            _startChip('Dryer High', 'dryer_hi', device.parameters.dryerHiPrice),
          ],
        ),
        const Divider(height: 32),
        Text('Device Parameters', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _paramField('washer_cold_price', 'Washer Cold Price (RM)'),
        _paramField('washer_warm_price', 'Washer Warm Price (RM)'),
        _paramField('washer_hot_price', 'Washer Hot Price (RM)'),
        _paramField('dryer_low_price', 'Dryer Low Price (RM)'),
        _paramField('dryer_med_price', 'Dryer Med Price (RM)'),
        _paramField('dryer_hi_price', 'Dryer High Price (RM)'),
        const Divider(height: 32),
        _paramField('pulse_price', 'Pulse Price (RM per pulse)'),
        _paramField('pulse_add_min', 'Pulse → Added Minutes'),
        _paramField('pulse_width', 'Pulse Width (ms)'),
        _paramField('pulse_delay', 'Pulse Delay (ms)'),
        _paramField('coin_signal_width', 'Coin Signal Width (ms)'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saveParameters,
          icon: const Icon(Icons.cloud_upload),
          label: const Text('Save & Push to Device'),
        ),
      ],
    );
  }

  Widget _startChip(String label, String type, double price) {
    return ActionChip(
      label: Text('$label (RM${price.toStringAsFixed(2)})'),
      onPressed: () => _promptAndStart(type, price),
    );
  }

  Widget _paramField(String key, String label) {
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
