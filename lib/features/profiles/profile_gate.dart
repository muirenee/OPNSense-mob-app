import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../../core/storage/profile_repository.dart';
import '../shell/main_shell.dart';
import 'firewall_profile.dart';
import 'profile_setup_screen.dart';

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.repository,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ProfileRepository repository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final selected = widget.repository.selectedProfile;
    if (selected == null) {
      return ProfileSetupScreen(repository: widget.repository);
    }

    return FutureBuilder<FirewallCredentials?>(
      future: widget.repository.credentialsFor(selected.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final credentials = snapshot.data;
        if (credentials == null) {
          return ProfileSetupScreen(
            repository: widget.repository,
            initialProfile: selected,
          );
        }
        return MainShell(
          repository: widget.repository,
          profile: selected,
          credentials: credentials,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        );
      },
    );
  }
}
