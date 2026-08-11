import 'package:flutter/material.dart';

import '../../core/api/api_capabilities.dart';
import '../../core/api/opnsense_api_client.dart';
import '../profiles/firewall_profile.dart';

class CapabilitiesScreen extends StatefulWidget {
  const CapabilitiesScreen({
    super.key,
    required this.profile,
    required this.credentials,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<CapabilitiesScreen> createState() => _CapabilitiesScreenState();
}

class _CapabilitiesScreenState extends State<CapabilitiesScreen> {
  late final ApiCapabilityProbe _probe;
  late Future<List<ApiCapability>> _future;

  @override
  void initState() {
    super.initState();
    _probe = ApiCapabilityProbe(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _future = _probe.run();
  }

  Future<void> _refresh() async {
    setState(() => _future = _probe.run());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API capabilities')),
      body: FutureBuilder<List<ApiCapability>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snapshot.error.toString(), textAlign: TextAlign.center),
              ),
            );
          }
          final items = snapshot.data ?? const <ApiCapability>[];
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.profile.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Available means the endpoint responded to this API user. Permission denied is different from unsupported.',
                ),
                const SizedBox(height: 14),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _CapabilityTile(item: items[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({required this.item});

  final ApiCapability item;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (item.state) {
      ApiCapabilityState.available => (Icons.check_circle, Colors.green, 'Available'),
      ApiCapabilityState.forbidden => (
          Icons.lock_outline,
          Colors.orange,
          'Permission denied',
        ),
      ApiCapabilityState.unavailable => (
          Icons.remove_circle_outline,
          Theme.of(context).colorScheme.outline,
          'Unsupported',
        ),
      ApiCapabilityState.error => (
          Icons.error_outline,
          Theme.of(context).colorScheme.error,
          'Error',
        ),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${item.path}\n$label${item.message == null ? '' : ' · ${item.message}'}'),
      isThreeLine: item.message != null,
    );
  }
}
