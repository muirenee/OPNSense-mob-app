import 'package:flutter/material.dart';

import '../../../core/api/api_choice.dart';
import '../../../core/widgets/api_select_fields.dart';
import '../../audit/audit_repository.dart';
import 'nat_models.dart';
import 'nat_repository.dart';

class NatRuleEditor extends StatefulWidget {
  const NatRuleEditor({
    super.key,
    required this.repository,
    required this.audit,
    this.rule,
    this.initial = const <String, dynamic>{},
  });

  final NatRepository repository;
  final AuditRepository audit;
  final NatRuleSummary? rule;
  final Map<String, dynamic> initial;

  @override
  State<NatRuleEditor> createState() => _NatRuleEditorState();
}

class _NatRuleEditorState extends State<NatRuleEditor> {
  late final TextEditingController _description;
  late final TextEditingController _source;
  late final TextEditingController _sourcePort;
  late final TextEditingController _destination;
  late final TextEditingController _destinationPort;
  late final TextEditingController _target;
  late final TextEditingController _targetPort;
  List<ApiChoice> _interfaceChoices = const [];
  Set<String> _interfaces = <String>{};
  String _ipProtocol = 'inet';
  String _protocol = 'tcp';
  String _reflection = '';
  String _pass = 'rule';
  bool _enabled = true;
  bool _log = false;
  bool _busy = false;
  bool _optionsLoading = false;

