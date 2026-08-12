import 'package:flutter/material.dart';

import 'app.dart';
import 'core/ads/ad_service.dart';
import 'core/licensing/license_repository.dart';
import 'core/storage/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final profileRepository = ProfileRepository();
  final licenseRepository = LicenseRepository();
  final adService = AdService();
  await Future.wait([
    profileRepository.initialize(),
    licenseRepository.initialize(),
  ]);

  runApp(
    OpnManagerApp(
      profileRepository: profileRepository,
      licenseRepository: licenseRepository,
      adService: adService,
    ),
  );
}
