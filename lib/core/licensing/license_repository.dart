import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../app_info.dart';
import 'license_models.dart';

class LicenseRepository extends ChangeNotifier {
  LicenseRepository({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
    String apiUrl = AppInfo.licenseApiUrl,
  })  : _secureStorage = secureStorage,
        _apiUrl = apiUrl.trim();

  static const _entitlementKey = 'sentinel_license_entitlement_v1';
  static const _installationIdKey = 'sentinel_installation_id_v1';

  final FlutterSecureStorage _secureStorage;
  final String _apiUrl;

  LicenseEntitlement _entitlement = LicenseEntitlement.free();
  String _installationId = '';
  bool _busy = false;
  String? _lastError;

  LicenseEntitlement get entitlement => _entitlement;
  String get installationId => _installationId;
  bool get busy => _busy;
  String? get lastError => _lastError;
  bool get serviceConfigured => _apiUrl.isNotEmpty;

  Future<void> initialize() async {
    _installationId = await _secureStorage.read(key: _installationIdKey) ?? '';
    if (_installationId.isEmpty) {
      _installationId = _newInstallationId();
      await _secureStorage.write(
        key: _installationIdKey,
        value: _installationId,
      );
    }

    final raw = await _secureStorage.read(key: _entitlementKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final loaded = LicenseEntitlement.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          _entitlement = loaded.isUsable ? loaded : LicenseEntitlement.free();
        }
      } catch (_) {
        _entitlement = LicenseEntitlement.free();
      }
    }
  }

  bool canAddFirewall(int currentCount) {
    final usable = _entitlement.isUsable ? _entitlement : LicenseEntitlement.free();
    return currentCount < usable.maxFirewalls;
  }

  Future<void> activate(String activationCode) async {
    final code = activationCode.trim();
    if (code.isEmpty) throw StateError('Enter an activation code.');
    _requireService();
    await _run(() async {
      final response = await _dio().post<dynamic>(
        '/v1/licenses/activate',
        data: {
          'activation_code': code,
          'installation_id': _installationId,
          'package_id': AppInfo.packageId,
          'app_version': AppInfo.version,
          'build_number': AppInfo.buildNumber,
          'platform': 'android',
        },
      );
      await _acceptResponse(response.data);
    });
  }

  Future<void> refresh() async {
    _requireService();
    if (_entitlement.leaseToken.isEmpty) {
      throw StateError('No active commercial license is stored on this device.');
    }
    await _run(() async {
      final response = await _dio().post<dynamic>(
        '/v1/licenses/refresh',
        data: {
          'lease_token': _entitlement.leaseToken,
          'installation_id': _installationId,
          'package_id': AppInfo.packageId,
          'app_version': AppInfo.version,
          'build_number': AppInfo.buildNumber,
        },
      );
      await _acceptResponse(response.data);
    });
  }

  Future<void> deactivate() async {
    final previous = _entitlement;
    if (_apiUrl.isNotEmpty && previous.leaseToken.isNotEmpty) {
      try {
        await _dio().post<dynamic>(
          '/v1/licenses/deactivate',
          data: {
            'lease_token': previous.leaseToken,
            'installation_id': _installationId,
          },
        );
      } catch (_) {
        // Local deactivation must remain available if the licensing service is
        // temporarily unreachable. The server can expire the lease separately.
      }
    }
    _entitlement = LicenseEntitlement.free();
    _lastError = null;
    await _secureStorage.delete(key: _entitlementKey);
    notifyListeners();
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      await action();
    } on DioException catch (error) {
      final data = error.response?.data;
      final detail = data is Map
          ? (data['message'] ?? data['error'])?.toString()
          : null;
      _lastError = detail?.trim().isNotEmpty == true
          ? detail
          : 'Unable to contact the Netsource Sentinel licensing service.';
      throw StateError(_lastError!);
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _acceptResponse(dynamic raw) async {
    if (raw is! Map) {
      throw StateError('The licensing service returned an invalid response.');
    }
    final response = Map<String, dynamic>.from(raw);
    final source = response['entitlement'] is Map
        ? Map<String, dynamic>.from(response['entitlement'] as Map)
        : response;
    final entitlement = LicenseEntitlement.fromJson(source);
    if (!entitlement.isUsable || entitlement.leaseToken.isEmpty) {
      throw StateError(
        response['message']?.toString() ?? 'The license is not active.',
      );
    }
    _entitlement = entitlement;
    await _secureStorage.write(
      key: _entitlementKey,
      value: jsonEncode(entitlement.toJson()),
    );
  }

  Dio _dio() {
    return Dio(
      BaseOptions(
        baseUrl: _apiUrl.replaceAll(RegExp(r'/+$'), ''),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
        headers: const {'Accept': 'application/json'},
      ),
    );
  }

  void _requireService() {
    if (_apiUrl.isEmpty) {
      throw StateError(
        'Commercial licensing is not configured in this build. '
        'Set SENTINEL_LICENSE_API_URL when building the production release.',
      );
    }
  }

  static String _newInstallationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(16)}-$hex';
  }
}
