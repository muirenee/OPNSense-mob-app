import 'package:flutter/material.dart';

import 'core/storage/profile_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/profiles/profile_gate.dart';

class OpnManagerApp extends StatefulWidget {
  const OpnManagerApp({super.key, required this.profileRepository});

  final ProfileRepository profileRepository;

  @override
  State<OpnManagerApp> createState() => _OpnManagerAppState();
}

class _OpnManagerAppState extends State<OpnManagerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Netsource OPN Manager',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: ProfileGate(
        repository: widget.profileRepository,
        themeMode: _themeMode,
        onThemeModeChanged: (value) => setState(() => _themeMode = value),
      ),
    );
  }
}
