# Netsource Sentinel native ads bridge

The v1.1.3 Android ad integration deliberately does not use the `google_mobile_ads` Flutter plugin. Field testing showed that binaries containing that plugin crashed before Sentinel could open, while the same application without the plugin launched normally.

Sentinel therefore owns a small Android bridge:

- Flutter starts normally without directly loading Google Ads classes.
- A MethodChannel requests consent/ads initialization only after the real firewall shell has been visible for a short delay.
- The Google-dependent runtime is loaded by reflection and all bridge boundaries fail open.
- UMP controls whether ads may be requested.
- Banner ads are exposed as a Sentinel-owned Android platform view.
- Google Mobile Ads' eager `MobileAdsInitProvider` is removed from the merged manifest; initialization is explicit.
- Demo Mode remains ad-free and the Free entitlement remains limited to one real firewall.

Production builds provide `SENTINEL_ADMOB_APP_ID` and `SENTINEL_ADMOB_BANNER_ID`. Validation builds use Google's sample app/banner IDs.
