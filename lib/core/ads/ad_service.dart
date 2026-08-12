import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

class AdService extends ChangeNotifier {
  bool _initializing = false;
  bool _initialized = false;
  bool _canRequestAds = false;
  bool _mobileAdsInitialized = false;
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

    if (!AdConfig.enabled) {
      _initialized = true;
      _initializing = false;
      notifyListeners();
      return;
    }

    final update = Completer<FormError?>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!update.isCompleted) update.complete(null);
      },
      (FormError error) {
        if (!update.isCompleted) update.complete(error);
      },
    );

    try {
      final updateError = await update.future;
      if (updateError != null) {
        _lastError = updateError.message;
      } else {
        final form = Completer<FormError?>();
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (!form.isCompleted) form.complete(error);
        });
        final formError = await form.future;
        if (formError != null) _lastError = formError.message;
      }
    } catch (error) {
      _lastError = error.toString();
    }

    await _refreshConsentState();
    _initialized = true;
    _initializing = false;
    notifyListeners();
  }

  Future<void> showPrivacyOptions() async {
    if (!_privacyOptionsRequired) return;
    final form = Completer<FormError?>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (!form.isCompleted) form.complete(error);
    });
    final error = await form.future;
    if (error != null) {
      _lastError = error.message;
    } else {
      _lastError = null;
    }
    await _refreshConsentState();
    notifyListeners();
  }

  Future<void> _refreshConsentState() async {
    try {
      _privacyOptionsRequired =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
              PrivacyOptionsRequirementStatus.required;
      _canRequestAds = await ConsentInformation.instance.canRequestAds();

      if (_canRequestAds && !_mobileAdsInitialized) {
        await MobileAds.instance.initialize();
        _mobileAdsInitialized = true;
      }
    } catch (error) {
      _lastError ??= error.toString();
      _canRequestAds = false;
    }
  }
}
