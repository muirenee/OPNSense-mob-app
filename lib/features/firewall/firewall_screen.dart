import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
import '../audit/audit_repository.dart';
import '../profiles/firewall_profile.dart';
import 'firewall_models.dart';
import 'firewall_repository.dart';
import 'firewall_rule_editor.dart';

class FirewallScreen extends StatefulWidget {
  const FirewallScreen({super.key, required this.profile, required this.credentials});

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<FirewallScreen> createState() => _FirewallScreenState();
}

class _FirewallScreenState extends State<FirewallScreen> {
  late final FirewallRepository _repository;
  late final AuditRepository _audit;
  late Future<List<FirewallRuleSummary>> _future;
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _busyUuid;

  @override
  void initState() {
    super.initState();
    _repository = FirewallRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _audit = AuditRepository(profileId: widget.profile.id);
    _future = _repository.loadRules();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.loadRules(search: _searchController.text));
    await _future;
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _future = _repository.loadRules(search: value));
    });
  }

  Future<void> _edit([FirewallRuleSummary? rule]) async {
    Map<String, dynamic> initial = <String, dynamic>{};
    if (rule != null && rule.uuid.isNotEmpty) {
      try {
        initial = await _repository.getRule(rule.uuid);
      } catch (_) {}
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FirewallRuleEditor(
          repository: _repository,
          audit: _audit,
          rule: rule,
          initial: initial,
        ),
      ),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _toggle(FirewallRuleSummary rule) async {
    final nextEnabled = !rule.enabled;
    final verb = nextEnabled ? 'Enable' : 'Disable';
    final confirmed = await _confirm(
      '$verb firewall rule?',
      '$verb "${rule.description.isEmpty ? rule.uuid : rule.description}"?\n\nSentinel will apply the change using rollback protection.',
      verb,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyUuid = rule.uuid);
    try {
      final revision = await _repository.toggleRuleSafely(rule: rule, enabled: nextEnabled);
      await _record('$verb firewall rule', rule.description.isEmpty ? rule.uuid : rule.description, 'success', 'rollback revision $revision');
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rule ${nextEnabled ? 'enabled' : 'disabled'} successfully.')));
    } catch (error) {
      await _record('$verb firewall rule', rule.description.isEmpty ? rule.uuid : rule.description, 'failed', error.toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rule change failed: $error')));
    } finally {
      if (mounted) setState(() => _busyUuid = null);
    }
  }

  Future<void> _delete(FirewallRuleSummary rule) async {
    final confirmed = await _confirm(
      'Delete firewall rule?',
      'Delete "${rule.description.isEmpty ? rule.uuid : rule.description}"? Sentinel will apply the deletion with rollback protection.',
      'Delete',
    );
    if (!confirmed) return;
    setState(() => _busyUuid = rule.uuid);
    try {
      final revision = await _repository.deleteRuleSafely(rule);
      await _record('Delete firewall rule', rule.description.isEmpty ? rule.uuid : rule.description, 'success', 'rollback revision $revision');
      await _refresh();
    } catch (error) {
      await _record('Delete firewall rule', rule.description.isEmpty ? rule.uuid : rule.description, 'failed', error.toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rule delete failed: $error')));
    } finally {
      if (mounted) setState(() => _busyUuid = null);
    }
  }

  Future<bool> _confirm(String title, String text, String action) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(text),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _record(String action, String target, String result, String details) async {
    try {
      await _audit.record(action: action, target: target, result: result, details: details);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FirewallRuleSummary>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return _FirewallError(error: snapshot.error, onRetry: _refresh);
        final rules = snapshot.data ?? const <FirewallRuleSummary>[];

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Firewall rules', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        Text('${rules.length} Automation rule${rules.length == 1 ? '' : 's'}'),
                      ],
                    ),
                  ),
                  FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add')),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Search rules',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              const _NoticeCard(
                text: 'Only Firewall Automation/MVC rules exposed by the firewall API appear here. Add/Edit/Delete/Enable actions use rollback protection and local audit logging.',
              ),
              const SizedBox(height: 12),
              if (rules.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('No matching Firewall Automation rules returned.')))
              else
                for (final rule in rules) ...[
                  _RuleCard(
                    rule: rule,
                    busy: _busyUuid == rule.uuid,
                    onTap: () => _edit(rule),
                    onToggle: rule.uuid.isEmpty || _busyUuid != null ? null : () => _toggle(rule),
                    onDelete: rule.uuid.isEmpty || _busyUuid != null ? null : () => _delete(rule),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.busy,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final FirewallRuleSummary rule;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final action = rule.action.toLowerCase();
    final actionIcon = action.contains('pass') || action.contains('allow')
        ? Icons.check_circle_outline
        : action.contains('reject')
            ? Icons.block
            : Icons.shield_outlined;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(actionIcon, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(rule.description.isEmpty ? 'Unnamed rule' : rule.description, style: const TextStyle(fontWeight: FontWeight.w800))),
              if (busy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                Switch.adaptive(value: rule.enabled, onChanged: onToggle == null ? null : (_) => onToggle!()),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onTap();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ChipText(rule.action.isEmpty ? 'Action unknown' : rule.action),
              if (rule.interfaceName.isNotEmpty) _ChipText(rule.interfaceName),
              if (rule.direction.isNotEmpty) _ChipText(rule.direction),
              if (rule.protocol.isNotEmpty) _ChipText(rule.protocol),
              if (rule.logging) const _ChipText('Logging'),
            ]),
            const SizedBox(height: 12),
            _EndpointRow(label: 'Source', value: _endpoint(rule.source, rule.sourcePort)),
            const SizedBox(height: 6),
            _EndpointRow(label: 'Destination', value: _endpoint(rule.destination, rule.destinationPort)),
          ]),
        ),
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 92, child: Text(label)),
        Expanded(child: Text(value.isEmpty ? 'any' : value, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]);
}

class _ChipText extends StatelessWidget {
  const _ChipText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      ));
}

class _FirewallError extends StatelessWidget {
  const _FirewallError({required this.error, required this.onRetry});
  final Object? error;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.security_outlined, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text('Firewall rules unavailable', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: () => onRetry(), icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ]),
      ));
}

String _endpoint(String address, String port) {
  final a = address.isEmpty ? 'any' : address;
  return port.isEmpty ? a : '$a:$port';
}
