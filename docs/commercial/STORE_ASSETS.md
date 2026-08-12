# Netsource Sentinel — Google Play Store Asset Specification

## Required identity
- Product name: **Netsource Sentinel**
- Package ID: **com.netsource.sentinel**
- Visual direction: modern professional network/security administration product; consistent with the existing Sentinel blue/neutral UI.
- Do not use the OPNsense logo as the Sentinel app icon.
- Do not imply official endorsement by OPNsense/Deciso.

## High-resolution Play icon
- 512 x 512 px
- PNG, 32-bit
- Keep important artwork away from the outer edge because Google Play applies its own masking.
- Recommended content: the existing unique Netsource Sentinel shield/network motif, simplified for small-size readability.
- No tiny text.

The current Flutter launcher icon should be reviewed/replaced before public submission; the Play icon should be treated as a deliberate brand asset, not merely an enlarged low-resolution development icon.

## Feature graphic
- 1024 x 500 px
- Recommended composition:
  - Left: Sentinel shield/brand mark + “Netsource Sentinel”
  - Short value line: “Mobile firewall management. Wherever you work.”
  - Right: clean phone mockup showing the Sentinel dashboard
- Avoid screenshots containing live credentials, public customer IPs or customer names.

## Phone screenshots
Use real application captures and show a sequence that explains the product rather than several nearly identical screens.

Suggested order:
1. **Dashboard** — system health, interfaces and quick actions
2. **Firewall management** — rules/aliases/NAT overview or rule editor
3. **KEA DHCP** — leases/reservations with filters
4. **Users & Groups** — modern group/privilege management
5. **Captive Portal** — zones/session management
6. **Diagnostics** — ping/traceroute/packet capture
7. **Demo Mode** — first-run demo option, useful for reviewer clarity

Existing QA screenshots from the 0.6.x milestone can be retained as internal reference, but public store screenshots should be captured again from the final v1.0 build after the package/version and legal/licensing UI are complete.

## Screenshot copy overlays (optional)
If marketing overlays are used, keep them brief:
- “Your firewall at a glance”
- “Manage rules securely”
- “KEA leases and reservations”
- “Users, groups and access rights”
- “Captive Portal from mobile”
- “Diagnostics when you need them”

Do not claim capabilities that are unavailable on some OPNsense versions without qualifying the claim in the listing.

## Promotional wording
Primary: **Professional mobile management for compatible OPNsense firewalls.**

Alternatives:
- **Monitor. Manage. Diagnose.**
- **Firewall administration without the desktop.**
- **A modern mobile console for network administrators.**

## Store listing tone
- Professional, technical and precise.
- Avoid fear-based security marketing.
- Avoid “official OPNsense app” or wording that could imply endorsement.
- Emphasize that credentials remain on-device and the app connects directly to the administrator-configured firewall.

## Release asset folder convention
Suggested local/export structure:

```text
play-store-assets/
  icon/
    sentinel-play-icon-512.png
  feature-graphic/
    sentinel-feature-graphic-1024x500.png
  screenshots/
    01-dashboard.png
    02-firewall.png
    03-kea-dhcp.png
    04-users-groups.png
    05-captive-portal.png
    06-diagnostics.png
  text/
    listing-en-US.txt
    release-notes-1.0.0.txt
```

## Final visual QA
Before upload:
- Confirm all screenshots are from build 1.0.0+100 or newer.
- Remove/blur any production IPs, customer names, usernames, email addresses or firewall API material.
- Confirm status bar notifications do not expose unrelated private information.
- Verify screenshots remain legible on the Play listing at reduced size.
- Verify app icon does not resemble or copy a third-party trademark/logo.
