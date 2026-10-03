import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class OutletListScreen extends StatefulWidget {
  final ApiService api;
  const OutletListScreen({super.key, required this.api});

  @override
  State<OutletListScreen> createState() => _OutletListScreenState();
}

class _OutletListScreenState extends State<OutletListScreen> {
  List<OutletSummary> _outlets = [];
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
      final outlets = await widget.api.outlets();
      setState(() => _outlets = outlets);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outlets')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.red)))])
                : _outlets.isEmpty
                    ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Text('No outlets assigned to your account yet.'))])
                    : ListView.builder(
                        itemCount: _outlets.length,
                        itemBuilder: (context, i) {
                          final o = _outlets[i];
                          return ListTile(
                            leading: const Icon(Icons.store),
                            title: Text(o.name),
                            subtitle: Text(o.city ?? ''),
                            trailing: Text('${o.onlineCount}/${o.deviceCount} online', style: TextStyle(color: o.onlineCount == o.deviceCount ? Colors.green : Colors.orange)),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => OutletDevicesScreen(api: widget.api, outlet: o)),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class OutletDevicesScreen extends StatefulWidget {
  final ApiService api;
  final OutletSummary outlet;
  const OutletDevicesScreen({super.key, required this.api, required this.outlet});

  @override
  State<OutletDevicesScreen> createState() => _OutletDevicesScreenState();
}

class _OutletDevicesScreenState extends State<OutletDevicesScreen> {
  List<OutletDeviceSummary> _devices = [];
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
      final devices = await widget.api.outletDevices(widget.outlet.id);
      setState(() => _devices = devices);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.outlet.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.red)))])
                : _devices.isEmpty
                    ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Text('No devices installed at this outlet yet.'))])
                    : ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, i) {
                          final d = _devices[i];
                          return ListTile(
                            leading: Icon(Icons.circle, size: 12, color: d.isOnline ? Colors.green : Colors.red),
                            title: Text('${d.machineType ?? ''} #${d.machineNum ?? ''} — ${d.machineName ?? ''}'),
                            subtitle: Text(d.serialNumber),
                            trailing: Text(d.availability ? 'Available' : 'Busy'),
                          );
                        },
                      ),
      ),
    );
  }
}
