import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/profiles/firewall_profile.dart';

class ProfileRepository extends ChangeNotifier {
  static const _profilesKey = 'firewall_profiles_v1';
  static const _selectedProfileKey = 'selected_profile_id_v1';
  static const _demoProfileId = '__demo__';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late SharedPreferences _preferences;

  final List<FirewallProfile> _profiles = [];
  String? _selectedProfileId;

  List<FirewallProfile> get profiles => List.unmodifiable(_profiles);
  String? get selectedProfileId => _selectedProfileId;

  FirewallProfile? get selectedProfile {
    if (_selectedProfileId == _demoProfileId) return FirewallProfile.demo;
    if (_selectedProfileId == null) return null;
    for (final profile in _profiles) {
      if (profile.id == _selectedProfileId) return profile;
    }
    return null;
  }

  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    _selectedProfileId = _preferences.getString(_selectedProfileKey);

    final raw = _preferences.getString(_profilesKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _profiles
        ..clear()
        ..addAll(decoded.map((item) => FirewallProfile.fromJson(
              Map<String, Object?>.from(item as Map),
            )));
    }

    if (selectedProfile == null && _profiles.isNotEmpty) {
      _selectedProfileId = _profiles.first.id;
    }
  }

  Future<void> saveProfile(
    FirewallProfile profile,
    FirewallCredentials credentials,
  ) async {
    if (profile.isDemo) {
      throw StateError('Demo Mode profiles are not persisted.');
    }
    final index = _profiles.indexWhere((item) => item.id == profile.id);
    if (index == -1) {
      _profiles.add(profile);
    } else {
      _profiles[index] = profile;
    }

    _selectedProfileId = profile.id;
    await _secureStorage.write(
      key: _credentialKey(profile.id, 'apiKey'),
      value: credentials.apiKey,
    );
    await _secureStorage.write(
      key: _credentialKey(profile.id, 'apiSecret'),
      value: credentials.apiSecret,
    );
    await _persist();
    notifyListeners();
  }

  Future<FirewallCredentials?> credentialsFor(String profileId) async {
    if (profileId == _demoProfileId) return FirewallCredentials.demo;
    final apiKey = await _secureStorage.read(
      key: _credentialKey(profileId, 'apiKey'),
    );
    final apiSecret = await _secureStorage.read(
      key: _credentialKey(profileId, 'apiSecret'),
    );
    if (apiKey == null || apiSecret == null) return null;
    return FirewallCredentials(apiKey: apiKey, apiSecret: apiSecret);
  }

  Future<void> select(String profileId) async {
    _selectedProfileId = profileId;
    await _preferences.setString(_selectedProfileKey, profileId);
    notifyListeners();
  }

  Future<void> selectDemo() => select(_demoProfileId);

  Future<void> delete(String profileId) async {
    if (profileId == _demoProfileId) {
      _selectedProfileId = _profiles.isEmpty ? null : _profiles.first.id;
      await _persist();
      notifyListeners();
      return;
    }
    _profiles.removeWhere((item) => item.id == profileId);
    await _secureStorage.delete(key: _credentialKey(profileId, 'apiKey'));
    await _secureStorage.delete(key: _credentialKey(profileId, 'apiSecret'));
    if (_selectedProfileId == profileId) {
      _selectedProfileId = _profiles.isEmpty ? null : _profiles.first.id;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _preferences.setString(
      _profilesKey,
      jsonEncode(_profiles.map((profile) => profile.toJson()).toList()),
    );
    if (_selectedProfileId == null) {
      await _preferences.remove(_selectedProfileKey);
    } else {
      await _preferences.setString(_selectedProfileKey, _selectedProfileId!);
    }
  }

  static String _credentialKey(String profileId, String field) =>
      'firewall_profile:$profileId:$field';
}
