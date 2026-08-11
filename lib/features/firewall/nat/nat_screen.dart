import 'package:flutter/material.dart';

import '../../../core/api/opnsense_api_client.dart';
import '../../audit/audit_repository.dart';
import '../../profiles/firewall_profile.dart';
import 'nat_models.dart';
import 'nat_repository.dart';
import 'nat_rule_editor.dart';

class NatScreen extends StatefulWidget {
  const NatScreen({super.key, required this.profile, required this.credentials});
  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<NatScreen> createState() => _NatScreenState();
}

class _NatScreenState extends State<NatScreen> {
  late final NatRepository _repository;
  late final AuditRepository _audit;
  late Future<List<NatRuleSummary>> _portForwards;
  late Future<List<NatRuleSummary>> _outbound;
  String? _busyUuid;

  @override
  void initState() {
    super.initState();
    _repository = NatRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _audit = AuditRepository(profileId: widget.profile.id);
    _reload();
  }

  void _reload() {
    _portForwards = _repository.loadPortForwards();
    _outbound = _repository.loadOutbound();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait<dynamic>([_portForwards, _outbound]);
  }

  Future<void> _editPortForward([NatRuleSummary? rule]) async {
    Map<String, dynamic> initial = <String, dynamic>{};
    if (rule != null) {
      try {
        initial = await _repository.getRule(rule);
      } catch (_) {}
    }
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NatRuleEditor(
          repository: _repository,
          audit: _audit,
          rule: rule,
          initial: initial,
        ),
      ),
    );
    if (changed == true) await _refresh();
  }

  Future<void> _toggle(NatRuleSummary rule) async {
    final enable = !rule.enabled;
    final verb = enable ? 'Enable' : 'Disable';
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$verb NAT rule?'),
            content: Text(
              '$verb "${rule.description.isEmpty ? rule.uuid : rule.description}"?\n\n'
              'Sentinel will create a rollback savepoint, apply the change, verify API reachability, and only then confirm it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(verb),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() => _busyUuid = rule.uuid);
    try {
      final revision = await _repository.setEnabledSafely(rule, enable);
      try {
        await _audit.record(
          action: '$verb NAT rule',
          target: rule.description.isEmpty ? rule.uuid : rule.description,
          result: 'success',
          details: 'rollback revision $revision',
        );
      } catch (_) {}
      await _refresh();
    } catch (error) {
      try {
        await _audit.record(
          action: '$verb NAT rule',
          target: rule.description.isEmpty ? rule.uuid : rule.description,
          result: 'failed',
          details: error.toString(),
        );
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NAT change failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyUuid = null);
    }
  }

  Future<void> _delete(NatRuleSummary rule) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete NAT rule?'),
            content: Text(
              'Delete "${rule.description.isEmpty ? rule.uuid : rule.description}"?\n\n'
              'Published services or outbound connectivity may be affected. Sentinel will use rollback protection while applying the deletion.',
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
    if (!ok) return;

    setState(() => _busyUuid = rule.uuid);
    try {
      final revision = await _repository.deleteSafely(rule);
      try {
        await _audit.record(
          action: 'Delete NAT rule',
          target: rule.description.isEmpty ? rule.uuid : rule.description,
          result: 'success',
          details: 'rollback revision $revision',
        );
      } catch (_) {}
      await _refresh();
    } catch (error) {
      try {
        await _audit.record(
          action: 'Delete NAT rule',
          target: rule.description.isEmpty ? rule.uuid : rule.description,
          result: 'failed',
          details: error.toString(),
        );
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('NAT delete failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyUuid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Material(
            child: TabBar(
              tabs: [
                Tab(text: 'Port Forward', icon: Icon(Icons.call_made_outlined)),
                Tab(text: 'Outbound', icon: Icon(Icons.call_received_outlined)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _NatList(
                  future: _portForwards,
                  onRefresh: _refresh,
                  onAdd: () => _editPortForward(),
                  onEdit: _editPortForward,
                  onToggle: _toggle,
                  onDelete: _delete,
                  busyUuid: _busyUuid,
                  title: 'Port forwards',
                  emptyText: 'No port-forward rules returned.',
                ),
                _NatList(
                  future: _outbound,
                  onRefresh: _refresh,
                  onToggle: _toggle,
                  onDelete: _delete,
                  busyUuid: _busyUuid,
                  title: 'Outbound NAT',
                  emptyText: 'No outbound NAT rules returned.',
                  notice:
                      'Outbound NAT creation remains hidden until the Source NAT model is verified for this firewall release. Existing rules can still be enabled, disabled or deleted.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NatList extends StatelessWidget {
  const _NatList({
    required this.future,
    required this.onRefresh,
    required this.onToggle,
    required this.onDelete,
    required this.busyUuid,
    required this.title,
    required this.emptyText,
    this.onAdd,
    this.onEdit,
    this.notice,
  });

  final Future<List<NatRuleSummary>> future;
  final Future<void> Function() onRefresh;
  final Future<void> Function(NatRuleSummary) onToggle;
  final Future<void> Function(NatRuleSummary) onDelete;
  final Future<void> Function(NatRuleSummary)? onEdit;
  final VoidCallback? onAdd;
  final String? busyUuid;
  final String title;
  final String emptyText;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NatRuleSummary>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'NAT view unavailable\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final rules = snapshot.data ?? const <NatRuleSummary>[];
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text('${rules.length} rules'),
                      ],
                    ),
                  ),
                  if (onAdd != null)
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                ],
              ),
              if (notice != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(notice!)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              for (final rule in rules) ...[
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onEdit == null ? null : () => onEdit!(rule),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: rule.enabled
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  rule.description.isEmpty
                                      ? 'Unnamed NAT rule'
                                      : rule.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (busyUuid == rule.uuid)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') onEdit?.call(rule);
                                    if (value == 'toggle') onToggle(rule);
                                    if (value == 'delete') onDelete(rule);
                                  },
                                  itemBuilder: (_) => [
                                    if (onEdit != null)
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        rule.enabled ? 'Disable' : 'Enable',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (rule.interfaceName.isNotEmpty)
                                Chip(label: Text(rule.interfaceName)),
                              if (rule.protocol.isNotEmpty)
                                Chip(label: Text(rule.protocol)),
                              Chip(
                                label: Text(
                                  rule.enabled ? 'Enabled' : 'Disabled',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _EndpointRow(
                            label: 'Source',
                            value: _endpoint(rule.source, rule.sourcePort),
                          ),
                          _EndpointRow(
                            label: 'Destination',
                            value: _endpoint(
                              rule.destination,
                              rule.destinationPort,
                            ),
                          ),
                          if (rule.target.isNotEmpty ||
                              rule.targetPort.isNotEmpty)
                            _EndpointRow(
                              label: 'Translation',
                              value: _endpoint(
                                rule.target,
                                rule.targetPort,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (rules.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(emptyText),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

String _endpoint(String address, String port) {
  final a = address.isEmpty ? 'any' : address;
  return port.isEmpty ? a : '$a:$port';
}
