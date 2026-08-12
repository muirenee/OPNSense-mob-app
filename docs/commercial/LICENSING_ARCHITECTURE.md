# Netsource Sentinel — Licensing Architecture v1

## Goals
The licensing system must control commercial entitlements without ever requiring firewall API credentials on the licensing server. It must tolerate temporary loss of Internet access and must support device replacement, cancellation and plan upgrades.

## Plans
Initial commercial packaging (server-configurable; not hardcoded into the mobile binary):

| Plan | Suggested annual price | Firewall limit | Intended use |
|---|---:|---:|---|
| Free | $0 | 1 | Evaluation / light personal use |
| Personal | $9.99 | 1 | Individual administrator |
| Professional | $29 | 5 | Consultants / small IT teams |
| MSP | $99 | 25 | Managed-service providers |

The server is authoritative for plan names, limits, expiry and feature flags. Pricing can change without rebuilding the app.

## Client identity
On first launch Sentinel generates a cryptographically random **installation_id**. It is stored in Android/iOS secure storage and is not derived from IMEI, MAC address, Android ID or any other hardware identifier.

The client never sends these values to the licensing API:
- Firewall API key
- Firewall API secret
- Firewall configuration
- Captive Portal user credentials
- Packet captures

## Activation flow
1. Customer receives an activation code after a completed sale or approved trial.
2. App sends `activation_code`, `installation_id`, package ID, app version and build number to `POST /v1/licenses/activate`.
3. Backend verifies the activation code, subscription state and device/install limits.
4. Backend records/updates the activation and returns an entitlement object with an **opaque lease token**.
5. App stores the entitlement and lease token in secure storage.
6. The firewall-count limit is enforced in the UI, but the backend remains authoritative for the paid entitlement.

Example successful response:

```json
{
  "entitlement": {
    "plan": "professional",
    "status": "active",
    "max_firewalls": 5,
    "features": [
      "diagnostics",
      "multi-firewall",
      "users-groups",
      "captive-portal"
    ],
    "license_id": "lic_01J...",
    "expires_at": "2027-08-12T00:00:00Z",
    "offline_until": "2026-08-19T00:00:00Z",
    "lease_token": "opaque-high-entropy-token"
  }
}
```

## Refresh flow
`POST /v1/licenses/refresh`

Request:
```json
{
  "lease_token": "opaque-high-entropy-token",
  "installation_id": "random-installation-id",
  "package_id": "com.netsource.sentinel",
  "app_version": "1.0.0",
  "build_number": 100
}
```

The service returns a new entitlement/lease, extending `offline_until` when the subscription remains valid.

Recommended production behavior:
- Refresh on app start when the last successful validation is older than 24 hours and connectivity exists.
- Refresh after purchase/upgrade.
- Refresh before the offline lease expires.
- Suggested offline grace: 7 days for active paid plans.
- A failed refresh does not immediately disable an otherwise valid cached entitlement; it remains usable until `offline_until`.

## Deactivation flow
`POST /v1/licenses/deactivate`

The service invalidates the activation/lease. The client removes the local paid entitlement and falls back to Free. Local deactivation remains possible if the service is unreachable; server-side leases should also expire automatically.

## Suggested backend entities

### customers
- id
- email
- display_name / organization
- status
- created_at / updated_at

### licenses
- id
- customer_id
- plan
- status (`active`, `suspended`, `cancelled`, `expired`)
- max_installations
- max_firewalls
- starts_at
- expires_at
- external_order_id / invoice reference
- created_at / updated_at

### activation_codes
- id
- license_id
- code_hash (never store the clear activation code after issue)
- expires_at
- max_uses
- use_count
- revoked_at

### installations
- id
- license_id
- installation_id_hash
- package_id
- first_seen_at
- last_seen_at
- app_version
- build_number
- revoked_at

### license_leases
- id
- installation_id
- token_hash (store only a hash of the opaque token)
- issued_at
- expires_at
- offline_until
- revoked_at

### audit_events
- id
- license_id / installation_id where applicable
- event type (activate, refresh, deactivate, revoke, upgrade, failed_activation)
- IP / user-agent only if required for fraud/security and disclosed in privacy policy
- created_at

## Token design
Use at least 256 bits of cryptographically secure random entropy for opaque lease tokens. Store only a one-way hash of the lease token on the server. Use TLS for all licensing API traffic.

Do not embed server master secrets, private signing keys, valid activation codes or administrative API keys in the Flutter app.

## Server-side checks
Activation/refresh should verify:
- License status and expiry
- Activation code validity
- Installation limit
- Package ID allow-list (`com.netsource.sentinel`)
- Minimum supported app version when required
- Revocation state
- Rate limits / brute-force protection

Return generic errors for invalid activation codes to reduce account enumeration.

## Plan enforcement
The client currently implements a firewall-profile count guard. Future feature-level gates should use named feature flags returned by the entitlement rather than checking plan names throughout the UI.

Example:
```dart
if (license.entitlement.hasFeature('captive-portal')) {
  // expose module
}
```

## Purchases
The entitlement API is deliberately independent of payment provider. A future Google Play Billing integration can verify purchases on the backend and update the same `licenses` records. Website/invoice/reseller purchases can do the same.

For Google Play-distributed builds, review current Google Play Payments policy before placing any external purchase flow inside the app.

## Security hardening roadmap
After the basic backend is deployed:
1. Add Play Integrity verification to activation/refresh requests where appropriate.
2. Pin or otherwise strengthen TLS only after an operational certificate-rotation plan exists.
3. Add server-side anomaly detection for excessive activations.
4. Add a customer portal for self-service deactivation/device replacement.
5. Add webhook processing from the chosen billing platform.
6. Add signed server configuration for minimum supported app version and maintenance notices.

## Failure behavior
- Licensing backend unavailable, cached lease valid: continue operating and show a non-blocking status.
- Offline grace expired: fall back to Free entitlement; do not erase firewall credentials or profiles.
- License revoked: paid feature/limit entitlement is removed after successful validation; user data remains local.
- License server compromise: rotate backend credentials/tokens; because firewall API secrets are never sent to licensing, the firewall credentials are not exposed by that system.
