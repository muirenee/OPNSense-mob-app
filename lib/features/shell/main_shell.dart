import 'package:flutter/material.dart';

import '../../core/storage/profile_repository.dart';
import '../audit/audit_screen.dart';
import '../capabilities/capabilities_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../firewall/firewall_module_screen.dart';
import '../network/network_module_screen.dart';
import '../profiles/firewall_profile.dart';
import '../profiles/profile_setup_screen.dart';
import '../services/services_screen.dart';
import '../system/firmware_screen.dart';
import '../vpn/vpn_screen.dart';

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

  void _selectTab(int index) {
    if (index < 0 || index > 4 || index == _index) return;
    setState(() => _index = index);
  }

  void _editProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSetupScreen(
          repository: widget.repository,
          initialProfile: widget.profile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        profile: widget.profile,
        credentials: widget.credentials,
        onSelectMainTab: _selectTab,
      ),
      FirewallModuleScreen(
        profile: widget.profile,
        credentials: widget.credentials,
      ),
      NetworkModuleScreen(
        profile: widget.profile,
        credentials: widget.credentials,
      ),
      VpnScreen(
        profile: widget.profile,
        credentials: widget.credentials,
      ),
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
        leading: Padding(
          padding: const EdgeInsets.all(9),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        title: const Text('Netsource Sentinel'),
        actions: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: TextButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: Text(
                widget.profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined),
            selectedIcon: Icon(Icons.security),
            label: 'Firewall',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: 'Network',
          ),
          NavigationDestination(
            icon: Icon(Icons.vpn_lock_outlined),
            selectedIcon: Icon(Icons.vpn_lock),
            label: 'VPN',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
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

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Management',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'System tools and Sentinel preferences',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Firewall profile'),
                subtitle: Text(profile.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(
                  context,
                  ProfileSetupScreen(
                    repository: repository,
                    initialProfile: profile,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.system_update_alt),
                title: const Text('System updates'),
                subtitle: const Text('Check and install available updates'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(
                  context,
                  FirmwareScreen(
                    profile: profile,
                    credentials: credentials,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.miscellaneous_services_outlined),
                title: const Text('Services'),
                subtitle: const Text('Start, stop and restart firewall services'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(
                  context,
                  ServicesScreen(
                    profile: profile,
                    credentials: credentials,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.troubleshoot_outlined),
                title: const Text('Diagnostics'),
                subtitle: const Text(
                  'Ping, traceroute, DNS, routes and packet capture',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(
                  context,
                  DiagnosticsScreen(
                    profile: profile,
                    credentials: credentials,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('API capabilities'),
                subtitle: const Text('Check endpoint support and permissions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(
                  context,
                  CapabilitiesScreen(
                    profile: profile,
                    credentials: credentials,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('App audit trail'),
                subtitle: const Text(
                  'Review service and firewall changes made from this app',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(
                  context,
                  AuditScreen(profileId: profile.id),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Appearance'),
                subtitle: const Text('Follow system, light or dark'),
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
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Switch firewall'),
                subtitle: const Text('Return to saved firewall profiles'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => repository.select('__none__'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Netsource Sentinel · Version 0.5.2'),
            subtitle: Text(
              'KEA DHCP · unified navigation · improved diagnostics',
            ),
          ),
        ),
      ],
    );
  }
}
