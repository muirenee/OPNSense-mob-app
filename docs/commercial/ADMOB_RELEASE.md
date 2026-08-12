# Netsource Sentinel Free — AdMob Release Guide

## Product model
- Free edition: one real firewall, supported management features, advertising enabled.
- Demo Mode: local sample profile; advertising suppressed.
- Future Pro/MSP entitlement: multiple firewalls and advertising disabled.
- Keep Android package `com.netsource.sentinel` for all editions.

## Development and CI safety
The source defaults to Google's Android sample AdMob application ID and test banner unit ID. This lets CI compile and lets development devices exercise the ad layout without generating live ad traffic.

Do not publish a production Play release while the app still reports **AdMob test configuration**.

## Create the production AdMob configuration
1. In AdMob, add the Android app with package `com.netsource.sentinel`.
2. Create a Banner ad unit for Netsource Sentinel.
3. Configure Privacy & messaging / User Messaging Platform messages for the regions where they are required.
4. Add these GitHub Actions repository secrets:
   - `SENTINEL_ADMOB_APP_ID` — the AdMob Android application ID (`ca-app-pub-...~...`).
   - `SENTINEL_ADMOB_BANNER_ID` — the Sentinel banner ad unit ID (`ca-app-pub-.../...`).
5. Re-run the Android Release workflow. The **Report AdMob build mode** step must state that production identifiers are configured.
6. Install the internal-test Play build and confirm ads/consent behavior before production rollout.

Do not commit the production identifiers merely to make the build work; keeping them in release configuration makes test-vs-production behavior explicit.

## Consent flow
At app launch Sentinel requests updated consent information through Google UMP. It then loads/shows a consent form if required. Ads are requested only when UMP reports that ads can be requested. If UMP reports that privacy options must remain accessible, Sentinel exposes **More → Ad privacy choices**.

## Placement rules
Banner advertising is rendered only in the main application shell for a real Free-plan firewall. It is intentionally absent from:
- firewall-profile/API credential entry;
- Demo Mode;
- firewall/NAT add and edit routes;
- diagnostics operation screens;
- user/group and captive-portal add/edit routes;
- destructive/action dialogs and confirmation screens.

Never add an interstitial between an administrator and a firewall management action without a separate product/policy review.

## Pre-production checks
- Real AdMob app ID configured.
- Real banner ad unit configured.
- UMP messages published/configured.
- Public Privacy Policy includes advertising and consent disclosures.
- Google Play **Contains ads** = Yes.
- Data Safety answers include the relevant Google Mobile Ads/UMP data practices.
- Test on at least two physical devices and at least one small-screen layout.
- Verify banner never covers navigation, save/apply, form controls or firewall status content.
- Verify Demo Mode is ad-free.
- Verify Free cannot save a second real firewall.
- Verify replacing the one saved firewall remains possible by edit/delete.

## Future Pro
When a paid entitlement becomes available, do not fork the application by default. The current entitlement model exposes `adsEnabled` and `maxFirewalls`; a commercial entitlement therefore removes ads and raises the firewall limit without changing package identity or the ad placement code.
