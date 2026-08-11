# Netsource Sentinel

Flutter mobile client for Netsource Sentinel firewall administration.

## v0.4.0 scope

### Profiles and security
- Multiple saved Netsource Sentinel firewall profiles
- Edit/delete/switch profiles
- API Key / Secret authentication
- Credentials stored in platform secure storage
- HTTPS by default
- Optional self-signed certificate mode with warning
- API capability probe distinguishing available / forbidden / unavailable

### Monitoring and network operations
- System, memory, disk, interface and gateway monitoring
- Live interface throughput calculation
- DHCP lease discovery across Dnsmasq, Kea and DHCPv4 APIs
- ARP and NDP neighbors
- Active PF states
- Routing table

### Firewall and services
- Firewall Automation/MVC rules with guarded enable/disable
- Savepoint/apply/rollback safety flow
- Live firewall logs
- NAT port-forward and outbound NAT browsers
- Alias browser
- Core service start/stop/restart with confirmation
- Local per-profile audit trail for app-initiated writes

### VPN
- WireGuard service status and peer/session view
- OpenVPN session view
- IPsec service status and Phase 1 session/tunnel view
- Confirmed Start / Stop / Restart service controls
- VPN write actions recorded in the local audit trail

### Diagnostics
- Ping jobs
- Traceroute
- Reverse DNS lookup
- Routing table browser
- Packet-capture jobs
- Stop capture and download PCAP to app temporary storage

## Important safety and compatibility notes

- API access depends on the Effective Privileges assigned to the firewall API user.
- Firewall Automation API rules are not the same as all legacy/core GUI rules; rules outside Firewall Automation may not be returned.
- VPN, DHCP and diagnostic endpoint availability varies by firewall release, enabled component/plugin and ACL. The app probes capabilities and reports forbidden separately from unavailable.
- Service stop/restart and VPN service actions can interrupt sessions and require explicit confirmation.
- Firewall state deletion/flush remains read-only in v0.4.
- NAT/alias editing remains read-only in v0.4.
- Self-signed certificate bypass is optional and deliberately warned; normal TLS validation is the default.

## Repository layout

The repository is normalized as a standard Flutter application. Android and iOS platform wrappers are committed alongside the application source:

- `lib/` — application source
- `test/` — project tests
- `android/` — Android platform project
- `ios/` — iOS platform project
- `docs/` — architecture and roadmap documentation
- `.github/workflows/build-apk.yml` — Android CI build

## Android build

On a machine with Flutter installed:

```bash
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build apk --release
```

The APK is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

The GitHub Actions workflow performs the same sequence, verifies the generated APK and uploads it as a workflow artifact.

## Netsource Sentinel setup

Create a dedicated local firewall API user and grant only the Effective Privileges needed by the modules you intend to use. Generate an API key and secret for that user and enter them in Netsource Sentinel. Avoid using a full administrator account unless it is required.
