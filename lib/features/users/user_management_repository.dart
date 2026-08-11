import '../../core/api/api_choice.dart';
import '../../core/api/opnsense_api_client.dart';
import 'user_management_models.dart';

class UserManagementRepository {
  UserManagementRepository(this.api);

  final OpnSenseApiClient api;

  Future<List<FirewallUserSummary>> loadUsers({String search = ''}) async {
    final raw = await api.getData(
      '/api/auth/user/search',
      queryParameters: {
        'current': 1,
        'rowCount': 500,
        if (search.trim().isNotEmpty) 'searchPhrase': search.trim(),
      },
    );
    return parseUsers(raw);
  }

  Future<List<FirewallGroupSummary>> loadGroups({String search = ''}) async {
    final raw = await api.getData(
      '/api/auth/group/search',
      queryParameters: {
        'current': 1,
        'rowCount': 500,
        if (search.trim().isNotEmpty) 'searchPhrase': search.trim(),
      },
    );
    return parseGroups(raw);
  }

  /// Fetch an existing user or, with no UUID, OPNsense's default user model.
  /// The default model includes the valid choices for groups, privileges,
  /// shells and languages, which lets the UI render proper selectors.
  Future<Map<String, dynamic>> getUser([String? uuid]) async {
    final suffix = uuid == null || uuid.isEmpty
        ? ''
        : '/${Uri.encodeComponent(uuid)}';
    final raw = await api.getData('/api/auth/user/get$suffix');
    return _extractModel(raw, 'user');
  }

  /// Fetch an existing group or, with no UUID, the default group model with
  /// valid member and privilege choices.
  Future<Map<String, dynamic>> getGroup([String? uuid]) async {
    final suffix = uuid == null || uuid.isEmpty
        ? ''
        : '/${Uri.encodeComponent(uuid)}';
    final raw = await api.getData('/api/auth/group/get$suffix');
    return _extractModel(raw, 'group');
  }

  Future<String> saveUser({
    String? uuid,
    required Map<String, dynamic> values,
  }) async {
    final raw = await api.postData(
      uuid == null || uuid.isEmpty
          ? '/api/auth/user/add'
          : '/api/auth/user/set/${Uri.encodeComponent(uuid)}',
      data: {'user': values},
    );
    _ensureSuccess(raw, 'Save user');
    return _uuidFrom(raw);
  }

  Future<String> saveGroup({
    String? uuid,
    required Map<String, dynamic> values,
  }) async {
    final raw = await api.postData(
      uuid == null || uuid.isEmpty
          ? '/api/auth/group/add'
          : '/api/auth/group/set/${Uri.encodeComponent(uuid)}',
      data: {'group': values},
    );
    _ensureSuccess(raw, 'Save group');
    return _uuidFrom(raw);
  }

  Future<void> deleteUser(String uuid) async {
    final raw = await api.postData(
      '/api/auth/user/del/${Uri.encodeComponent(uuid)}',
    );
    _ensureSuccess(raw, 'Delete user');
  }

  Future<void> deleteGroup(String uuid) async {
    final raw = await api.postData(
      '/api/auth/group/del/${Uri.encodeComponent(uuid)}',
    );
    _ensureSuccess(raw, 'Delete group');
  }

  Future<GeneratedApiKey> generateApiKey(String username) async {
    final raw = await api.postData(
      '/api/auth/user/add_api_key/${Uri.encodeComponent(username)}',
    );
    final map = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final result = map['result'];
    Map<String, dynamic> payload = map;
    if (result is Map) payload = Map<String, dynamic>.from(result);

    final key = _first(
      payload,
      const ['key', 'api_key', 'apikey', 'username'],
    );
    final secret = _first(
      payload,
      const ['secret', 'api_secret', 'password'],
    );
    final hostname = _first(map, const ['hostname', 'host']);
    if (key.isEmpty || secret.isEmpty) {
      throw StateError('The firewall did not return a new API key and secret.');
    }
    return GeneratedApiKey(key: key, secret: secret, hostname: hostname);
  }

  static List<ApiChoice> choices(Map<String, dynamic> model, String field) {
    return parseApiChoices(model[field], scalarValuesSelected: false);
  }

