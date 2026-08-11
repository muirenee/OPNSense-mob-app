class ApiChoice {
  const ApiChoice({
    required this.value,
    required this.label,
    this.selected = false,
  });

  final String value;
  final String label;
  final bool selected;

  ApiChoice copyWith({bool? selected, String? label}) => ApiChoice(
        value: value,
        label: label ?? this.label,
        selected: selected ?? this.selected,
      );
}

/// Parses the option-map format returned by OPNsense BaseListField fields.
///
/// OPNsense normally returns list fields as:
/// {
///   "machine-value": {"value": "Human label", "selected": 1}
/// }
///
/// The parser is intentionally defensive because a few endpoints return plain
/// lists or compact scalar maps instead.
List<ApiChoice> parseApiChoices(
  dynamic raw, {
  bool scalarValuesSelected = true,
}) {
  final output = <ApiChoice>[];

  if (raw == null) return output;

  if (raw is Map) {
    final map = Map<dynamic, dynamic>.from(raw);

    // A single list item represented as an object rather than an option map.
    if (_looksLikeChoiceObject(map)) {
      final value = _firstText(map, const ['id', 'key', 'uuid', 'name', 'value']);
      if (value.isNotEmpty) {
        output.add(
          ApiChoice(
            value: value,
            label: _firstText(
              map,
              const ['label', 'description', 'descr', 'name', 'value'],
              fallback: value,
            ),
            selected: _truthy(map['selected']) ||
                _truthy(map['checked']) ||
                _truthy(map['enabled']),
          ),
        );
      }
      return _dedupe(output);
    }

    for (final entry in map.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      final value = entry.value;
      if (value is Map) {
        final option = Map<dynamic, dynamic>.from(value);
        final label = _firstText(
          option,
          const ['value', 'label', 'name', 'description', 'descr'],
          fallback: key,
        );
        output.add(
          ApiChoice(
            value: key,
            label: label.isEmpty ? key : label,
            selected: _truthy(option['selected']) ||
                _truthy(option['checked']),
          ),
        );
      } else if (value is bool || value is num) {
        output.add(
          ApiChoice(
            value: key,
            label: key,
            selected: scalarValuesSelected && _truthy(value),
          ),
        );
      } else {
        final text = _plainText(value);
        output.add(
          ApiChoice(
            value: key,
            label: text.isEmpty ? key : text,
            selected: false,
          ),
        );
      }
    }
    return _dedupe(output);
  }

  if (raw is Iterable) {
    for (final item in raw) {
      if (item is Map) {
        final map = Map<dynamic, dynamic>.from(item);
        final value = _firstText(
          map,
          const ['id', 'key', 'uuid', 'name', 'value'],
        );
        if (value.isEmpty) continue;
        output.add(
          ApiChoice(
            value: value,
            label: _firstText(
              map,
              const ['label', 'description', 'descr', 'name', 'value'],
              fallback: value,
            ),
            selected: _truthy(map['selected']) ||
                _truthy(map['checked']) ||
                scalarValuesSelected,
          ),
        );
      } else {
        final value = _plainText(item);
        if (value.isNotEmpty) {
          output.add(
            ApiChoice(
              value: value,
              label: value,
              selected: scalarValuesSelected,
            ),
          );
        }
      }
    }
    return _dedupe(output);
  }

  final text = _plainText(raw);
  if (text.isEmpty) return output;
  for (final item in text.split(',')) {
    final value = item.trim();
    if (value.isNotEmpty) {
      output.add(
        ApiChoice(
          value: value,
          label: value,
          selected: scalarValuesSelected,
        ),
      );
    }
  }
  return _dedupe(output);
}

Set<String> selectedApiChoiceValues(dynamic raw) => parseApiChoices(raw)
    .where((choice) => choice.selected)
    .map((choice) => choice.value)
    .toSet();

String encodeApiChoiceValues(Iterable<String> values) {
  final cleaned = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  return cleaned.join(',');
}

String apiChoiceDisplayText(dynamic raw, {String separator = ', '}) {
  final choices = parseApiChoices(raw);
  if (choices.isEmpty) return _plainText(raw);
  final selected = choices.where((choice) => choice.selected).toList();
  if (selected.isNotEmpty) {
    return selected.map((choice) => choice.label).join(separator);
  }

  // Plain scalar/list values represent selected values, while an OPNsense
  // option map with no selected entries represents an empty selection.
  if (raw is Map) return '';
  return choices.map((choice) => choice.label).join(separator);
}

List<ApiChoice> mergeApiChoices(
  Iterable<ApiChoice> choices,
  Iterable<String> selectedValues, {
  Map<String, String> fallbackLabels = const {},
}) {
  final selected = selectedValues.map((value) => value.trim()).toSet();
  final result = <ApiChoice>[];
  final seen = <String>{};
  for (final choice in choices) {
    if (!seen.add(choice.value)) continue;
    result.add(choice.copyWith(selected: selected.contains(choice.value)));
  }
  for (final value in selected) {
    if (value.isEmpty || !seen.add(value)) continue;
    result.add(
      ApiChoice(
        value: value,
        label: fallbackLabels[value] ?? value,
        selected: true,
      ),
    );
  }
  result.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return result;
}

bool _looksLikeChoiceObject(Map<dynamic, dynamic> map) {
  if (map.containsKey('selected') && map.containsKey('value')) return true;
  if (map.containsKey('id') &&
      (map.containsKey('label') || map.containsKey('name'))) {
    return true;
  }
  return false;
}

List<ApiChoice> _dedupe(List<ApiChoice> input) {
  final output = <ApiChoice>[];
  final seen = <String>{};
  for (final choice in input) {
    if (choice.value.isEmpty || !seen.add(choice.value)) continue;
    output.add(choice);
  }
  output.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return output;
}

String _firstText(
  Map<dynamic, dynamic> map,
  Iterable<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final text = _plainText(map[key]);
    if (text.isNotEmpty && text != 'true' && text != 'false') return text;
  }
  return fallback;
}

String _plainText(dynamic value) {
  if (value == null) return '';
  if (value is String || value is num) return value.toString().trim();
  if (value is bool) return value ? 'true' : 'false';
  if (value is Iterable) {
    return value.map(_plainText).where((text) => text.isNotEmpty).join(', ');
  }
  return '';
}

bool _truthy(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return const {'1', 'true', 'yes', 'on', 'enabled', 'selected'}.contains(text);
}
