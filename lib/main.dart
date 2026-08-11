import 'package:flutter/material.dart';

import 'app.dart';
import 'core/storage/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final profileRepository = ProfileRepository();
  await profileRepository.initialize();
  runApp(OpnManagerApp(profileRepository: profileRepository));
}
