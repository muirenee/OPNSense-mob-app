import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../audit/audit_repository.dart';
import '../profiles/firewall_profile.dart';
import 'dhcp_models.dart';
import 'dhcp_repository.dart';

class DhcpScreen extends StatefulWidget {
  const DhcpScreen({super.key, required this.profile, required this.credentials});

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<DhcpScreen> createState() => _DhcpScreenState();
}

class _DhcpScreenState extends State<DhcpScreen> {
  late final DhcpRepository _repository;
  late final AuditRepository _audit;
  late Future<KeaDhcpData> _future;

  String _leaseQuery = '';
  String _reservationQuery = '';
  String _leaseState = 'all';
  String _reservationMode = 'all';
  String _leaseInterface = 'all';
  String _reservationSubnet = 'all';

  @override
  void initState() {
    super.initState();
    _repository = DhcpRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _audit = AuditRepository(profileId: widget.profile.id);
    _future = _repository.loadAll();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.loadAll());
    await _future;
  }

  KeaReservationSummary? _reservationFor(
    DhcpLeaseSummary lease,
    List<KeaReservationSummary> reservations,
  ) {
    for (final reservation in reservations) {
      if (reservation.matchesLease(lease)) return reservation;
    }
    return null;
  }

  Future<void> _editReservation({
    required KeaDhcpData data,
    DhcpLeaseSummary? lease,
    KeaReservationSummary? reservation,
  }) async {
    var existing = reservation;
    if (existing != null && existing.uuid.isNotEmpty) {
      try {
        existing = await _repository.getReservation(
              existing.uuid,
              subnets: data.subnets,
            ) ??
            existing;
      } catch (_) {
        // Search results already contain enough information for the basic form.
      }
    }

    final initialSubnet = existing?.subnetUuid.isNotEmpty == true
        ? existing!.subnetUuid
        : lease == null
            ? (data.subnets.isEmpty ? '' : data.subnets.first.uuid)
            : (_repository.subnetForIp(lease.ip, data.subnets)?.uuid ??
                (data.subnets.isEmpty ? '' : data.subnets.first.uuid));

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ReservationEditorScreen(
          repository: _repository,
          audit: _audit,
          subnets: data.subnets,
          reservation: existing,
          initialSubnetUuid: initialSubnet,
          initialIp: existing?.ip ?? lease?.ip ?? '',
          initialMac: existing?.mac ?? lease?.mac ?? '',
          initialClientId: existing?.clientId ?? lease?.clientId ?? '',
          initialHostname: existing?.hostname ?? lease?.hostname ?? '',
        ),
      ),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _releaseLease(DhcpLeaseSummary lease) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Release KEA lease?'),
            content: Text(
              'Remove the current dynamic lease for ${lease.hostname.isEmpty ? lease.ip : lease.hostname} (${lease.ip})? The client may request a new lease immediately.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Release lease'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await _repository.releaseLease(lease.ip);
      try {
        await _audit.record(
          action: 'Release KEA DHCP lease',
          target: lease.ip,
          result: 'success',
          details: lease.mac,
        );
      } catch (_) {}
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KEA lease released.')),
        );
      }
    } catch (error) {
      try {
        await _audit.record(
          action: 'Release KEA DHCP lease',
          target: lease.ip,
          result: 'failed',
          details: error.toString(),
        );
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to release lease: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KeaDhcpData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorPane(
            title: 'KEA DHCP unavailable',
            error: snapshot.error,
            onRetry: _refresh,
          );
        }
        final data = snapshot.data!;
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: TabBar(
                  tabs: [
                    Tab(text: 'Leases (${data.leases.length})'),
                    Tab(text: 'Reservations (${data.reservations.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildLeases(data),
                    _buildReservations(data),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeases(KeaDhcpData data) {
    final interfaces = data.leases
        .map((item) => item.interfaceName)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final query = _leaseQuery.trim().toLowerCase();
    final filtered = data.leases.where((lease) {
      final reservation = _reservationFor(lease, data.reservations);
      final matchesSearch = query.isEmpty ||
          lease.ip.toLowerCase().contains(query) ||
          lease.mac.toLowerCase().contains(query) ||
          lease.hostname.toLowerCase().contains(query) ||
          lease.interfaceName.toLowerCase().contains(query) ||
          lease.clientId.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      if (_leaseInterface != 'all' && lease.interfaceName != _leaseInterface) {
        return false;
      }
      if (_leaseState == 'active' && !lease.isActive) return false;
      if (_leaseState == 'inactive' && lease.isActive) return false;
      if (_reservationMode == 'reserved' && reservation == null) return false;
      if (_reservationMode == 'dynamic' && reservation != null) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _DhcpHeader(
            title: 'KEA DHCPv4 leases',
            subtitle: '${filtered.length} of ${data.leases.length} leases shown',
            icon: Icons.devices_outlined,
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search IP, MAC, hostname or client ID',
            ),
            onChanged: (value) => setState(() => _leaseQuery = value),
          ),
          const SizedBox(height: 12),
          _FilterPanel(
            children: [
              _FilterDropdown(
                label: 'Interface',
                value: _leaseInterface,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All interfaces')),
                  ...interfaces.map(
                    (value) => DropdownMenuItem(value: value, child: Text(value)),
                  ),
                ],
                onChanged: (value) => setState(() => _leaseInterface = value!),
              ),
              _FilterDropdown(
                label: 'State',
                value: _leaseState,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All states')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'inactive', child: Text('Inactive / expired')),
                ],
                onChanged: (value) => setState(() => _leaseState = value!),
              ),
              _FilterDropdown(
                label: 'Reservation',
                value: _reservationMode,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All leases')),
                  DropdownMenuItem(value: 'reserved', child: Text('Reserved')),
                  DropdownMenuItem(value: 'dynamic', child: Text('Dynamic only')),
                ],
                onChanged: (value) => setState(() => _reservationMode = value!),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final lease in filtered) ...[
            Builder(
              builder: (context) {
                final reservation = _reservationFor(lease, data.reservations);
                return _LeaseCard(
                  lease: lease,
                  reserved: reservation != null,
                  onReserveOrEdit: () => _editReservation(
                    data: data,
                    lease: lease,
                    reservation: reservation,
                  ),
                  onRelease: () => _releaseLease(lease),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
          if (filtered.isEmpty)
            const _EmptyCard(text: 'No KEA leases match the selected filters.'),
        ],
      ),
    );
  }

  Widget _buildReservations(KeaDhcpData data) {
    final query = _reservationQuery.trim().toLowerCase();
    final filtered = data.reservations.where((reservation) {
      final matchesSearch = query.isEmpty ||
          reservation.ip.toLowerCase().contains(query) ||
          reservation.mac.toLowerCase().contains(query) ||
          reservation.hostname.toLowerCase().contains(query) ||
          reservation.description.toLowerCase().contains(query) ||
          reservation.clientId.toLowerCase().contains(query);
      if (!matchesSearch) return false;
      if (_reservationSubnet != 'all' &&
          reservation.subnetUuid != _reservationSubnet) {
        return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(
            children: [
              const Expanded(
                child: _DhcpHeader(
                  title: 'KEA reservations',
                  subtitle: 'Static DHCPv4 assignments',
                  icon: Icons.bookmark_added_outlined,
                ),
              ),
              FilledButton.icon(
                onPressed: data.subnets.isEmpty
                    ? null
                    : () => _editReservation(data: data),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search IP, MAC, hostname or description',
            ),
            onChanged: (value) => setState(() => _reservationQuery = value),
          ),
          const SizedBox(height: 12),
          _FilterPanel(
            children: [
              _FilterDropdown(
                label: 'Subnet',
                value: _reservationSubnet,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All subnets')),
                  ...data.subnets.map(
                    (subnet) => DropdownMenuItem(
                      value: subnet.uuid,
                      child: Text(subnet.label),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _reservationSubnet = value!),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final reservation in filtered) ...[
            _ReservationCard(
              reservation: reservation,
              onEdit: () => _editReservation(data: data, reservation: reservation),
              onDelete: () => _deleteReservation(reservation),
            ),
            const SizedBox(height: 10),
          ],
          if (filtered.isEmpty)
            const _EmptyCard(text: 'No KEA reservations match the selected filters.'),
        ],
      ),
    );
  }

  Future<void> _deleteReservation(KeaReservationSummary reservation) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete KEA reservation?'),
            content: Text(
              'Delete the static reservation for ${reservation.hostname.isEmpty ? reservation.ip : reservation.hostname}? KEA will be reconfigured immediately.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await _repository.deleteReservation(reservation.uuid);
      try {
        await _audit.record(
          action: 'Delete KEA DHCP reservation',
          target: reservation.ip,
          result: 'success',
          details: reservation.mac,
        );
      } catch (_) {}
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KEA reservation deleted.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete reservation: $error')),
        );
      }
    }
  }
}

class _ReservationEditorScreen extends StatefulWidget {
  const _ReservationEditorScreen({
    required this.repository,
    required this.audit,
    required this.subnets,
    required this.initialSubnetUuid,
    this.reservation,
    this.initialIp = '',
    this.initialMac = '',
    this.initialClientId = '',
    this.initialHostname = '',
  });

  final DhcpRepository repository;
  final AuditRepository audit;
  final List<KeaSubnetSummary> subnets;
  final KeaReservationSummary? reservation;
  final String initialSubnetUuid;
  final String initialIp;
  final String initialMac;
  final String initialClientId;
  final String initialHostname;

  @override
  State<_ReservationEditorScreen> createState() =>
      _ReservationEditorScreenState();
}

class _ReservationEditorScreenState extends State<_ReservationEditorScreen> {
  late String _subnetUuid;
  late final TextEditingController _ip;
  late final TextEditingController _mac;
  late final TextEditingController _clientId;
  late final TextEditingController _hostname;
  late final TextEditingController _description;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _subnetUuid = widget.initialSubnetUuid;
    _ip = TextEditingController(text: widget.reservation?.ip ?? widget.initialIp);
    _mac = TextEditingController(text: widget.reservation?.mac ?? widget.initialMac);
    _clientId = TextEditingController(
      text: widget.reservation?.clientId ?? widget.initialClientId,
    );
    _hostname = TextEditingController(
      text: widget.reservation?.hostname ?? widget.initialHostname,
    );
    _description = TextEditingController(
      text: widget.reservation?.description ?? '',
    );
  }

  @override
  void dispose() {
    _ip.dispose();
    _mac.dispose();
    _clientId.dispose();
    _hostname.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_subnetUuid.isEmpty || _ip.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subnet and IP address are required.')),
      );
      return;
    }
    if (_mac.text.trim().isEmpty && _clientId.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a MAC address or KEA client ID.'),
        ),
      );
      return;
    }

    final draft = KeaReservationDraft(
      subnetUuid: _subnetUuid,
      ip: _ip.text,
      mac: _mac.text,
      clientId: _clientId.text,
      hostname: _hostname.text,
      description: _description.text,
    );
    final editing = widget.reservation != null;

    setState(() => _busy = true);
    try {
      if (editing) {
        await widget.repository.updateReservation(widget.reservation!.uuid, draft);
      } else {
        await widget.repository.addReservation(draft);
      }
      try {
        await widget.audit.record(
          action: '${editing ? 'Edit' : 'Add'} KEA DHCP reservation',
          target: draft.ip,
          result: 'success',
          details: draft.mac,
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      try {
        await widget.audit.record(
          action: '${editing ? 'Edit' : 'Add'} KEA DHCP reservation',
          target: draft.ip,
          result: 'failed',
          details: error.toString(),
        );
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save reservation: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.reservation != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit KEA reservation' : 'Add KEA reservation'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _subnetUuid.isEmpty ? null : _subnetUuid,
            decoration: const InputDecoration(
              labelText: 'Subnet',
              prefixIcon: Icon(Icons.account_tree_outlined),
            ),
            items: widget.subnets
                .map(
                  (subnet) => DropdownMenuItem(
                    value: subnet.uuid,
                    child: Text(subnet.label),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _subnetUuid = value ?? ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ip,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Reserved IP address',
              prefixIcon: Icon(Icons.language_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mac,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'MAC address',
              hintText: '00:11:22:33:44:55',
              prefixIcon: Icon(Icons.memory_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clientId,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Client ID (optional)',
              prefixIcon: Icon(Icons.fingerprint),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hostname,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Hostname',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_busy ? 'Saving…' : 'Save & reconfigure KEA'),
          ),
        ],
      ),
    );
  }
}

class _DhcpHeader extends StatelessWidget {
  const _DhcpHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final itemWidth = width >= 720
                  ? (width - 24) / 3
                  : width >= 480
                      ? (width - 12) / 2
                      : width;
              return Wrap(
                spacing: 12,
                runSpacing: 10,
                children: children
                    .map((child) => SizedBox(width: itemWidth, child: child))
                    .toList(),
              );
            },
          ),
        ),
      );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: items,
        onChanged: onChanged,
      );
}

