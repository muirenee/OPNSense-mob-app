import 'package:flutter/material.dart';

import '../../core/storage/profile_repository.dart';
import '../capabilities/capabilities_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../firewall/firewall_module_screen.dart';
import '../network/network_module_screen.dart';
import '../audit/audit_screen.dart';
import '../profiles/firewall_profile.dart';
import '../services/services_screen.dart';
import '../vpn/vpn_screen.dart';
import '../diagnostics/diagnostics_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.repository,
    required this.profile,
    required this.credentials,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ProfileRepository repository;
  final FirewallProfile profile;
  final FirewallCredentials credentials;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(profile: widget.profile, credentials: widget.credentials),
      FirewallModuleScreen(profile: widget.profile, credentials: widget.credentials),
      NetworkModuleScreen(profile: widget.profile, credentials: widget.credentials),
      VpnScreen(profile: widget.profile, credentials: widget.credentials),
      _MoreScreen(
        repository: widget.repository,
        profile: widget.profile,
        credentials: widget.credentials,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Netsource Sentinel'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                widget.profile.name,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined),
            label: 'Firewall',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            label: 'Network',
          ),
          NavigationDestination(
            icon: Icon(Icons.vpn_lock_outlined),
            label: 'VPN',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen({
    required this.repository,
    required this.profile,
    required this.credentials,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ProfileRepository repository;
  final FirewallProfile profile;
  final FirewallCredentials credentials;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme'),
                trailing: DropdownButton<ThemeMode>(
                  value: themeMode,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onThemeModeChanged(value);
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.miscellaneous_services_outlined),
                title: const Text('Services'),
                subtitle: const Text('Start, stop and restart firewall services'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ServicesScreen(
                        profile: profile,
                        credentials: credentials,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.troubleshoot_outlined),
                title: const Text('Diagnostics'),
                subtitle: const Text('Ping, traceroute, DNS, routes and packet capture'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DiagnosticsScreen(
                        profile: profile,
                        credentials: credentials,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('API capabilities'),
                subtitle: const Text('Check endpoint support and permissions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CapabilitiesScreen(
                        profile: profile,
                        credentials: credentials,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('App audit trail'),
                subtitle: const Text('Review service and firewall changes made from this app'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AuditScreen(profileId: profile.id),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Switch firewall'),
                subtitle: const Text('Return to firewall profiles'),
                onTap: () => repository.select('__none__'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Netsource Sentinel · Version 0.4.0'),
            subtitle: Text(
              'VPN · diagnostics · PCAP · safe firewall/service actions',
            ),
          ),
        ),
      ],
    );
  }
}
