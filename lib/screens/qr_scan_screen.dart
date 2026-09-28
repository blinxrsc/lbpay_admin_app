import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api_service.dart';
import 'device_detail_screen.dart';

/// Expects the QR code to encode the device serial number directly (e.g.
/// "NYJ312007A100216290"), or a URL ending in it (e.g.
/// "https://lbpaylinker.com/device/NYJ312007A100216290" — the same QR
/// customers scan). Adjust `_extractSerial` if your printed QR format
/// differs.
class QrScanScreen extends StatefulWidget {
  final ApiService api;
  const QrScanScreen({super.key, required this.api});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;

  String _extractSerial(String raw) {
    final trimmed = raw.trim();
    if (trimmed.contains('/')) {
      return trimmed.split('/').last;
    }
    return trimmed;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null) return;

    _handled = true;
    final serial = _extractSerial(raw);

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => DeviceDetailScreen(api: widget.api, serial: serial)))
        .then((_) => setState(() => _handled = false));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Device QR')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