  @override
  void initState() {
    super.initState();
    String scalar(List<String> keys, String fallback) {
      for (final key in keys) {
        final value = _read(widget.initial, key);
        if (value is String || value is num) {
          final text = value.toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
      return fallback;
    }

    _description = TextEditingController(
      text: scalar(
        const ['descr', 'description'],
        widget.rule?.description ?? '',
      ),
    );
    _source = TextEditingController(
      text: scalar(
        const ['source.network', 'source_net'],
        widget.rule?.source ?? '',
      ),
    );
    _sourcePort = TextEditingController(
      text: scalar(
        const ['source.port', 'source_port'],
        widget.rule?.sourcePort ?? '',
      ),
    );
    _destination = TextEditingController(
      text: scalar(
        const ['destination.network', 'destination_net'],
        widget.rule?.destination ?? 'wanip',
      ),
    );
    _destinationPort = TextEditingController(
      text: scalar(
        const ['destination.port', 'destination_port'],
        widget.rule?.destinationPort ?? '',
      ),
    );
    _target = TextEditingController(
      text: scalar(const ['target'], widget.rule?.target ?? ''),
    );
    _targetPort = TextEditingController(
      text: scalar(
        const ['local-port', 'local_port'],
        widget.rule?.targetPort ?? '',
      ),
    );
    _ipProtocol = scalar(const ['ipprotocol'], 'inet').toLowerCase();
    if (!const {'inet', 'inet6', 'inet46'}.contains(_ipProtocol)) {
      _ipProtocol = 'inet';
    }
    _protocol = scalar(
      const ['protocol'],
      widget.rule?.protocol ?? 'tcp',
    ).toLowerCase();
    if (!const {'tcp', 'udp', 'tcp/udp', 'any'}.contains(_protocol)) {
      _protocol = 'tcp';
    }
    _reflection = scalar(const ['natreflection'], '');
    if (!const {'', 'purenat', 'disable'}.contains(_reflection)) {
      _reflection = '';
    }
    _pass = scalar(const ['pass'], 'rule');
    if (!const {'', 'pass', 'rule'}.contains(_pass)) _pass = 'rule';
    final disabled = _read(widget.initial, 'disabled');
    _enabled = disabled == null
        ? (widget.rule?.enabled ?? true)
        : !_truthy(disabled);
    _log = _truthy(_read(widget.initial, 'log'));
    _applyOptions(widget.initial);
    _loadOptions();
  }

  void _applyOptions(Map<String, dynamic> model) {
    final choices = NatRepository.choices(model, 'interface');
    if (choices.isNotEmpty) _interfaceChoices = choices;
    final selected = NatRepository.selectedChoices(model, 'interface');
    if (selected.isNotEmpty) _interfaces = selected;
    if (_interfaces.isEmpty && widget.rule?.interfaceName.isNotEmpty == true) {
      _interfaces = _split(widget.rule!.interfaceName);
    }
  }

  Future<void> _loadOptions() async {
    setState(() => _optionsLoading = true);
    try {
      final model = widget.rule == null
          ? await widget.repository.getDefaultRule(NatRuleKind.portForward)
          : await widget.repository.getRule(widget.rule!);
      if (!mounted) return;
      setState(() => _applyOptions(model));
    } catch (_) {
      // A manual fallback remains available if option metadata is unavailable.
    } finally {
      if (mounted) setState(() => _optionsLoading = false);
    }
  }

  dynamic _read(Map<String, dynamic> map, String key) {
    dynamic value = map;
    for (final part in key.split('.')) {
      if (value is Map) {
        value = value[part];
      } else {
        return null;
      }
    }
    return value;
  }

  bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return const {'1', 'true', 'yes', 'on', 'enabled'}.contains(text);
  }

  Set<String> _split(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();

  @override
  void dispose() {
    _description.dispose();
    _source.dispose();
    _sourcePort.dispose();
    _destination.dispose();
    _destinationPort.dispose();
    _target.dispose();
    _targetPort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_interfaces.isEmpty ||
        _destination.text.trim().isEmpty ||
        _target.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Interface, destination and redirect target are required.',
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    final sortedInterfaces = _interfaces.toList()..sort();
    final values = <String, dynamic>{
      'disabled': _enabled ? '0' : '1',
      'interface': sortedInterfaces.join(','),
      'ipprotocol': _ipProtocol,
      'protocol': _protocol == 'any' ? '' : _protocol,
      'source': {
        'network': _source.text.trim(),
        'port': _sourcePort.text.trim(),
      },
      'destination': {
        'network': _destination.text.trim(),
        'port': _destinationPort.text.trim(),
      },
      'target': _target.text.trim(),
      'local-port': _targetPort.text.trim(),
      'log': _log ? '1' : '0',
      'natreflection': _reflection,
      'pass': _pass,
      'descr': _description.text.trim(),
    };

    try {
      final revision = await widget.repository.saveRuleSafely(
        kind: NatRuleKind.portForward,
        uuid: widget.rule?.uuid,
        values: values,
      );
      try {
        await widget.audit.record(
          action: widget.rule == null
              ? 'Add NAT port forward'
              : 'Edit NAT port forward',
          target: _description.text.trim().isEmpty
              ? '${_destination.text}:${_destinationPort.text}'
              : _description.text.trim(),
          result: 'success',
          details: 'rollback revision $revision',
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save port forward: $error')),
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
        title: Text(editing ? 'Edit port forward' : 'Add port forward'),
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
          if (_interfaceChoices.isNotEmpty)
            ApiMultiSelectField(
              label: 'Interfaces',
              choices: _interfaceChoices,
              selected: _interfaces,
              prefixIcon: Icons.settings_ethernet,
              helperText: 'Select the interface(s) that receive this traffic.',
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _ipProtocol,
                  decoration: const InputDecoration(labelText: 'IP version'),
                  items: const [
                    DropdownMenuItem(value: 'inet', child: Text('IPv4')),
                    DropdownMenuItem(value: 'inet6', child: Text('IPv6')),
                    DropdownMenuItem(
                      value: 'inet46',
                      child: Text('IPv4 + IPv6'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _ipProtocol = value ?? 'inet'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _protocol,
                  decoration: const InputDecoration(labelText: 'Protocol'),
                  items: const [
                    DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                    DropdownMenuItem(value: 'udp', child: Text('UDP')),
                    DropdownMenuItem(
                      value: 'tcp/udp',
                      child: Text('TCP/UDP'),
                    ),
                    DropdownMenuItem(value: 'any', child: Text('Any')),
                  ],
                  onChanged: (value) =>
                      setState(() => _protocol = value ?? 'tcp'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(context, 'Source'),
          const SizedBox(height: 8),
          TextField(
            controller: _source,
            decoration: const InputDecoration(
              labelText: 'Source network / alias',
              hintText: 'Blank for any',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sourcePort,
            decoration: const InputDecoration(
              labelText: 'Source port / alias / range',
            ),
          ),
          const SizedBox(height: 16),
          _section(context, 'Destination'),
          const SizedBox(height: 8),
          TextField(
            controller: _destination,
            decoration: const InputDecoration(
              labelText: 'Destination network / alias',
              hintText: 'Example: wanip',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _destinationPort,
            decoration: const InputDecoration(
              labelText: 'Destination port / range',
            ),
          ),
          const SizedBox(height: 16),
          _section(context, 'Redirect'),
          const SizedBox(height: 8),
          TextField(
            controller: _target,
            decoration: const InputDecoration(
              labelText: 'Redirect target IP / alias',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _targetPort,
            decoration: const InputDecoration(labelText: 'Redirect target port'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _reflection,
            decoration: const InputDecoration(labelText: 'NAT reflection'),
            items: const [
              DropdownMenuItem(
                value: '',
                child: Text('Use system default'),
              ),
              DropdownMenuItem(value: 'purenat', child: Text('Enable')),
              DropdownMenuItem(value: 'disable', child: Text('Disable')),
            ],
            onChanged: (value) => setState(() => _reflection = value ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _pass,
            decoration: const InputDecoration(labelText: 'Filter rule handling'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Manual')),
              DropdownMenuItem(value: 'pass', child: Text('Pass')),
              DropdownMenuItem(
                value: 'rule',
                child: Text('Register associated rule'),
              ),
            ],
            onChanged: (value) => setState(() => _pass = value ?? 'rule'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Log matches'),
            value: _log,
            onChanged: (value) => setState(() => _log = value),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Sentinel applies Destination NAT changes with rollback protection and verifies management reachability before confirming them.',
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
            label: Text(editing ? 'Save port forward' : 'Add port forward'),
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
}
