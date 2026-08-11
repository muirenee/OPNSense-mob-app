import 'package:flutter/material.dart';

import '../audit/audit_repository.dart';
import 'firewall_models.dart';
import 'firewall_repository.dart';

class FirewallRuleEditor extends StatefulWidget {
  const FirewallRuleEditor({
    super.key,
    required this.repository,
    required this.audit,
    this.rule,
    this.initial = const <String, dynamic>{},
  });

  final FirewallRepository repository;
  final AuditRepository audit;
  final FirewallRuleSummary? rule;
  final Map<String, dynamic> initial;

  @override
  State<FirewallRuleEditor> createState() => _FirewallRuleEditorState();
}

class _FirewallRuleEditorState extends State<FirewallRuleEditor> {
  late final TextEditingController _description;
  late final TextEditingController _interfaceName;
  late final TextEditingController _protocol;
  late final TextEditingController _source;
  late final TextEditingController _sourcePort;
  late final TextEditingController _destination;
  late final TextEditingController _destinationPort;
  String _action = 'pass';
  String _direction = 'in';
  bool _enabled = true;
  bool _logging = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    String value(List<String> keys, String fallback) {
      for (final key in keys) {
        final raw = widget.initial[key];
        if (raw != null && raw.toString().trim().isNotEmpty) {
          return raw.toString().trim();
        }
      }
      return fallback;
    }

    _description = TextEditingController(
      text: value(const ['description', 'descr'], widget.rule?.description ?? ''),
    );
    _interfaceName = TextEditingController(
      text: value(const ['interface', 'interfaces'], widget.rule?.interfaceName ?? ''),
    );
    _protocol = TextEditingController(
      text: value(const ['protocol'], widget.rule?.protocol ?? 'TCP'),
    );
    _source = TextEditingController(
      text: value(const ['source_net', 'source'], widget.rule?.source ?? ''),
    );
    _sourcePort = TextEditingController(
      text: value(const ['source_port'], widget.rule?.sourcePort ?? ''),
    );
    _destination = TextEditingController(
      text: value(
        const ['destination_net', 'destination'],
        widget.rule?.destination ?? '',
      ),
    );
    _destinationPort = TextEditingController(
      text: value(
        const ['destination_port'],
        widget.rule?.destinationPort ?? '',
      ),
    );
    _action = value(
      const ['action'],
      widget.rule?.action.toLowerCase() ?? 'pass',
    ).toLowerCase();
    if (!const {'pass', 'block', 'reject'}.contains(_action)) _action = 'pass';
    _direction = value(
      const ['direction'],
      widget.rule?.direction.toLowerCase() ?? 'in',
    ).toLowerCase();
    if (!const {'in', 'out'}.contains(_direction)) _direction = 'in';
    _enabled = widget.rule?.enabled ?? _truthy(widget.initial['enabled'], true);
    _logging = widget.rule?.logging ?? _truthy(widget.initial['log'], false);
  }

  bool _truthy(dynamic value, bool fallback) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return const {'1', 'true', 'yes', 'on'}
        .contains(value.toString().toLowerCase());
  }

  @override
  void dispose() {
    _description.dispose();
    _interfaceName.dispose();
    _protocol.dispose();
    _source.dispose();
    _sourcePort.dispose();
    _destination.dispose();
    _destinationPort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final values = <String, dynamic>{
      'description': _description.text.trim(),
      'action': _action,
      'direction': _direction,
      'protocol': _protocol.text.trim(),
      'interface': _interfaceName.text.trim(),
      'source_net': _source.text.trim(),
      'source_port': _sourcePort.text.trim(),
      'destination_net': _destination.text.trim(),
      'destination_port': _destinationPort.text.trim(),
      'enabled': _enabled ? '1' : '0',
      'log': _logging ? '1' : '0',
    };
    try {
      final revision = await widget.repository.saveRuleSafely(
        uuid: widget.rule?.uuid,
        values: values,
      );
      try {
        await widget.audit.record(
          action: widget.rule == null ? 'Add firewall rule' : 'Edit firewall rule',
          target: _description.text.trim().isEmpty
              ? (widget.rule?.uuid ?? 'new rule')
              : _description.text.trim(),
          result: 'success',
          details: 'rollback revision $revision',
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save firewall rule: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.rule != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit firewall rule' : 'Add firewall rule'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _action,
            decoration: const InputDecoration(labelText: 'Action'),
            items: const [
              DropdownMenuItem(value: 'pass', child: Text('Pass')),
              DropdownMenuItem(value: 'block', child: Text('Block')),
              DropdownMenuItem(value: 'reject', child: Text('Reject')),
            ],
            onChanged: (value) => setState(() => _action = value ?? 'pass'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _direction,
                  decoration: const InputDecoration(labelText: 'Direction'),
                  items: const [
                    DropdownMenuItem(value: 'in', child: Text('In')),
                    DropdownMenuItem(value: 'out', child: Text('Out')),
                  ],
                  onChanged: (value) =>
                      setState(() => _direction = value ?? 'in'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _protocol,
                  decoration: const InputDecoration(
                    labelText: 'Protocol',
                    hintText: 'TCP, UDP, any',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _interfaceName,
            decoration: const InputDecoration(
              labelText: 'Interface',
              hintText: 'Optional interface identifier',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Source',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _source,
            decoration: const InputDecoration(
              labelText: 'Network / alias',
              hintText: 'any, 192.168.1.0/24, alias_name',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sourcePort,
            decoration: const InputDecoration(labelText: 'Port / alias'),
          ),
          const SizedBox(height: 16),
          Text(
            'Destination',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _destination,
            decoration: const InputDecoration(
              labelText: 'Network / alias',
              hintText: 'any, 10.0.0.0/24, alias_name',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _destinationPort,
            decoration: const InputDecoration(labelText: 'Port / alias'),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Log matches'),
            value: _logging,
            onChanged: (value) => setState(() => _logging = value),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Sentinel applies rule changes with firewall savepoint/rollback protection and verifies API reachability before confirming the change.',
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(editing ? 'Save rule' : 'Add rule'),
          ),
        ],
      ),
    );
  }
}