  static Set<String> selectedChoices(
    Map<String, dynamic> model,
    String field,
  ) {
    return parseApiChoices(model[field])
        .where((choice) => choice.selected)
        .map((choice) => choice.value)
        .toSet();
  }

  static String encodeChoices(Iterable<String> values) =>
      encodeApiChoiceValues(values);

  static List<FirewallUserSummary> parseUsers(dynamic raw) {
    return _rows(raw).map((row) {
      return FirewallUserSummary(
        uuid: _first(row, const ['uuid', 'id']),
        name: _first(row, const ['name', 'username', 'user']),
        description: _first(
          row,
          const ['descr', 'description', 'full_name'],
        ),
        email: _first(row, const ['email']),
        scope: _first(row, const ['scope'], fallback: 'user'),
        disabled: _truthy(row['disabled']),
        isAdmin: _truthy(row['is_admin']) ||
            _truthy(row['admin']) ||
            apiChoiceDisplayText(row['priv']).contains('page-all'),
        comment: _first(row, const ['comment']),
      );
    }).where((item) => item.name.isNotEmpty).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static List<FirewallGroupSummary> parseGroups(dynamic raw) {
    return _rows(raw).map((row) {
      return FirewallGroupSummary(
        uuid: _first(row, const ['uuid', 'id']),
        name: _first(row, const ['name', 'groupname', 'group']),
        description: _first(row, const ['description', 'descr']),
        scope: _first(row, const ['scope'], fallback: 'user'),
        member: apiChoiceDisplayText(row['member'] ?? row['members']),
        privileges: apiChoiceDisplayText(row['priv'] ?? row['privileges']),
        sourceNetworks: _text(row['source_networks']),
      );
    }).where((item) => item.name.isNotEmpty).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static Map<String, dynamic> _extractModel(dynamic raw, String key) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    final model = map[key];
    if (model is Map) return Map<String, dynamic>.from(model);
    return map;
  }

  static List<Map<String, dynamic>> _rows(dynamic raw) {
    dynamic candidate = raw;
    if (raw is Map) {
      candidate = raw['rows'] ?? raw['items'] ?? raw['data'] ?? raw;
    }
    final rows = <Map<String, dynamic>>[];
    if (candidate is List) {
      for (final item in candidate) {
        if (item is Map) rows.add(Map<String, dynamic>.from(item));
      }
    } else if (candidate is Map) {
      for (final entry in candidate.entries) {
        if (entry.value is Map) {
          final row = Map<String, dynamic>.from(entry.value as Map);
          row.putIfAbsent('uuid', () => entry.key.toString());
          rows.add(row);
        }
      }
    }
    return rows;
  }

  static String _uuidFrom(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final uuid = _first(map, const ['uuid', 'id']);
      if (uuid.isNotEmpty) return uuid;
      final result = map['result'];
      if (result is Map) {
        return _first(
          Map<String, dynamic>.from(result),
          const ['uuid', 'id'],
        );
      }
    }
    return '';
  }

  static String _first(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = _text(map[key]);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    if (value is String || value is num) return value.toString().trim();
    if (value is bool) return value ? '1' : '0';
    if (value is Iterable) {
      return value.map(_text).where((e) => e.isNotEmpty).join(', ');
    }
    if (value is Map) return apiChoiceDisplayText(value);
    return '';
  }

  static bool _truthy(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase() ?? '';
    return const {'1', 'true', 'yes', 'on', 'enabled'}.contains(text);
  }

  static void _ensureSuccess(dynamic raw, String operation) {
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    final result = map['result']?.toString().trim().toLowerCase();
    final status = map['status']?.toString().trim().toLowerCase();
    if (result == 'failed' || status == 'failed' || status == 'error') {
      final validations = map['validations'] ?? map['validation'];
      if (validations is Map && validations.isNotEmpty) {
        final details = validations.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join(' · ');
        throw StateError('$operation failed: $details');
      }
      final detail = _first(map, const ['message', 'error']);
      throw StateError(
        detail.isEmpty ? '$operation failed.' : '$operation failed: $detail',
      );
    }
  }
}
