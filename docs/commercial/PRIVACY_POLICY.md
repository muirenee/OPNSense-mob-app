# Netsource Sentinel Privacy Policy

**Effective date: 12 August 2026**

This document is the website/store master copy corresponding to the policy included in Netsource Sentinel 1.0. It must be reviewed and published on a public HTTPS URL before production submission to Google Play.

## 1. Scope
Netsource Sentinel is a mobile management client for firewalls that expose compatible OPNsense APIs.

## 2. Firewall connection data
The app stores firewall profiles locally on the device. API keys and API secrets are stored using platform secure storage. Firewall API credentials are sent only to the firewall address configured by the user and are not sent to the Netsource Sentinel licensing service.

## 3. Licensing data
Commercial builds may send the following to the Netsource Sentinel licensing service:
- activation code;
- randomly generated installation identifier;
- application package identifier;
- application version and build number;
- opaque license lease token during refresh/deactivation.

The licensing service does not require or receive firewall API keys or firewall API secrets.

## 4. Demo Mode
Demo Mode uses sample data generated locally by the application and does not contact a firewall.

## 5. Advertising
The current application does not include advertising SDKs. Netsource Sentinel does not sell firewall credentials or licensing data to advertisers.

## 6. Security
Sensitive local values are stored using secure-storage facilities supplied by the operating system. Connections to real firewalls use HTTPS when configured by the user. A self-signed-certificate option is available for trusted firewalls controlled by the user; a publicly trusted CA certificate remains recommended where practical.

## 7. Retention and deletion
Deleting a firewall profile removes the API credentials stored for that profile from application secure storage. Deactivating a license removes the locally cached commercial entitlement.

Uninstalling the application removes application-local data subject to the operating system's backup and restore behavior.

Licensing records retained by the licensing service should be kept only as necessary for subscription administration, fraud prevention, support, accounting and legal obligations. The production backend retention schedule must be documented before launch.

## 8. Third-party services
The mobile application communicates with:
- the firewall endpoint configured by the user;
- the Netsource Sentinel licensing service when commercial licensing is configured and used.

If analytics, crash reporting, Play Billing, authentication, or other third-party SDKs are added later, this policy and the Google Play Data Safety declaration must be updated before release.

## 9. Children's privacy
Netsource Sentinel is an IT administration tool and is not designed or directed to children.

## 10. Changes
This policy may be updated when the product, licensing system, legal requirements or data practices change. Material changes should be reflected by updating the effective date and the public policy page.

## 11. Contact
Privacy questions or licensing-data deletion requests: **support@fidalix.com**

---

### Release-owner action
Before publishing, confirm the legal publisher/company name, postal contact details, retention periods, the final public privacy-policy URL and all actual production SDK/backend behavior. This engineering draft is not a substitute for legal review.
