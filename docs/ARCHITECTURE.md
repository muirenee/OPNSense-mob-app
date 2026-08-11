# Architecture

## Principles

1. Direct client-to-firewall HTTPS. No mandatory cloud relay.
2. Secrets stored only in platform secure storage.
3. Least-privilege OPNsense API users.
4. Capability probing because endpoint availability differs by OPNsense release, enabled services/plugins and ACLs.
5. Read-only by default; write actions require explicit confirmation.
6. API transport isolated from feature repositories so endpoints can evolve without rewriting the UI.
7. Polling is used only where it adds operational value.
8. Potentially connectivity-impacting firewall changes use OPNsense rollback protection.
9. App-initiated write actions are recorded locally without credentials or secrets.

## v0.4 modules

- Profiles & Security
- Dashboard
- Interfaces & Gateways
- DHCP Leases
- ARP / NDP Neighbors
- Firewall Automation Rules
- NAT Port Forward / Outbound NAT
- Firewall Aliases
- Active Firewall States
- Live Firewall Logs
- Services
- App Audit Trail
- API Capability Matrix
- WireGuard / OpenVPN / IPsec
- Ping / Traceroute / Reverse DNS
- Routing Table
- Packet Capture / PCAP Download

## API capability model

Each important endpoint is classified as:

- `available`: endpoint responded successfully
- `forbidden`: endpoint exists but the current API user received HTTP 403
- `unavailable`: endpoint returned HTTP 404 for this release/configuration
- `error`: other network/API failure

This avoids treating insufficient privileges as an incompatible firewall.

## Live interface throughput

The app polls `diagnostics/interface/get_interface_statistics` every two seconds and derives RX/TX bit rates from byte-counter deltas. This avoids coupling the UI to streaming-response framing while still providing live throughput.

## DHCP provider detection

Lease discovery is capability-tolerant. The repository probes Dnsmasq, Kea and DHCPv4 lease APIs. A 403/404 on one DHCP provider does not prevent trying another provider because installations and API privileges differ.

## Firewall change safety

A Firewall Automation rule toggle uses a guarded transaction:

1. `savepoint`
2. `toggleRule`
3. `apply/<revision>`
4. verify `searchRule` remains reachable with the same API privilege
5. `cancelRollback/<revision>`

If reachability verification fails after apply, rollback cancellation is intentionally skipped so OPNsense can revert the firewall component when its rollback timer is available.

## Write-action policy

- read: no confirmation
- service start: confirmation
- service stop/restart: confirmation + interruption warning
- firewall rule toggle: confirmation + rollback-safe transaction
- NAT/alias edits: deferred until the same transaction safety is implemented for those controllers
- firewall state kill/flush: deferred because the effect on active sessions is immediate
- reboot/shutdown: future strong confirmation

## Audit model

The app stores up to 200 recent write-action records per firewall profile in local preferences. The audit entry contains timestamp, action, target, result and non-secret details. API keys and secrets are never recorded.

## VPN and diagnostics policy

VPN status and session discovery are read-only. VPN service Start/Stop/Restart requires explicit confirmation and is written to the local audit trail. Diagnostics jobs are isolated from configuration writes; ping, traceroute and packet capture use their dedicated diagnostics controllers. PCAP data is downloaded as bytes and written to app temporary storage.
