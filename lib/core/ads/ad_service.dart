import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ad_config.dart';

class AdService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel(
    'com.netsource.sentinel/ads',
  );

  bool _initializing = false;
  bool _initialized = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  String? _lastError;

  bool get initialized => _initialized;
  bool get canRequestAds => AdConfig.enabled && _canRequestAds;
  bool get privacyOptionsRequired => _privacyOptionsRequired;
  bool get usingTestAds => AdConfig.usingTestAds;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    _lastError = null;

    try {
      if (!AdConfig.enabled) return;

      final state = await _channel
          .invokeMapMethod<String, dynamic>('initialize')
          .timeout(const Duration(seconds: 45));
      _applyState(state);
    } on TimeoutException {
      _lastError = 'Advertising initialization timed out.';
      _canRequestAds = false;
    } on MissingPluginException {
      _lastError = 'Native advertising bridge is unavailable.';
      _canRequestAds = false;
    } on PlatformException catch (error) {
      _lastError = error.message ?? error.code;
      _canRequestAds = false;
    } catch (error) {
      _lastError = error.toString();
      _canRequestAds = false;
    } finally {
      _initialized = true;
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> showPrivacyOptions() async {
    if (!_privacyOptionsRequired || !AdConfig.enabled) return;

    try {
      final state = await _channel
          .invokeMapMethod<String, dynamic>('showPrivacyOptions')
          .timeout(const Duration(seconds: 45));
      _applyState(state);
    } on TimeoutException {
      _lastError = 'Privacy options timed out.';
    } on MissingPluginException {
      _lastError = 'Native advertising bridge is unavailable.';
      _canRequestAds = false;
    } on PlatformException catch (error) {
      _lastError = error.message ?? error.code;
    } catch (error) {
      _lastError = error.toString();
    } finally {
      notifyListeners();
    }
  }

  void _applyState(Map<String, dynamic>? state) {
    if (state == null) {
      _canRequestAds = false;
      return;
    }

    _canRequestAds = state['canRequestAds'] == true;
    _privacyOptionsRequired = state['privacyOptionsRequired'] == true;

    final error = state['lastError'];
    _lastError = error is String && error.trim().isNotEmpty ? error.trim() : null;
  }
}
