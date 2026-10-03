import 'dart:async';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'qr_scan_screen.dart';

class QuickStartScreen extends StatefulWidget {
  final ApiService api;
  const QuickStartScreen({super.key, required this.api});

  @override
  State<QuickStartScreen> createState() => _QuickStartScreenState();
}

class _QuickStartScreenState extends State<QuickStartScreen> {
  DeviceDetail? _device;
  bool _loading = false;
  String? _error;
  String? _ackStatus;
  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _scanAndLoad() async {
    final serial = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen(title: 'Scan Device to Start')),
    );
    if (serial == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _device = null;
      _ackStatus = null;
    });
    try {
      final device = await widget.api.fetchDevice(serial);
      setState(() => _device = device);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start(String type, double price) async {
    if (_device == null) return;
    setState(() {
      _ackStatus = 'sending';
      _error = null;
    });
    try {
      final (pulses, opId) = await widget.api.startMachine(_device!.serialNumber, type: type, price: price);
      setState(() => _ackStatus = 'received');
      _pollAck(opId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Credit sent — $pulses pulse(s) queued.')));
      }
    } catch (e) {
      setState(() {
        _ackStatus = null;
        _error = e.toString();
      });
    }
  }

  void _pollAck(String opId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final status = await widget.api.startAckStatus(opId);
        if (!mounted) return;
        setState(() => _ackStatus = status);
        if (['completed', 'failed', 'busy', 'rejected', 'duplicate_ignored'].contains(status)) {
          timer.cancel();
        }
      } catch (_) {
        // transient network hiccup — keep polling, next tick will retry
      }
    });
  }

  Future<void> _promptPrice(String type, double defaultPrice) async {
    final controller = TextEditingController(text: defaultPrice.toStringAsFixed(2));
    final price = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start ${type.replaceAll('_', ' ')}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Price (RM)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(controller.text)), child: const Text('Send Credit')),
        ],
      ),
    );
    if (price != null && price > 0) _start(type, price);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Start')),
      body: _device == null
          ? _buildEmptyState()
          : _buildDeviceView(_device!),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Scan a machine\'s QR code to send a credit pulse and start it.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            FilledButton.icon(
              onPressed: _loading ? null : _scanAndLoad,
              icon: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Device'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceView(DeviceDetail device) {
    final outlet = device.outlet;
    final params = device.parameters;
    final isWasher = outlet?.machineType == 'Washer';

    final modes = isWasher
        ? [('washer_warm', 'Normal', params.washerWarmPrice), ('washer_cold', 'Cold', params.washerColdPrice), ('washer_hot', 'Hot', params.washerHotPrice)]
        : [('dryer_low', 'Low', params.dryerLowPrice), ('dryer_med', 'Medium', params.dryerMedPrice), ('dryer_hi', 'High', params.dryerHiPrice)];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.serialNumber, style: Theme.of(context).textTheme.titleMedium),
                Text('${outlet?.outletName ?? '—'} · ${outlet?.machineType ?? ''} #${outlet?.machineNum ?? ''}'),
                Row(children: [
                  Icon(Icons.circle, size: 10, color: outlet?.isOnline == true ? Colors.green : Colors.red),
                  const SizedBox(width: 6),
                  Text(outlet?.isOnline == true ? 'Online' : 'Offline'),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (outlet?.isOnline != true)
          const Card(
            color: Color(0xFFFFF3E0),
            child: Padding(padding: EdgeInsets.all(12), child: Text('This machine is offline — starting is likely to fail.')),
          ),
        const SizedBox(height: 8),
        ...modes.map((m) => Card(
              child: ListTile(
                title: Text(m.$2),
                trailing: Text('RM ${m.$3.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => _promptPrice(m.$1, m.$3),
              ),
            )),
        const SizedBox(height: 16),
        if (_ackStatus != null) _buildAckBanner(_ackStatus!),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: _scanAndLoad, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan Another Device')),
      ],
    );
  }

  Widget _buildAckBanner(String status) {
    late Color bg;
    late String text;
    switch (status) {
      case 'completed':
        bg = Colors.green.shade50;
        text = '✅ Credit sent — machine received it. Press Start on the machine.';
        break;
      case 'busy':
      case 'rejected':
      case 'duplicate_ignored':
        bg = Colors.orange.shade50;
        text = '⚠️ Machine could not accept the credit ($status).';
        break;
      case 'sending':
      case 'received':
        bg = Colors.blue.shade50;
        text = 'Sending credit to the machine…';
        break;
      default:
        bg = Colors.grey.shade100;
        text = 'Status: $status';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text),
    );
  }
}
