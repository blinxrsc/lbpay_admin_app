import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/qr_scan_screen.dart';

void main() {
  runApp(const LbTechnicianApp());
}

class LbTechnicianApp extends StatelessWidget {
  const LbTechnicianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LB Admin',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: _AuthGate(api: ApiService()),
    );
  }
}

class _AuthGate extends StatefulWidget {
  final ApiService api;
  const _AuthGate({required this.api});

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<bool> _loggedIn = widget.api.isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loggedIn,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data!
            ? QrScanScreen(api: widget.api)
            : LoginScreen(api: widget.api);
      },
    );
  }
}