class _LeaseCard extends StatelessWidget {
  const _LeaseCard({
    required this.lease,
    required this.reserved,
    required this.onReserveOrEdit,
    required this.onRelease,
  });
  final DhcpLeaseSummary lease;
  final bool reserved;
  final VoidCallback onReserveOrEdit;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final statusColor = lease.isActive
        ? Colors.green
        : Theme.of(context).colorScheme.outline;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.devices_outlined),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lease.hostname.isEmpty ? lease.ip : lease.hostname,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (lease.hostname.isNotEmpty) Text(lease.ip),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'reservation') onReserveOrEdit();
                    if (value == 'release') onRelease();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'reservation',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(reserved ? Icons.edit_outlined : Icons.bookmark_add_outlined),
                        title: Text(reserved ? 'Edit reservation' : 'Create reservation'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'release',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_sweep_outlined),
                        title: Text('Release lease'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(text: lease.isActive ? 'Active' : (lease.state.isEmpty ? 'Unknown' : lease.state), color: statusColor),
                if (reserved)
                  _Pill(
                    text: 'Reserved',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                if (lease.interfaceName.isNotEmpty)
                  _Pill(text: lease.interfaceName),
              ],
            ),
            if (lease.mac.isNotEmpty) ...[
              const SizedBox(height: 10),
              _KeyValue(label: 'MAC', value: lease.mac),
            ],
            if (lease.clientId.isNotEmpty)
              _KeyValue(label: 'Client ID', value: lease.clientId),
            if (lease.ends.isNotEmpty)
              _KeyValue(label: 'Expires', value: lease.ends),
          ],
        ),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.onEdit,
    required this.onDelete,
  });
  final KeaReservationSummary reservation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          leading: const Icon(Icons.bookmark_added_outlined),
          title: Text(
            reservation.hostname.isEmpty ? reservation.ip : reservation.hostname,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            [
              if (reservation.hostname.isNotEmpty) reservation.ip,
              reservation.mac,
              reservation.subnetLabel,
              reservation.description,
            ].where((item) => item.isNotEmpty).join('\n'),
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final value = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: value.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(color: value, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 78,
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: Text(text)),
        ),
      );
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.title, required this.error, required this.onRetry});
  final String title;
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}
