import 'package:flutter/material.dart';

import '../../../core/api/api_choice.dart';
import '../../audit/audit_repository.dart';
import 'alias_models.dart';
import 'alias_repository.dart';

class AliasEditor extends StatefulWidget {
  const AliasEditor({
    super.key,
    required this.repository,
    required this.audit,
    this.alias,
    this.initial = const <String, dynamic>{},
  });

  final AliasRepository repository;
  final AuditRepository audit;
  final FirewallAliasSummary? alias;
  final Map<String, dynamic> initial;

  @override
  State<AliasEditor> createState() => _AliasEditorState();
}

class _AliasEditorState extends State<AliasEditor> {
  late final TextEditingController _name;
  late final TextEditingController _content;
  late final TextEditingController _description;
  String _type = 'host';
  bool _enabled = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: _plainValue(widget.initial['name'], widget.alias?.name ?? ''),
    );
    _content = TextEditingController(
      text: _contentValue(
        widget.initial['content'],
        widget.alias?.content ?? '',
      ),
    );
    _description = TextEditingController(
      text: _plainValue(
        widget.initial['description'],
        widget.alias?.description ?? '',
      ),
    );
    _type = _selectedValue(
      widget.initial['type'],
      widget.alias?.type ?? 'host',
    ).toLowerCase();
    if (!const {
      'host',
      'network',
      'port',
      'mac',
      'asn',
      'networkgroup',
    }.contains(_type)) {
      _type = 'host';
    }
    _enabled = _selectedBool(
      widget.initial['enabled'],
      widget.alias?.enabled ?? true,
    );
  }

  static String _plainValue(dynamic raw, String fallback) {
    if (raw is String || raw is num) {
      final text = raw.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static String _selectedValue(dynamic raw, String fallback) {
    if (raw is Map || raw is Iterable) {
      final selected = parseApiChoices(raw)
          .where((choice) => choice.selected)
          .toList();
      if (selected.length == 1) return selected.single.value;
    }
    return _plainValue(raw, fallback);
  }

  static String _contentValue(dynamic raw, String fallback) {
    if (raw is Map || raw is Iterable) {
      final selected = parseApiChoices(raw)
          .where((choice) => choice.selected)
          .map((choice) => choice.value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (selected.isNotEmpty) return selected.join('\n');
    }
    return _plainValue(raw, fallback);
  }

  static bool _selectedBool(dynamic raw, bool fallback) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is Map || raw is Iterable) {
      final selected = parseApiChoices(raw)
          .where((choice) => choice.selected)
          .map((choice) => choice.value.toLowerCase())
          .toSet();
      if (selected.contains('1') || selected.contains('true')) return true;
      if (selected.contains('0') || selected.contains('false')) return false;
    }
    final text = raw?.toString().trim().toLowerCase() ?? '';
    if (const {'1', 'true', 'yes', 'on', 'enabled'}.contains(text)) return true;
    if (const {'0', 'false', 'no', 'off', 'disabled'}.contains(text)) {
      return false;
    }
    return fallback;
  }

  @override
  void dispose() {
    _name.dispose();
    _content.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _content.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alias name and content are required.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.save(
        uuid: widget.alias?.uuid,
        values: {
          'enabled': _enabled ? '1' : '0',
          'name': _name.text.trim(),
          'type': _type,
          'content': _content.text.trim(),
          'description': _description.text.trim(),
        },
      );
      try {
        await widget.audit.record(
          action: widget.alias == null ? 'Add alias' : 'Edit alias',
          target: _name.text.trim(),
          result: 'success',
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save alias: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.alias != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit alias' : 'Add alias')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Alias name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: 'host', child: Text('Host(s)')),
              DropdownMenuItem(value: 'network', child: Text('Network(s)')),
              DropdownMenuItem(value: 'port', child: Text('Port(s)')),
              DropdownMenuItem(value: 'mac', child: Text('MAC address')),
              DropdownMenuItem(value: 'asn', child: Text('BGP ASN')),
              DropdownMenuItem(
                value: 'networkgroup',
                child: Text('Network group'),
              ),
            ],
            onChanged: (value) => setState(() => _type = value ?? 'host'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Content',
              hintText: 'One address, network, port/range or alias member per line',
              helperText: 'OPNsense alias content is newline-separated. Existing option-map values are converted back to normal entries.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
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
            label: Text(editing ? 'Save alias' : 'Add alias'),
          ),
        ],
      ),
    );
  }
}
