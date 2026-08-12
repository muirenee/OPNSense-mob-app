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
  late final TextEditingController _sequence;
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
    ApiChoice(value: 'TCP', label: 'TCP'),
    ApiChoice(value: 'UDP', label: 'UDP'),
    ApiChoice(value: 'TCP/UDP', label: 'TCP/UDP'),
    ApiChoice(value: 'ICMP', label: 'ICMP'),
    ApiChoice(value: 'IPV6-ICMP', label: 'ICMPv6'),
    ApiChoice(value: 'ESP', label: 'ESP'),
    ApiChoice(value: 'GRE', label: 'GRE'),
  ];
  List<ApiChoice> _stateTypeChoices = const [
    ApiChoice(value: 'keep', label: 'keep state'),
    ApiChoice(value: 'sloppy', label: 'sloppy state'),
    ApiChoice(value: 'modulate', label: 'modulate state'),
    ApiChoice(value: 'synproxy', label: 'synproxy state'),
    ApiChoice(value: 'none', label: 'no state'),
  ];

  bool _sourceNot = false;
  bool _destinationNot = false;
  bool _interfaceNot = false;
  bool _quick = true;
  bool _enabled = true;
  bool _logging = false;
  bool _busy = false;
  bool _optionsLoading = false;

  bool get _portsSupported =>
      FirewallRepository.protocolSupportsPorts(_protocol);

  @override
  void initState() {
    super.initState();

    final sourceFallback = widget.rule?.source.isNotEmpty == true
        ? widget.rule!.source
        : 'any';
    final destinationFallback = widget.rule?.destination.isNotEmpty == true
        ? widget.rule!.destination
        : 'any';

    _description = TextEditingController(
      text: FirewallRepository.fieldValue(
        widget.initial,
        'description',
        fallback: widget.rule?.description ?? '',
      ),
    );
    _sequence = TextEditingController(
      text: FirewallRepository.fieldValue(widget.initial, 'sequence'),
    );
    _source = TextEditingController(
      text: FirewallRepository.fieldValue(
        widget.initial,
        'source_net',
        fallback: sourceFallback,
      ),
    );
    _sourcePort = TextEditingController(
      text: FirewallRepository.fieldValue(
        widget.initial,
        'source_port',
        fallback: widget.rule?.sourcePort ?? '',
      ),
    );
    _destination = TextEditingController(
      text: FirewallRepository.fieldValue(
        widget.initial,
        'destination_net',
        fallback: destinationFallback,
      ),
    );
    _destinationPort = TextEditingController(
      text: FirewallRepository.fieldValue(
        widget.initial,
        'destination_port',
        fallback: widget.rule?.destinationPort ?? '',
      ),
    );

    _action = FirewallRepository.fieldValue(
      widget.initial,
      'action',
      fallback: widget.rule?.action ?? 'pass',
    ).toLowerCase();
    if (!const {'pass', 'block', 'reject'}.contains(_action)) {
      _action = 'pass';
    }

    _direction = FirewallRepository.fieldValue(
      widget.initial,
      'direction',
      fallback: widget.rule?.direction ?? 'in',
    ).toLowerCase();
    if (!const {'in', 'out', 'any'}.contains(_direction)) {
      _direction = 'in';
    }

    _ipProtocol = FirewallRepository.fieldValue(
      widget.initial,
      'ipprotocol',
      fallback: 'inet',
    ).toLowerCase();
    if (!const {'inet', 'inet6', 'inet46'}.contains(_ipProtocol)) {
      _ipProtocol = 'inet';
    }

    _protocol = FirewallRepository.normalizeProtocol(
      FirewallRepository.fieldValue(
        widget.initial,
        'protocol',
        fallback: widget.rule?.protocol ?? 'any',
      ),
    );
    _stateType = FirewallRepository.fieldValue(
      widget.initial,
      'statetype',
      fallback: 'keep',
    );

    _sourceNot = _truthy(widget.initial['source_not'], false);
    _destinationNot = _truthy(widget.initial['destination_not'], false);
    _interfaceNot = _truthy(widget.initial['interfacenot'], false);
    _quick = _truthy(widget.initial['quick'], true);
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
    if (selectedInterfaces.isNotEmpty) {
      _interfaces = selectedInterfaces;
    } else if (_interfaces.isEmpty &&
        widget.rule?.interfaceName.isNotEmpty == true) {
      _interfaces = _split(widget.rule!.interfaceName);
    }

    final protocols = FirewallRepository.choices(model, 'protocol');
    if (protocols.isNotEmpty) _protocolChoices = protocols;
    final selectedProtocol = FirewallRepository.selectedChoice(model, 'protocol');
    if (selectedProtocol != null && selectedProtocol.isNotEmpty) {
      _protocol = FirewallRepository.normalizeProtocol(selectedProtocol);
    }

    final stateTypes = FirewallRepository.choices(model, 'statetype');
    if (stateTypes.isNotEmpty) _stateTypeChoices = stateTypes;
    final stateType = FirewallRepository.selectedChoice(model, 'statetype');
    if (stateType != null && stateType.isNotEmpty) _stateType = stateType;

    final action = FirewallRepository.selectedChoice(model, 'action');
    if (action != null && const {'pass', 'block', 'reject'}.contains(action)) {
      _action = action;
    }
    final direction = FirewallRepository.selectedChoice(model, 'direction');
    if (direction != null && const {'in', 'out', 'any'}.contains(direction)) {
      _direction = direction;
    }
    final ipProtocol = FirewallRepository.selectedChoice(model, 'ipprotocol');
    if (ipProtocol != null &&
        const {'inet', 'inet6', 'inet46'}.contains(ipProtocol)) {
      _ipProtocol = ipProtocol;
    }
  }

  Future<void> _loadOptions() async {
    setState(() => _optionsLoading = true);
    try {
      final model = await widget.repository.getRule(widget.rule?.uuid);
      if (mounted) setState(() => _applyOptions(model));
    } catch (_) {
      // The initial model/fallback values remain editable.
    }

    try {
      final interfaces = await widget.repository.loadInterfaceChoices();
      if (mounted && interfaces.isNotEmpty) {
        setState(() => _interfaceChoices = interfaces);
      }
    } catch (_) {
      // get_rule interface options remain available when this endpoint is ACL blocked.
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
      // Manual address/port entry remains available without alias lookup ACL.
    } finally {
      if (mounted) setState(() => _optionsLoading = false);
    }
  }

  static bool _truthy(dynamic value, bool fallback) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (const {'1', 'true', 'yes', 'on', 'enabled'}.contains(text)) return true;
    if (const {'0', 'false', 'no', 'off', 'disabled', ''}.contains(text)) {
      return false;
    }
    return fallback;
  }

  @override
  void dispose() {
    _description.dispose();
    _sequence.dispose();
    _source.dispose();
    _sourcePort.dispose();
    _destination.dispose();
    _destinationPort.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final source = _source.text.trim();
    final destination = _destination.text.trim();
    if (source.isEmpty || destination.isEmpty) {
      _message('Source and destination are required. Use "any" when unrestricted.');
      return;
    }

    if (_hasAnyCombination(source) || _hasAnyCombination(destination)) {
      _message('"any" cannot be combined with another network or alias.');
      return;
    }
    if (_sourceNot && _split(source).length > 1) {
      _message('OPNsense only allows source inversion with one source value.');
      return;
    }
    if (_destinationNot && _split(destination).length > 1) {
      _message('OPNsense only allows destination inversion with one destination value.');
      return;
    }
    if (_interfaceNot && _interfaces.length != 1) {
      _message('OPNsense only allows interface inversion with exactly one interface.');
      return;
    }

    final sequenceText = _sequence.text.trim();
    if (sequenceText.isNotEmpty) {
      final sequence = int.tryParse(sequenceText);
      if (sequence == null || sequence < 1 || sequence > 999999) {
        _message('Sequence must be a number between 1 and 999999.');
        return;
      }
    }

    setState(() => _busy = true);
    final interfaces = _interfaces.toList()..sort();
    final protocol = FirewallRepository.normalizeProtocol(_protocol);
    final values = <String, dynamic>{
      'description': _description.text.trim(),
      if (sequenceText.isNotEmpty) 'sequence': sequenceText,
      'action': _action,
      'quick': _quick ? '1' : '0',
      'interfacenot': _interfaceNot ? '1' : '0',
      'interface': interfaces.join(','),
      'direction': _direction,
      'ipprotocol': _ipProtocol,
      'protocol': protocol,
      'statetype': _stateType,
      'source_net': source,
      'source_not': _sourceNot ? '1' : '0',
      'source_port': _portsSupported
          ? FirewallRepository.normalizePort(_sourcePort.text)
          : '',
      'destination_net': destination,
      'destination_not': _destinationNot ? '1' : '0',
      'destination_port': _portsSupported
          ? FirewallRepository.normalizePort(_destinationPort.text)
          : '',
      'enabled': _enabled ? '1' : '0',
      'log': _logging ? '1' : '0',
    };

    try {
      final applyResult = await widget.repository.saveRuleSafely(
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
          details: 'OPNsense apply: $applyResult',
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _message('Unable to save firewall rule: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setProtocol(String? value) {
    final normalized = FirewallRepository.normalizeProtocol(value);
    setState(() {
      _protocol = normalized;
      if (!FirewallRepository.protocolSupportsPorts(normalized)) {
        _sourcePort.clear();
        _destinationPort.clear();
      }
    });
  }

  void _setInterfaces(Set<String> values) {
    setState(() {
      _interfaces = values;
      if (_interfaces.length != 1) _interfaceNot = false;
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _action,
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
                child: TextField(
                  controller: _sequence,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sequence',
                    helperText: '1–999999',
                  ),
                ),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quick / first match'),
            subtitle: const Text(
              'Stop evaluating later rules after this rule matches.',
            ),
            value: _quick,
            onChanged: (value) => setState(() => _quick = value),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _direction,
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
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _ipProtocol,
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
            ],
          ),
          const SizedBox(height: 12),
          ApiSingleSelectField(
            label: 'Protocol',
            choices: _protocolChoices,
            value: _protocol,
            allowEmpty: false,
            prefixIcon: Icons.route_outlined,
            onChanged: _setProtocol,
          ),
          const SizedBox(height: 12),
          ApiSingleSelectField(
            label: 'State type',
            choices: _stateTypeChoices,
            value: _stateType,
            allowEmpty: false,
            prefixIcon: Icons.swap_horiz_outlined,
            onChanged: (value) =>
                setState(() => _stateType = value ?? 'keep'),
          ),
          const SizedBox(height: 12),
          if (_interfaceChoices.isNotEmpty)
            ApiMultiSelectField(
              label: 'Interfaces',
              choices: _interfaceChoices,
              selected: _interfaces,
              prefixIcon: Icons.settings_ethernet,
              emptyText: 'Floating / all interfaces',
              helperText:
                  'Select one interface/group for a normal rule. Leave empty for a floating/global rule.',
              searchHint: 'Search interfaces and groups',
              onChanged: _setInterfaces,
            )
          else
            TextFormField(
              initialValue: _interfaces.join(','),
              decoration: const InputDecoration(
                labelText: 'Interfaces',
                hintText: 'lan, wan, group name; blank = floating/global',
              ),
              onChanged: (value) => _setInterfaces(_split(value)),
            ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Invert interface'),
            subtitle: Text(
              _interfaces.length == 1
                  ? 'Match every interface except the selected interface.'
                  : 'Available only when exactly one interface is selected.',
            ),
            value: _interfaceNot,
            onChanged: _interfaces.length == 1
                ? (value) => setState(() => _interfaceNot = value)
                : null,
          ),
          const SizedBox(height: 8),
          _section(context, 'Source'),
          const SizedBox(height: 8),
          ApiTextSelectorField(
            controller: _source,
            label: 'Network / alias',
            choices: _networkChoices,
            allowMultiple: true,
            prefixIcon: Icons.call_made_outlined,
            hintText: 'any, 192.168.1.0/24, alias_name',
            helperText:
                'Choose a network/interface address/alias or type an IP/CIDR. Multiple values are comma-separated.',
            searchHint: 'Search networks and aliases',
          ),
          const SizedBox(height: 10),
          ApiTextSelectorField(
            controller: _sourcePort,
            label: 'Port / alias / range',
            choices: _portChoices,
            enabled: _portsSupported,
            prefixIcon: Icons.numbers_outlined,
            hintText: 'https, 5060, 10000-20000, PORT_ALIAS',
            helperText: _portsSupported
                ? 'Leave blank for any port. Use a service, port alias, number or range.'
                : 'Ports only apply to TCP, UDP or TCP/UDP rules.',
            searchHint: 'Search services and port aliases',
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Invert source'),
            subtitle: const Text('Match everything except this source.'),
            value: _sourceNot,
            onChanged: (value) => setState(() => _sourceNot = value),
          ),
          const SizedBox(height: 8),
          _section(context, 'Destination'),
          const SizedBox(height: 8),
          ApiTextSelectorField(
            controller: _destination,
            label: 'Network / alias',
            choices: _networkChoices,
            allowMultiple: true,
            prefixIcon: Icons.call_received_outlined,
            hintText: 'any, WAN address, 10.0.0.0/24, alias_name',
            helperText:
                'Choose a network/interface address/alias or type an IP/CIDR. Multiple values are comma-separated.',
            searchHint: 'Search networks and aliases',
          ),
          const SizedBox(height: 10),
          ApiTextSelectorField(
            controller: _destinationPort,
            label: 'Port / alias / range',
            choices: _portChoices,
            enabled: _portsSupported,
            prefixIcon: Icons.numbers_outlined,
            hintText: 'https, 443, 5060, 10000-20000, PORT_ALIAS',
            helperText: _portsSupported
                ? 'Leave blank for any port. Use a service, port alias, number or range.'
                : 'Ports only apply to TCP, UDP or TCP/UDP rules.',
            searchHint: 'Search services and port aliases',
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Invert destination'),
            subtitle: const Text('Match everything except this destination.'),
            value: _destinationNot,
            onChanged: (value) => setState(() => _destinationNot = value),
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
                'Sentinel validates the rule with OPNsense, saves it through the Firewall model API, then calls the official firewall apply action.',
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

  static Set<String> _split(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();

  static bool _hasAnyCombination(String value) {
    final values = _split(value);
    return values.length > 1 &&
        values.any((item) => item.toLowerCase() == 'any');
  }
}
