import 'package:flutter/material.dart';

import '../../core/ads/ad_service.dart';
import '../../core/app_info.dart';
import '../../core/licensing/license_repository.dart';
import '../../core/storage/profile_repository.dart';
import '../shell/main_shell.dart';
import 'firewall_profile.dart';
import 'profile_setup_screen.dart';

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.repository,
    required this.licenseRepository,
    required this.adService,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ProfileRepository repository;
  final LicenseRepository licenseRepository;
  final AdService adService;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  bool _adInitializationScheduled = false;

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

  void _scheduleAdInitialization(FirewallProfile profile) {
    if (_adInitializationScheduled ||
        profile.isDemo ||
        !AppInfo.adsEnabled ||
        !widget.licenseRepository.entitlement.adsEnabled) {
      return;
    }
    _adInitializationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Give the real firewall shell time to become fully visible before any
      // Google advertising class is loaded. Ads are optional; Sentinel is not.
      Future<void>.delayed(const Duration(milliseconds: 2500), () async {
        if (!mounted) return;
        await widget.adService.initialize();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.repository.selectedProfile;
    if (selected == null) {
      return ProfileSetupScreen(
        repository: widget.repository,
        licenseRepository: widget.licenseRepository,
      );
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
            licenseRepository: widget.licenseRepository,
            initialProfile: selected,
          );
        }

        _scheduleAdInitialization(selected);
        return MainShell(
          repository: widget.repository,
          licenseRepository: widget.licenseRepository,
          adService: widget.adService,
          profile: selected,
          credentials: credentials,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        );
      },
    );
  }
}
