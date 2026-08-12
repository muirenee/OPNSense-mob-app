# Netsource Sentinel — Play Console Submission Checklist

This checklist is the release gate for the first public Google Play submission of Netsource Sentinel Free.

## 1. Developer and AdMob accounts
- Complete Google Play developer identity verification.
- Prefer an Organization account when publishing under a company/brand.
- Confirm the public developer name, support email, phone and website.
- Create/verify the AdMob account and add Android app **com.netsource.sentinel**.
- Create a banner ad unit for Sentinel.
- Configure Google Privacy & messaging / UMP consent messages for applicable regions.
- If a newly created personal Play account is subject to Google's testing requirement, complete the required testing before requesting production access.

## 2. App identity
- App name: **Netsource Sentinel**.
- Android application ID: **com.netsource.sentinel**.
- Keep this package ID unchanged.
- Free public release: **1.1.0**, versionCode/build **110**.

## 3. Android release
- Target Android 16 / API 36.
- Build and upload the signed `app-release.aab` from the permanent release pipeline.
- Enroll the application in Play App Signing.
- Keep the upload/release keystore and credentials outside Git.
- Confirm the expected upload certificate before the first production release.
- Retain an independently backed-up copy of upload-key material.

## 4. AdMob production configuration
- Keep Google's sample/test AdMob IDs for development and CI validation only.
- Add GitHub Actions secret `SENTINEL_ADMOB_APP_ID` with the real Sentinel AdMob Android app ID.
- Add GitHub Actions secret `SENTINEL_ADMOB_BANNER_ID` with the real banner ad unit ID.
- Confirm the production build reports that production AdMob identifiers are configured.
- Confirm ads appear only on the top-level Sentinel shell and never on credentials, add/edit forms or operational action routes.
- Confirm Demo Mode does not display advertising.
- Confirm the **Ad privacy choices** menu appears when UMP reports that privacy options are required.

## 5. Store listing
- App name and short description.
- Full description clearly states the Free edition supports one firewall and contains ads.
- App category: Tools.
- 512 x 512 high-resolution PNG app icon.
- 1024 x 500 feature graphic.
- At least two representative phone screenshots; four or more are preferred.
- Avoid screenshots containing secrets, private firewall addresses, customer names or production credentials.

## 6. Privacy and legal
- Publish the Privacy Policy on a public HTTPS page accessible without login.
- Configure that public URL in Play Console.
- Keep equivalent privacy information accessible from inside the app.
- Complete the Data Safety questionnaire against the exact production binary, including data practices of Google Mobile Ads and UMP.
- Review and publish the EULA/Terms page.
- Maintain Third-Party Notices for Flutter dependencies, Google Mobile Ads and OPNsense interoperability/trademark notice.
- Obtain appropriate business/legal review before broad public distribution.

## 7. Data Safety working inventory for v1.1
Validate these against the production Google Mobile Ads SDK documentation, UMP configuration and final binary:
- Firewall API keys/secrets: stored locally; transmitted only to the firewall configured by the user; not provided to advertisers.
- Firewall profile URL/name: stored locally by the app.
- Advertising: Google Mobile Ads may process advertising/device identifiers, IP address, app/device information, ad interactions and diagnostics for advertising, measurement, fraud prevention and related purposes.
- Consent: Google User Messaging Platform is used to collect or manage advertising privacy choices where required.
- Android Advertising ID permission is present for the ad-supported release.
- Free release does not require Sentinel licensing-server activation.
- Demo Mode: local sample data only and advertising suppressed.

Re-audit Data Safety whenever the advertising SDK, consent configuration, analytics, crash reporting, licensing, billing or authentication behavior changes.

## 8. App access / reviewer instructions
- State that no login is required for Demo Mode.
- Reviewer path: launch app → **Explore Demo Mode**.
- Explain that Demo Mode does not contact or change a firewall and does not show ads.
- Do not provide production firewall credentials in Play Console.

## 9. Content and declarations
- Complete Content Rating accurately.
- Declare target audience accurately; Sentinel is an IT administration tool, not a children's app.
- Complete the Play **Contains ads** declaration as **Yes** for the Free build.
- Review permissions in the final manifest: Internet and Advertising ID are expected for the ad-supported Android release; avoid unrelated sensitive permissions.

## 10. Testing tracks
- Upload the v1.1 AAB to Internal testing first.
- Install from Google Play on at least two physical Android devices when possible.
- Test Demo Mode with and without network connectivity.
- Test a real firewall over LAN/VPN and HTTPS.
- Verify exactly one real firewall can be saved on Free.
- Verify edit/delete/replace of the saved firewall still works.
- Verify ads never cover app navigation or management controls.
- Verify consent flows and privacy-options re-entry using Google test/debug geography where appropriate.
- Test dark/light/system appearance.
- Promote to Closed testing before Production when required or when broader validation is desired.

## 11. Production release gate
Do not promote to production until all of the following are true:
- CI Analyze and all tests pass.
- Signed APK verification passes.
- AAB exists and `jarsigner -verify` succeeds.
- API 36 target confirmed.
- Real AdMob app and banner IDs are configured; no Google sample/test IDs remain in the production build.
- UMP privacy messages are configured in AdMob.
- Demo Mode reviewed end-to-end.
- Public Privacy Policy URL is live.
- Data Safety form matches actual advertising and app behavior.
- Play **Contains ads** declaration is Yes.
- Final icon/feature graphic/screenshots are uploaded.
- No paid activation or external digital-purchase flow is exposed in the Free build.
- No production firewall credentials or signing secrets are committed to the repository.

## 12. Future Pro release
When paid monetization becomes available:
- keep package `com.netsource.sentinel` and the same Play listing;
- add Play Billing or the approved entitlement source rather than creating a second app by default;
- grant a Pro/MSP entitlement through the existing licensing abstraction;
- increase `maxFirewalls` according to the plan;
- disable advertising automatically when the entitlement is commercial;
- re-audit Play Payments policy, Data Safety, privacy policy and release notes before enabling purchases.

## 13. Post-launch
- Monitor Play pre-launch reports, Android vitals and AdMob policy notifications.
- Respond to crashes and OPNsense API compatibility regressions.
- Keep OPNsense version-compatibility notes current.
- Increment versionCode for every Play upload.
- Re-run privacy/Data Safety review whenever data handling or SDKs change.
