import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'config_network_screen.dart';
import 'config_parameter_screen.dart';
import 'quick_start_screen.dart';

class DeviceInstallScreen extends StatelessWidget {
  final ApiService api;
  const DeviceInstallScreen({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Install')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OptionCard(
            icon: Icons.play_circle_fill,
            color: Colors.green,
            title: 'Quick Start',
            subtitle: 'Scan a machine and send a paid credit pulse to it.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QuickStartScreen(api: api))),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.wifi,
            color: Colors.blue,
            title: 'Config Network',
            subtitle: 'Scan a device and set its WiFi SSID/password over Bluetooth.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfigNetworkScreen())),
          ),
          const SizedBox(height: 12),
          _OptionCard(
            icon: Icons.tune,
            color: Colors.deepPurple,
            title: 'Config Parameter',
            subtitle: 'Scan a device and edit its prices, pulse and coin-signal settings.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConfigParameterScreen(api: api))),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
