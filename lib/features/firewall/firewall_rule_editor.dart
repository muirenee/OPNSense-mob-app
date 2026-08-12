import 'package:flutter/material.dart';

import '../../core/api/api_choice.dart';
import '../../core/widgets/api_select_fields.dart';
import '../../core/widgets/api_text_selector_field.dart';
import '../audit/audit_repository.dart';
import 'firewall_models.dart';
import 'firewall_reference_repository.dart';
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
  String _ipProtocol = 'inet';
  String _protocol = 'any';
  String _stateType = 'keep';

  Set<String> _interfaces = <String>{};
  List<ApiChoice> _interfaceChoices = const [];
  List<ApiChoice> _networkChoices = const [];
  List<ApiChoice> _portChoices = const [];
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
  List<ApiChoice> _stateTypeChoices = const [
    ApiChoice(value: 'keep', label: 'Keep state'),
    ApiChoice(value: 'sloppy', label: 'Sloppy state'),
    ApiChoice(value: 'modulate', label: 'Modulate state'),
    ApiChoice(value: 'synproxy', label: 'Synproxy state'),
    ApiChoice(value: 'none', label: 'No state'),
  ];

  bool _quick = true;
  bool _interfaceNot = false;
  bool _sourceNot = false;
  bool _destinationNot = false;
  bool _enabled = true;
  bool _logging = false;
  bool _busy = false;
  bool _optionsLoading = false;

  @override
  void initState() {
    super.initState();

    _description = TextEditingController(text: widget.rule?.description ?? '');
    _source = TextEditingController(
      text: widget.rule?.source.isNotEmpty == true ? widget.rule!.source : 'any',
    );
    _sourcePort = TextEditingController(text: widget.rule?.sourcePort ?? '');
    _destination = TextEditingController(
      text: widget.rule?.destination.isNotEmpty == true
          ? widget.rule!.destination
          : 'any',
    );
    _destinationPort = TextEditingController(
      text: widget.rule?.destinationPort ?? '',
    );

    if (widget.rule != null) {
      final action = widget.rule!.action.toLowerCase();
      if (const {'pass', 'block', 'reject'}.contains(action)) _action = action;
      final direction = widget.rule!.direction.toLowerCase();
      if (const {'in', 'out', 'any'}.contains(direction)) {
        _direction = direction;
      }
      if (widget.rule!.interfaceName.isNotEmpty) {
        _interfaces = _split(widget.rule!.interfaceName);
      }
      if (widget.rule!.protocol.isNotEmpty) {
        _protocol = widget.rule!.protocol.toLowerCase();
      }
      _enabled = widget.rule!.enabled;
      _logging = widget.rule!.logging;
    }

    _applyModel(widget.initial, overwriteValues: true);
    _loadOptions();
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

  void _applyModel(
    Map<String, dynamic> model, {
    required bool overwriteValues,
  }) {
    if (model.isEmpty) return;

    final interfaces = FirewallRepository.choices(model, 'interface');
    if (interfaces.isNotEmpty) _interfaceChoices = interfaces;

    final protocols = FirewallRepository.choices(model, 'protocol');
    if (protocols.isNotEmpty) _protocolChoices = protocols;

    final stateTypes = FirewallRepository.choices(model, 'statetype');
    if (stateTypes.isNotEmpty) _stateTypeChoices = stateTypes;

    if (!overwriteValues) return;

    final description = _scalarField(model, const ['description', 'descr']);
    if (description != null) _description.text = description;

    final source = _multiField(model, 'source_net');
    if (source != null && source.isNotEmpty) _source.text = source;

    final sourcePort = _singleField(model, 'source_port');
    if (sourcePort != null) _sourcePort.text = _normalizePort(sourcePort);

    final destination = _multiField(model, 'destination_net');
    if (destination != null && destination.isNotEmpty) {
      _destination.text = destination;
    }

    final destinationPort = _singleField(model, 'destination_port');
    if (destinationPort != null) {
      _destinationPort.text = _normalizePort(destinationPort);
    }

    _action = _validatedChoice(
      _singleField(model, 'action'),
      const {'pass', 'block', 'reject'},
      _action,
    );
    _direction = _validatedChoice(
      _singleField(model, 'direction'),
      const {'in', 'out', 'any'},
      _direction,
    );
    _ipProtocol = _validatedChoice(
      _singleField(model, 'ipprotocol'),
      const {'inet', 'inet6', 'inet46'},
      _ipProtocol,
    );

    final protocol = _singleField(model, 'protocol');
    if (protocol != null && protocol.isNotEmpty) _protocol = protocol;

    final stateType = _singleField(model, 'statetype');
    if (stateType != null && stateType.isNotEmpty) _stateType = stateType;

    final selectedInterfaces = FirewallRepository.selectedChoices(
      model,
      'interface',
    );
    if (selectedInterfaces.isNotEmpty) _interfaces = selectedInterfaces;

    _quick = _booleanField(model, 'quick', _quick);
    _interfaceNot = _booleanField(model, 'interfacenot', _interfaceNot);
    _sourceNot = _booleanField(model, 'source_not', _sourceNot);
    _destinationNot = _booleanField(model, 'destination_not', _destinationNot);
    _enabled = _booleanField(model, 'enabled', _enabled);
    _logging = _booleanField(model, 'log', _logging);
  }

  Future<void> _loadOptions() async {
    if (mounted) setState(() => _optionsLoading = true);

    try {
      // get_rule without a UUID returns OPNsense's real defaults and option
      // inventories. With a UUID it returns the selected values for that rule.
      final model = await widget.repository.getRule(widget.rule?.uuid);
      if (mounted) {
        setState(() => _applyModel(model, overwriteValues: true));
      }
    } catch (_) {
      // Existing values remain editable even if model lookup is restricted.
    }

    try {
      final references =
          await FirewallReferenceRepository(widget.repository.api).load();
      if (mounted) {
        setState(() {
          _networkChoices = references.networks;
          _portChoices = references.ports;
        });
      }
    } catch (_) {
      // Manual IP/CIDR/port entry remains available without alias-list ACL.
    } finally {
      if (mounted) setState(() => _optionsLoading = false);
    }
  }

  Future<void> _save() async {
    if (_interfaces.isEmpty) {
      _showMessage('Select at least one interface.');
      return;
    }

    final source = _source.text.trim();
    final destination = _destination.text.trim();
    if (source.isEmpty || destination.isEmpty) {
      _showMessage('Source and destination are required. Use "any" when unrestricted.');
      return;
    }

    setState(() => _busy = true);
    try {
      final values = <String, dynamic>{
        'description': _description.text.trim(),
        'action': _action,
        'quick': _quick ? '1' : '0',
        'interfacenot': _interfaceNot ? '1' : '0',
        'interface': encodeApiChoiceValues(_interfaces),
        'direction': _direction,
        'ipprotocol': _ipProtocol,
        'protocol': _protocol,
        'statetype': _stateType,
        'source_net': _normalizeNetworkList(source),
        'source_not': _sourceNot ? '1' : '0',
        'source_port': _normalizePort(_sourcePort.text),
        'destination_net': _normalizeNetworkList(destination),
        'destination_not': _destinationNot ? '1' : '0',
        'destination_port': _normalizePort(_destinationPort.text),
        'enabled': _enabled ? '1' : '0',
        'log': _logging ? '1' : '0',
      };

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
      if (mounted) _showMessage('Unable to save firewall rule: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          if (_optionsLoading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _action,
                  decoration: const InputDecoration(labelText: 'Action'),
                  items: const [
                    DropdownMenuItem(value: 'pass', child: Text('Pass')),
                    DropdownMenuItem(value: 'block', child: Text('Block')),
                    DropdownMenuItem(value: 'reject', child: Text('Reject')),
                  ],
                  onChanged: (value) =>
                      setState(() => _action = value ?? 'pass'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _direction,
                  decoration: const InputDecoration(labelText: 'Direction'),
                  items: const [
                    DropdownMenuItem(value: 'in', child: Text('In')),
                    DropdownMenuItem(value: 'out', child: Text('Out')),
                    DropdownMenuItem(value: 'any', child: Text('Both')),
                  ],
                  onChanged: (value) =>
                      setState(() => _direction = value ?? 'in'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _ipProtocol,
                  decoration: const InputDecoration(labelText: 'IP version'),
                  items: const [
                    DropdownMenuItem(value: 'inet', child: Text('IPv4')),
                    DropdownMenuItem(value: 'inet6', child: Text('IPv6')),
                    DropdownMenuItem(value: 'inet46', child: Text('IPv4 + IPv6')),
                  ],
                  onChanged: (value) =>
                      setState(() => _ipProtocol = value ?? 'inet'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ApiSingleSelectField(
                  label: 'Protocol',
                  choices: _protocolChoices,
                  value: _protocol,
                  allowEmpty: false,
                  onChanged: (value) =>
                      setState(() => _protocol = value ?? 'any'),
                ),
              ),
            ],
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
                hintText: 'lan,wan,opt1',
              ),
              onChanged: (value) => _interfaces = _split(value),
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Invert interface'),
            subtitle: const Text('Apply to all interfaces except the selected ones.'),
            value: _interfaceNot,
            onChanged: (value) => setState(() => _interfaceNot = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quick'),
            subtitle: const Text('Stop evaluating later rules when this rule matches.'),
            value: _quick,
            onChanged: (value) => setState(() => _quick = value),
          ),
          const SizedBox(height: 8),
          _section(context, 'Source'),
          const SizedBox(height: 8),
          ApiTextSelectorField(
            controller: _source,
            label: 'Source network / alias',
            choices: _networkChoices,
            allowMultiple: true,
            prefixIcon: Icons.call_made_outlined,
            hintText: 'any, 192.168.1.0/24, LAN_NET',
            helperText:
                'Select OPNsense networks/aliases or type an IP, CIDR or alias. Multiple values use commas.',
            searchHint: 'Search source networks and aliases',
          ),
          const SizedBox(height: 10),
          ApiTextSelectorField(
            controller: _sourcePort,
            label: 'Source port / alias / range',
            choices: _portChoices,
            prefixIcon: Icons.numbers_outlined,
            hintText: 'https, 5060, 10000-20000, PORT_ALIAS',
            helperText: 'Leave blank for Any. Select a service/port alias or enter a port/range.',
            searchHint: 'Search services and port aliases',
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Invert source'),
            value: _sourceNot,
            onChanged: (value) => setState(() => _sourceNot = value),
          ),
          const SizedBox(height: 8),
          _section(context, 'Destination'),
          const SizedBox(height: 8),
          ApiTextSelectorField(
            controller: _destination,
            label: 'Destination network / alias',
            choices: _networkChoices,
            allowMultiple: true,
            prefixIcon: Icons.call_received_outlined,
            hintText: 'any, WAN address, 10.0.0.0/24, SERVER_ALIAS',
            helperText:
                'Select OPNsense networks/aliases or type an IP, CIDR or alias. Multiple values use commas.',
            searchHint: 'Search destination networks and aliases',
          ),
          const SizedBox(height: 10),
          ApiTextSelectorField(
            controller: _destinationPort,
            label: 'Destination port / alias / range',
            choices: _portChoices,
            prefixIcon: Icons.numbers_outlined,
            hintText: 'https, 443, 5060, 10000-20000, PORT_ALIAS',
            helperText: 'Leave blank for Any. Select a service/port alias or enter a port/range.',
            searchHint: 'Search services and port aliases',
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Invert destination'),
            value: _destinationNot,
            onChanged: (value) => setState(() => _destinationNot = value),
          ),
          const SizedBox(height: 8),
          _section(context, 'Rule options'),
          const SizedBox(height: 8),
          ApiSingleSelectField(
            label: 'State type',
            choices: _stateTypeChoices,
            value: _stateType,
            allowEmpty: false,
            onChanged: (value) =>
                setState(() => _stateType = value ?? 'keep'),
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
            value: _logging,
            onChanged: (value) => setState(() => _logging = value),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Network, alias and port choices are loaded from OPNsense. Custom IP/CIDR/port/range values remain editable. Changes are applied with rollback protection.',
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy || _optionsLoading ? null : _save,
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

  static Widget _section(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }

  static Set<String> _split(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();

  static String _validatedChoice(
    String? value,
    Set<String> allowed,
    String fallback,
  ) {
    if (value == null || value.isEmpty) return fallback;
    final normalized = value.toLowerCase();
    return allowed.contains(normalized) ? normalized : fallback;
  }

  static String? _scalarField(
    Map<String, dynamic> model,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = model[key];
      if (raw is String || raw is num || raw is bool) {
        return raw.toString().trim();
      }
    }
    return null;
  }

  static String? _singleField(Map<String, dynamic> model, String field) {
    final selected = selectedApiChoiceValues(model[field]);
    if (selected.isNotEmpty) return selected.first;
    final raw = model[field];
    if (raw is String || raw is num) return raw.toString().trim();
    return null;
  }

  static String? _multiField(Map<String, dynamic> model, String field) {
    final selected = selectedApiChoiceValues(model[field]);
    if (selected.isNotEmpty) {
      final values = selected.toList()..sort();
      return values.join(',');
    }
    final raw = model[field];
    if (raw is String || raw is num) return raw.toString().trim();
    return null;
  }

  static bool _booleanField(
    Map<String, dynamic> model,
    String field,
    bool fallback,
  ) {
    final value = _singleField(model, field)?.toLowerCase();
    if (value == null || value.isEmpty) return fallback;
    if (const {'1', 'true', 'yes', 'on', 'enabled'}.contains(value)) {
      return true;
    }
    if (const {'0', 'false', 'no', 'off', 'disabled'}.contains(value)) {
      return false;
    }
    return fallback;
  }

  static String _normalizePort(String value) {
    final trimmed = value.trim();
    return trimmed.toLowerCase() == 'any' ? '' : trimmed;
  }

  static String _normalizeNetworkList(String value) {
    final values = value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return values.join(',');
  }
}
