import 'package:flutter/material.dart';

import '../../core/api/api_choice.dart';
import '../../core/widgets/api_select_fields.dart';
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
  late final TextEditingController _source;
  late final TextEditingController _sourcePort;
  late final TextEditingController _destination;
  late final TextEditingController _destinationPort;
  String _action = 'pass';
  String _direction = 'in';
  String? _protocol;
  Set<String> _interfaces = <String>{};
  List<ApiChoice> _interfaceChoices = const [];
  List<ApiChoice> _protocolChoices = const [
    ApiChoice(value: 'any', label: 'Any'),
    ApiChoice(value: 'tcp', label: 'TCP'),
    ApiChoice(value: 'udp', label: 'UDP'),
    ApiChoice(value: 'tcp/udp', label: 'TCP/UDP'),
    ApiChoice(value: 'icmp', label: 'ICMP'),
    ApiChoice(value: 'icmp6', label: 'ICMPv6'),
    ApiChoice(value: 'esp', label: 'ESP'),
    ApiChoice(value: 'gre', label: 'GRE'),
  ];
  bool _enabled = true;
  bool _logging = false;
  bool _busy = false;
  bool _optionsLoading = false;

  @override
  void initState() {
    super.initState();
    String value(List<String> keys, String fallback) {
      for (final key in keys) {
        final raw = widget.initial[key];
        if (raw is String || raw is num) {
          final text = raw.toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
      return fallback;
    }

    _description = TextEditingController(
      text: value(
        const ['description', 'descr'],
        widget.rule?.description ?? '',
      ),
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
    _applyOptions(widget.initial);
    _loadOptions();
  }

  void _applyOptions(Map<String, dynamic> model) {
    final interfaces = FirewallRepository.choices(model, 'interface');
    if (interfaces.isNotEmpty) _interfaceChoices = interfaces;
    final selectedInterfaces = FirewallRepository.selectedChoices(
      model,
      'interface',
    );
    if (selectedInterfaces.isNotEmpty) _interfaces = selectedInterfaces;

    final protocols = FirewallRepository.choices(model, 'protocol');
    if (protocols.isNotEmpty) _protocolChoices = protocols;
    _protocol ??= FirewallRepository.selectedChoice(model, 'protocol');

    if (_interfaces.isEmpty && widget.rule?.interfaceName.isNotEmpty == true) {
      _interfaces = _split(widget.rule!.interfaceName);
    }
    _protocol ??= widget.rule?.protocol.toLowerCase();
    if (_protocol == null || _protocol!.isEmpty) _protocol = 'any';
  }

  Future<void> _loadOptions() async {
    setState(() => _optionsLoading = true);
    try {
      final model = await widget.repository.getRule(widget.rule?.uuid);
      if (!mounted) return;
      setState(() => _applyOptions(model));
    } catch (_) {
      // Existing/fallback values remain usable when option metadata is denied.
    } finally {
      if (mounted) setState(() => _optionsLoading = false);
    }
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
    _source.dispose();
    _sourcePort.dispose();
    _destination.dispose();
    _destinationPort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_interfaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one interface.')),
      );
      return;
    }
    setState(() => _busy = true);
    final values = <String, dynamic>{
      'description': _description.text.trim(),
      'action': _action,
      'direction': _direction,
      'protocol': _protocol == 'any' ? '' : (_protocol ?? ''),
      'interface': _interfaces.toList()..sort(),
      'source_net': _source.text.trim(),
      'source_port': _sourcePort.text.trim(),
      'destination_net': _destination.text.trim(),
      'destination_port': _destinationPort.text.trim(),
      'enabled': _enabled ? '1' : '0',
      'log': _logging ? '1' : '0',
    };
    if (values['interface'] is List) {
      values['interface'] = (values['interface'] as List).join(',');
    }
    try {
      final revision = await widget.repository.saveRuleSafely(
        uuid: widget.rule?.uuid,
        values: values,
      );
      try {
        await widget.audit.record(
          action: widget.rule == null
              ? 'Add firewall rule'
              : 'Edit firewall rule',
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
          if (_optionsLoading) const LinearProgressIndicator(),
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
          DropdownButtonFormField<String>(
            initialValue: _direction,
            decoration: const InputDecoration(labelText: 'Direction'),
            items: const [
              DropdownMenuItem(value: 'in', child: Text('In')),
              DropdownMenuItem(value: 'out', child: Text('Out')),
            ],
            onChanged: (value) => setState(() => _direction = value ?? 'in'),
          ),
          const SizedBox(height: 12),
          ApiSingleSelectField(
            label: 'Protocol',
            choices: _protocolChoices,
            value: _protocol,
            allowEmpty: false,
            prefixIcon: Icons.route_outlined,
            onChanged: (value) => setState(() => _protocol = value),
          ),
          const SizedBox(height: 12),
          if (_interfaceChoices.isNotEmpty)
            ApiMultiSelectField(
              label: 'Interfaces',
              choices: _interfaceChoices,
              selected: _interfaces,
              prefixIcon: Icons.settings_ethernet,
              searchHint: 'Search interfaces',
              onChanged: (values) => setState(() => _interfaces = values),
            )
          else
            TextFormField(
              initialValue: _interfaces.join(','),
              decoration: const InputDecoration(
                labelText: 'Interfaces',
                hintText: 'Interface IDs separated by commas',
              ),
              onChanged: (value) => _interfaces = _split(value),
            ),
          const SizedBox(height: 16),
          _section(context, 'Source'),
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
          _section(context, 'Destination'),
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
                'Sentinel applies rule changes with firewall rollback protection and verifies management reachability before confirming the change.',
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

  Widget _section(BuildContext context, String title) => Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      );

  Set<String> _split(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
}
