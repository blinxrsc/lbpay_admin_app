import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Generic reusable scanner: pops the route with the extracted device
/// serial once a code is read, or null if the user backs out.
/// Expects the QR to encode the serial directly, or a URL ending in it
/// (e.g. the same QR customers scan, "https://lbpaylinker.com/device/<serial>").
class QrScanScreen extends StatefulWidget {
  final String title;
  const QrScanScreen({super.key, this.title = 'Scan Device QR'});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;

  String _extractSerial(String raw) {
    final trimmed = raw.trim();
    return trimmed.contains('/') ? trimmed.split('/').last : trimmed;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null) return;
    _handled = true;
    Navigator.of(context).pop(_extractSerial(raw));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: const Text('Point the camera at the device\'s QR code', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
