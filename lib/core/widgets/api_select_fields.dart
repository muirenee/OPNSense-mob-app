import 'package:flutter/material.dart';

import '../api/api_choice.dart';

class ApiSingleSelectField extends StatelessWidget {
  const ApiSingleSelectField({
    super.key,
    required this.label,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.prefixIcon,
    this.enabled = true,
    this.helperText,
    this.allowEmpty = true,
    this.emptyLabel = 'None',
  });

  final String label;
  final List<ApiChoice> choices;
  final String? value;
  final ValueChanged<String?> onChanged;
  final IconData? prefixIcon;
  final bool enabled;
  final String? helperText;
  final bool allowEmpty;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final unique = <String, ApiChoice>{
      for (final choice in choices)
        if (choice.value.isNotEmpty) choice.value: choice,
    };
    final current = value != null && unique.containsKey(value) ? value! : '';
    final items = <DropdownMenuItem<String>>[
      if (allowEmpty)
        DropdownMenuItem<String>(
          value: '',
          child: Text(emptyLabel),
        ),
      ...unique.values.map(
        (choice) => DropdownMenuItem<String>(
          value: choice.value,
          child: Text(choice.label, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];
    final effectiveCurrent = current.isEmpty && !allowEmpty ? null : current;
    return DropdownButtonFormField<String>(
      initialValue: effectiveCurrent,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
      items: items,
      onChanged: enabled
          ? (selected) => onChanged(
                selected == null || selected.isEmpty ? null : selected,
              )
          : null,
    );
  }
}

class ApiMultiSelectField extends StatelessWidget {
  const ApiMultiSelectField({
    super.key,
    required this.label,
    required this.choices,
    required this.selected,
    required this.onChanged,
    this.prefixIcon,
    this.helperText,
    this.emptyText = 'None selected',
    this.searchHint = 'Search options',
    this.enabled = true,
  });

  final String label;
  final List<ApiChoice> choices;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final IconData? prefixIcon;
  final String? helperText;
  final String emptyText;
  final String searchHint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final byValue = <String, ApiChoice>{
      for (final choice in choices) choice.value: choice,
    };
    final selectedChoices = selected
        .map(
          (value) => byValue[value] ??
              ApiChoice(value: value, label: value, selected: true),
        )
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? () => _openPicker(context) : null,
      child: InputDecorator(
        isEmpty: selectedChoices.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          enabled: enabled,
        ),
        child: selectedChoices.isEmpty
            ? Text(
                emptyText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final choice in selectedChoices.take(4))
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(choice.label),
                    ),
                  if (selectedChoices.length > 4)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('+${selectedChoices.length - 4} more'),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final working = Set<String>.from(selected);
    final search = TextEditingController();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
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
                          TextButton(
                            onPressed: () {
                              working.clear();
                              setModalState(() {});
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                      Text(
                        '${working.length} selected · ${filtered.length} shown',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('No matching options.'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final choice = filtered[index];
                                  final checked = working.contains(choice.value);
                                  return CheckboxListTile(
                                    value: checked,
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(choice.label),
                                    subtitle: choice.label == choice.value
                                        ? null
                                        : Text(
                                            choice.value,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                    onChanged: (value) {
                                      if (value == true) {
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
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              Navigator.pop(context, Set<String>.from(working)),
                          icon: const Icon(Icons.check),
                          label: const Text('Apply selection'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    search.dispose();
    if (result != null) onChanged(result);
  }
}
