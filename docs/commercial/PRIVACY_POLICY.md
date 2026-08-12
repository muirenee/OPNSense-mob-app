# Netsource Sentinel Privacy Policy

**Effective date: 12 August 2026**

This is the website/store master copy for the Netsource Sentinel Free v1.1 release. Publish it on a public HTTPS URL before production submission to Google Play and keep the published text aligned with the shipped binary.

## 1. Scope
Netsource Sentinel is a mobile management client for firewalls that expose compatible OPNsense APIs.

## 2. Firewall connection data
The app stores firewall profiles locally on the device. API keys and API secrets are stored using platform secure storage. Firewall API credentials are sent only to the firewall address configured by the user. They are not sent to Google, advertising partners or the Netsource Sentinel licensing service.

## 3. Free edition and advertising
Netsource Sentinel Free supports one saved firewall and uses Google AdMob through the Google Mobile Ads SDK to display advertising on selected top-level overview screens.

Advertising is intentionally excluded from Demo Mode and from credential-entry, add/edit and operational action screens.

Google advertising services may process information such as device or advertising identifiers, IP address, app/device information, ad interactions, diagnostics and information needed for ad delivery, measurement, fraud prevention and legal compliance. Google's processing is governed by Google's applicable terms and privacy policies.

Netsource Sentinel does not sell firewall credentials and does not provide firewall API keys or secrets to advertisers.

## 4. Consent and privacy choices
The app integrates Google's User Messaging Platform. Consent information is refreshed when the application starts. Where a consent form is required, it is displayed before advertising is requested. When Google reports that privacy options must remain available, Sentinel exposes an **Ad privacy choices** control so users can revisit those choices.

## 5. Licensing data
The public Free release does not require a Sentinel licensing server. The client keeps the entitlement architecture so a future Pro/MSP release can add paid entitlements without changing the application package.

If commercial licensing is enabled in a future build, the app may send an activation code, randomly generated installation identifier, package ID, app version/build number and opaque lease token to the Sentinel licensing service. Firewall API keys and secrets are not sent to that service.

## 6. Demo Mode
Demo Mode uses sample data generated locally by the application and does not contact a firewall. Advertising is suppressed while the Demo profile is active.

## 7. Security
Sensitive local values are stored using secure-storage facilities supplied by the operating system. Connections to real firewalls use HTTPS when configured by the user. A self-signed-certificate option is available for trusted firewalls controlled by the user; a publicly trusted CA certificate remains recommended where practical.

## 8. Retention and deletion
Deleting a firewall profile removes the API credentials stored for that profile from application secure storage. Uninstalling the application removes application-local data subject to the operating system's backup and restore behavior.

Advertising data handled by Google is retained according to Google's applicable policies and the user's privacy/consent choices.

## 9. Third-party services
The v1.1 Free application may communicate with:
- the firewall endpoint configured by the user;
- Google Mobile Ads / AdMob services for advertising;
- Google's consent-management services used by the User Messaging Platform.

A future commercial build may additionally communicate with the Netsource Sentinel licensing service when the user activates a commercial entitlement.

## 10. Children's privacy
Netsource Sentinel is an IT administration tool and is not designed or directed to children.

## 11. Changes
This policy may be updated when the product, advertising configuration, licensing system, legal requirements or data practices change. Material changes should be reflected by updating the effective date and the public policy page.

## 12. Contact
Privacy questions: **support@fidalix.com**

---

### Release-owner action
Before publishing, confirm the legal publisher/company name, postal contact details, the final public privacy-policy URL, the AdMob account configuration, consent message configuration and the Play Data Safety answers against the exact production binary. This engineering draft is not a substitute for legal review.
