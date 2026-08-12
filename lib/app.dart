import 'package:flutter/material.dart';

import 'core/ads/ad_service.dart';
import 'core/licensing/license_repository.dart';
import 'core/storage/profile_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/profiles/profile_gate.dart';

class OpnManagerApp extends StatefulWidget {
  const OpnManagerApp({
    super.key,
    required this.profileRepository,
    required this.licenseRepository,
    required this.adService,
  });

  final ProfileRepository profileRepository;
  final LicenseRepository licenseRepository;
  final AdService adService;

  @override
  State<OpnManagerApp> createState() => _OpnManagerAppState();
}

class _OpnManagerAppState extends State<OpnManagerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.adService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Netsource Sentinel',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: ProfileGate(
        repository: widget.profileRepository,
        licenseRepository: widget.licenseRepository,
        adService: widget.adService,
        themeMode: _themeMode,
        onThemeModeChanged: (value) => setState(() => _themeMode = value),
      ),
    );
  }
}
