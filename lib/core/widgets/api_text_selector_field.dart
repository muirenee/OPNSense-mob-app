import 'package:flutter/material.dart';

import '../api/api_choice.dart';

/// Editable text field with a searchable OPNsense-style selector.
///
/// Network and port fields in OPNsense deliberately support both known
/// aliases/special values and manual values (IP/CIDR, numeric ports or ranges).
/// A plain dropdown would remove that flexibility, so this widget keeps the
/// text editor while exposing the known choices from a picker.
class ApiTextSelectorField extends StatelessWidget {
  const ApiTextSelectorField({
    super.key,
    required this.controller,
    required this.label,
    required this.choices,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.allowMultiple = false,
    this.searchHint = 'Search options',
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final List<ApiChoice> choices;
  final String? hintText;
  final String? helperText;
  final IconData? prefixIcon;
  final bool allowMultiple;
  final String searchHint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: choices.isEmpty
            ? null
            : IconButton(
                tooltip: 'Select $label',
                icon: const Icon(Icons.arrow_drop_down),
                onPressed: enabled ? () => _openPicker(context) : null,
              ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    if (choices.isEmpty) return;
    final search = TextEditingController();
    final working = _currentValues();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final query = search.text.trim().toLowerCase();
          final filtered = choices.where((choice) {
            return query.isEmpty ||
                choice.label.toLowerCase().contains(query) ||
                choice.value.toLowerCase().contains(query);
          }).toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (allowMultiple)
                          TextButton(
                            onPressed: () {
                              working.clear();
                              setModalState(() {});
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      allowMultiple
                          ? 'Select one or more known values, or close this picker and type a custom value.'
                          : 'Choose a known value, or close this picker and type a custom value.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: search,
                      autofocus: choices.length > 8,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: searchHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No matching options.'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final choice = filtered[index];
                                if (!allowMultiple) {
                                  return ListTile(
                                    leading: const Icon(Icons.list_alt_outlined),
                                    title: Text(choice.label),
                                    subtitle: choice.label == choice.value
                                        ? null
                                        : Text(choice.value),
                                    onTap: () => Navigator.pop(
                                      context,
                                      <String>{choice.value},
                                    ),
                                  );
                                }
                                final checked = working.contains(choice.value);
                                return CheckboxListTile(
                                  value: checked,
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(choice.label),
                                  subtitle: choice.label == choice.value
                                      ? null
                                      : Text(choice.value),
                                  onChanged: (selected) {
                                    if (selected == true) {
                                      working.add(choice.value);
                                    } else {
                                      working.remove(choice.value);
                                    }
                                    setModalState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                    if (allowMultiple) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(
                            context,
                            Set<String>.from(working),
                          ),
                          icon: const Icon(Icons.check),
                          label: Text('Apply ${working.length} selected'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    search.dispose();
    if (result == null) return;
    final values = result.where((value) => value.trim().isNotEmpty).toList();
    if (allowMultiple) values.sort();
    controller.text = values.join(',');
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
  }

  Set<String> _currentValues() {
    if (!allowMultiple) {
      final value = controller.text.trim();
      return value.isEmpty ? <String>{} : <String>{value};
    }
    return controller.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
  }
}
