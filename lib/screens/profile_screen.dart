import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ApiService api;
  const ProfileScreen({super.key, required this.api});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.profile();
      setState(() => _profile = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final p = _profile!;
    final roles = (p['roles'] as List?)?.join(', ') ?? '—';
    final permissions = (p['permissions'] as List?)?.cast<String>() ?? [];
    final allOutlets = p['can_access_all_outlets'] == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CircleAvatar(radius: 32, child: Text((p['name'] ?? '?').toString().substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 28))),
        const SizedBox(height: 12),
        Center(child: Text(p['name'] ?? '', style: Theme.of(context).textTheme.titleLarge)),
        Center(child: Text(p['email'] ?? '', style: const TextStyle(color: Colors.grey))),
        const SizedBox(height: 24),
        ListTile(leading: const Icon(Icons.badge), title: const Text('Role'), subtitle: Text(roles)),
        ListTile(
          leading: const Icon(Icons.store),
          title: const Text('Outlet Access'),
          subtitle: Text(allOutlets ? 'All outlets' : 'Outlets assigned to your account'),
        ),
        ExpansionTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Permissions'),
          children: permissions.map((perm) => ListTile(dense: true, title: Text(perm))).toList(),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout), label: const Text('Log Out')),
      ],
    );
  }
}
