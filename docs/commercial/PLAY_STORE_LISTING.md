# Netsource Sentinel — Google Play Listing Draft

## App name
Netsource Sentinel

## Short description
Manage one compatible OPNsense firewall from Android with powerful mobile tools.

## Full description
Netsource Sentinel is an independent mobile management client for compatible OPNsense firewalls. The Free edition lets administrators connect one firewall and use the supported management feature set from a modern Android interface.

### Monitor at a glance
- System health, memory and storage
- Interfaces and addresses
- Services and status
- Firewall logs and states
- VPN status

### Manage from mobile
- Firewall rules, aliases and supported NAT operations
- KEA DHCP leases and reservations
- Users, groups and access rights
- Captive Portal zones, sessions and vouchers
- Service start, stop and restart actions
- Firmware/update checks

### Diagnose problems
- Ping and traceroute
- DNS lookup
- Routes and neighbors
- Packet capture on supported firewall versions

### Safer administration
- Firewall API credentials remain on the device in secure platform storage
- Optional support for trusted self-signed certificates
- Audit trail for management actions performed from the app
- Capability checks to identify unsupported endpoints or missing permissions
- Demo Mode uses local sample data, so the app can be explored without connecting to a firewall

### Free edition
Netsource Sentinel Free supports **one saved firewall** and includes the supported management features for that firewall. The Free edition is supported by advertising on selected top-level overview screens. Ads are not shown in Demo Mode or while entering firewall credentials and using add/edit/action screens.

A future Sentinel Pro edition may add multiple-firewall management and an ad-free experience. No Pro purchase flow is enabled in this Free release.

Netsource Sentinel connects directly to the firewall address configured by the administrator. Firewall API credentials are not sent to Google, advertisers or the Netsource Sentinel licensing service.

Netsource Sentinel is independently developed. OPNsense is a trademark of Deciso B.V. This application is not affiliated with, endorsed by or produced by Deciso B.V.

## Suggested category
Tools

## Suggested tags
Firewall, network administration, network monitoring, VPN, security, IT administration

## Contact
Support: support@fidalix.com

## Release notes — 1.1.0
- Free edition with one-firewall limit
- Ad-supported top-level overview experience
- Google User Messaging Platform consent integration
- Ad privacy choices when required
- Ads excluded from Demo Mode and sensitive/action screens
- Existing Demo Mode, API 36 support, firewall/NAT/network/VPN management and diagnostics retained
- Future Pro/MSP entitlement architecture retained without enabling a purchase flow

## Reviewer notes
No account is required to review the main application experience. On the first screen choose **Explore Demo Mode**. Demo Mode uses only local sample data, does not contact or modify a firewall, and does not display ads.

The production Free build uses Google Mobile Ads on selected top-level screens when consent/eligibility allows ads to be requested. To test a real firewall connection, a reviewer would need a reachable compatible OPNsense installation and an API key/secret with appropriate privileges. Do not provide production firewall credentials in Play Console.
