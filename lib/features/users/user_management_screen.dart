import 'package:flutter/material.dart';

import '../../core/api/api_choice.dart';
import '../../core/api/opnsense_api_client.dart';
import '../../core/widgets/api_select_fields.dart';
import '../audit/audit_repository.dart';
import '../profiles/firewall_profile.dart';
import 'user_management_models.dart';
import 'user_management_repository.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({
    super.key,
    required this.profile,
    required this.credentials,
  });

  final FirewallProfile profile;
  final FirewallCredentials credentials;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late final UserManagementRepository _repository;
  late final AuditRepository _audit;
  late Future<List<FirewallUserSummary>> _users;
  late Future<List<FirewallGroupSummary>> _groups;
  final _userSearch = TextEditingController();
  final _groupSearch = TextEditingController();
  String _userFilter = 'all';

  @override
  void initState() {
    super.initState();
    _repository = UserManagementRepository(
      OpnSenseApiClient(
        profile: widget.profile,
        credentials: widget.credentials,
      ),
    );
    _audit = AuditRepository(profileId: widget.profile.id);
    _reload();
  }

  @override
  void dispose() {
    _userSearch.dispose();
    _groupSearch.dispose();
    super.dispose();
  }

  void _reload() {
    _users = _repository.loadUsers();
    _groups = _repository.loadGroups();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait<dynamic>([_users, _groups]);
  }

  Future<void> _openUser([FirewallUserSummary? user]) async {
    Map<String, dynamic> initial = <String, dynamic>{};
    try {
      initial = await _repository.getUser(user?.uuid);
    } catch (error) {
      if (user != null) {
        _show('Advanced user options could not be loaded: $error');
      }
    }
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _UserEditorScreen(
          repository: _repository,
          audit: _audit,
          user: user,
          initial: initial,
        ),
      ),
    );
    if (changed == true) await _refresh();
  }

  Future<void> _openGroup([FirewallGroupSummary? group]) async {
    Map<String, dynamic> initial = <String, dynamic>{};
    try {
      initial = await _repository.getGroup(group?.uuid);
    } catch (error) {
      if (group != null) {
        _show('Advanced group options could not be loaded: $error');
      }
    }
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _GroupEditorScreen(
          repository: _repository,
          audit: _audit,
          group: group,
          initial: initial,
        ),
      ),
    );
    if (changed == true) await _refresh();
  }

  Future<void> _deleteUser(FirewallUserSummary user) async {
    if (user.isSystem) {
      _show('System users cannot be deleted from Sentinel.');
      return;
    }
    if (!await _confirm(
      title: 'Delete user?',
      text: 'Delete ${user.name}? Authentication and API access may be affected.',
      action: 'Delete',
    )) {
      return;
    }
    try {
      await _repository.deleteUser(user.uuid);
      await _auditSafe('Delete user', user.name, 'success');
      await _refresh();
    } catch (error) {
      await _auditSafe('Delete user', user.name, 'failed', error.toString());
      _show('Unable to delete user: $error');
    }
  }

  Future<void> _deleteGroup(FirewallGroupSummary group) async {
    if (group.isSystem) {
      _show('System groups cannot be deleted from Sentinel.');
      return;
    }
    if (!await _confirm(
      title: 'Delete group?',
      text: 'Delete ${group.name}? Users may lose privileges inherited from this group.',
      action: 'Delete',
    )) {
      return;
    }
    try {
      await _repository.deleteGroup(group.uuid);
      await _auditSafe('Delete group', group.name, 'success');
      await _refresh();
    } catch (error) {
      await _auditSafe('Delete group', group.name, 'failed', error.toString());
      _show('Unable to delete group: $error');
    }
  }

  Future<void> _generateKey(FirewallUserSummary user) async {
    if (!await _confirm(
      title: 'Generate API key?',
      text: 'Generate a new API key for ${user.name}? The secret is displayed only once.',
      action: 'Generate',
    )) {
      return;
    }
    try {
      final key = await _repository.generateApiKey(user.name);
      await _auditSafe('Generate API key', user.name, 'success');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New API credentials'),
          content: SelectableText(
            '${key.hostname.isEmpty ? '' : 'Host: ${key.hostname}\n\n'}'
            'API key:\n${key.key}\n\n'
            'API secret:\n${key.secret}\n\n'
            'Copy these now. The API secret cannot be retrieved later.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      await _auditSafe(
        'Generate API key',
        user.name,
        'failed',
        error.toString(),
      );
      _show('Unable to generate API key: $error');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String text,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _auditSafe(
    String action,
    String target,
    String result, [
    String details = '',
  ]) async {
    try {
      await _audit.record(
        action: action,
        target: target,
        result: result,
        details: details,
      );
    } catch (_) {}
  }

  void _show(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Users & Groups'),
          actions: [
            IconButton(
              onPressed: _refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'Users'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Groups'),
            ],
          ),
        ),
        body: TabBarView(children: [_usersTab(), _groupsTab()]),
      ),
    );
  }

  Widget _usersTab() {
    return FutureBuilder<List<FirewallUserSummary>>(
      future: _users,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorPane(
            title: 'Users unavailable',
            error: snapshot.error,
            onRetry: _refresh,
          );
        }
        final all = snapshot.data ?? const <FirewallUserSummary>[];
        final query = _userSearch.text.trim().toLowerCase();
        final users = all.where((user) {
          if (_userFilter == 'enabled' && user.disabled) return false;
          if (_userFilter == 'disabled' && !user.disabled) return false;
          if (_userFilter == 'admin' && !user.isAdmin) return false;
          return query.isEmpty ||
              user.name.toLowerCase().contains(query) ||
              user.description.toLowerCase().contains(query) ||
              user.email.toLowerCase().contains(query);
        }).toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _Header(
                title: 'Firewall users',
                subtitle: '${users.length} of ${all.length} shown',
                onAdd: () => _openUser(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _userSearch,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search username, name or email',
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in const {
                    'all': 'All',
                    'enabled': 'Enabled',
                    'disabled': 'Disabled',
                    'admin': 'Admins',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _userFilter == entry.key,
                      onSelected: (_) => setState(() => _userFilter = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              for (final user in users) ...[
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        user.isAdmin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.person_outline,
                      ),
                    ),
                    title: Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user.description.isNotEmpty) Text(user.description),
                        if (user.email.isNotEmpty) Text(user.email),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _StatusChip(
                              label: user.disabled ? 'Disabled' : 'Enabled',
                              tone: user.disabled ? Colors.orange : Colors.green,
                            ),
                            if (user.isAdmin)
                              _StatusChip(
                                label: 'Admin',
                                tone: Theme.of(context).colorScheme.primary,
                              ),
                            if (user.isSystem)
                              _StatusChip(
                                label: 'System',
                                tone: Theme.of(context).colorScheme.outline,
                              ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => _openUser(user),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _openUser(user);
                        if (value == 'key') _generateKey(user);
                        if (value == 'delete') _deleteUser(user);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                          value: 'key',
                          child: Text('Generate API key'),
                        ),
                        if (!user.isSystem)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (users.isEmpty)
                const _EmptyCard(text: 'No users match the selected filters.'),
            ],
          ),
        );
      },
    );
  }

  Widget _groupsTab() {
    return FutureBuilder<List<FirewallGroupSummary>>(
      future: _groups,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorPane(
            title: 'Groups unavailable',
            error: snapshot.error,
            onRetry: _refresh,
          );
        }
        final all = snapshot.data ?? const <FirewallGroupSummary>[];
        final query = _groupSearch.text.trim().toLowerCase();
        final groups = all.where((group) {
          return query.isEmpty ||
              group.name.toLowerCase().contains(query) ||
              group.description.toLowerCase().contains(query) ||
              group.member.toLowerCase().contains(query) ||
              group.privileges.toLowerCase().contains(query);
        }).toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _Header(
                title: 'Firewall groups',
                subtitle: '${groups.length} of ${all.length} shown',
                onAdd: () => _openGroup(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _groupSearch,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search groups, members or rights',
                ),
              ),
              const SizedBox(height: 14),
              for (final group in groups) ...[
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                    title: Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (group.description.isNotEmpty) Text(group.description),
                        if (group.member.isNotEmpty) Text('Members: ${group.member}'),
                        if (group.privileges.isNotEmpty)
                          Text(
                            'Rights: ${group.privileges}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    onTap: () => _openGroup(group),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _openGroup(group);
                        if (value == 'delete') _deleteGroup(group);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (!group.isSystem)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (groups.isEmpty) const _EmptyCard(text: 'No groups match the search.'),
            ],
          ),
        );
      },
    );
  }
}

class _UserEditorScreen extends StatefulWidget {
  const _UserEditorScreen({
    required this.repository,
    required this.audit,
    required this.initial,
    this.user,
  });

  final UserManagementRepository repository;
  final AuditRepository audit;
  final Map<String, dynamic> initial;
  final FirewallUserSummary? user;

  @override
  State<_UserEditorScreen> createState() => _UserEditorScreenState();
}

class _UserEditorScreenState extends State<_UserEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _email;
  late final TextEditingController _comment;
  late final TextEditingController _password;
  late final TextEditingController _landingPage;
  late final List<ApiChoice> _groupChoices;
  late final List<ApiChoice> _privilegeChoices;
  late final List<ApiChoice> _shellChoices;
  late final List<ApiChoice> _languageChoices;
  late Set<String> _groups;
  late Set<String> _privileges;
  String? _shell;
  String? _language;
  bool _disabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: _scalar(widget.initial['name'], widget.user?.name ?? ''),
    );
    _description = TextEditingController(
      text: _scalar(
        widget.initial['descr'] ?? widget.initial['description'],
        widget.user?.description ?? '',
      ),
    );
    _email = TextEditingController(
      text: _scalar(widget.initial['email'], widget.user?.email ?? ''),
    );
    _comment = TextEditingController(
      text: _scalar(widget.initial['comment'], widget.user?.comment ?? ''),
    );
    _password = TextEditingController();
    _landingPage = TextEditingController(
      text: _scalar(widget.initial['landing_page'], ''),
    );
    _disabled = _bool(
      widget.initial['disabled'],
      widget.user?.disabled ?? false,
    );

    _groupChoices = UserManagementRepository.choices(
      widget.initial,
      'group_memberships',
    );
    _groups = UserManagementRepository.selectedChoices(
      widget.initial,
      'group_memberships',
    );
    _privilegeChoices = UserManagementRepository.choices(widget.initial, 'priv');
    _privileges = UserManagementRepository.selectedChoices(widget.initial, 'priv');
    _shellChoices = UserManagementRepository.choices(widget.initial, 'shell');
    _languageChoices = UserManagementRepository.choices(widget.initial, 'language');
    _shell = _selectedOne(widget.initial['shell']);
    _language = _selectedOne(widget.initial['language']);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _email.dispose();
    _comment.dispose();
    _password.dispose();
    _landingPage.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _show('Username is required.');
      return;
    }
    if (widget.user == null && _password.text.isEmpty) {
      _show('Password is required for a new local user.');
      return;
    }

    setState(() => _busy = true);
    final values = <String, dynamic>{
      'name': _name.text.trim(),
      'descr': _description.text.trim(),
      'email': _email.text.trim(),
      'comment': _comment.text.trim(),
      'disabled': _disabled ? '1' : '0',
      'scope': _scalar(
        widget.initial['scope'],
        widget.user?.scope ?? 'user',
      ),
      'group_memberships': UserManagementRepository.encodeChoices(_groups),
      'priv': UserManagementRepository.encodeChoices(_privileges),
    };
    if (_password.text.isNotEmpty) values['password'] = _password.text;
    if (_shell != null) values['shell'] = _shell;
    if (_language != null) values['language'] = _language;
    if (_landingPage.text.trim().isNotEmpty || widget.initial.containsKey('landing_page')) {
      values['landing_page'] = _landingPage.text.trim();
    }

    try {
      await widget.repository.saveUser(uuid: widget.user?.uuid, values: values);
      try {
        await widget.audit.record(
          action: widget.user == null ? 'Add user' : 'Edit user',
          target: _name.text.trim(),
          result: 'success',
          details: '${_groups.length} groups · ${_privileges.length} direct rights',
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _show('Unable to save user: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.user != null;
    final systemUser = widget.user?.isSystem ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit user' : 'Add user')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EditorSection(
            title: 'Account',
            icon: Icons.person_outline,
            children: [
              TextField(
                controller: _name,
                enabled: !editing || !systemUser,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Full name / description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _comment,
                decoration: const InputDecoration(labelText: 'Comment'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: editing
                      ? 'New password (leave blank to keep current)'
                      : 'Password',
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _disabled,
                onChanged: (value) => setState(() => _disabled = value),
                title: const Text('Disabled'),
                subtitle: const Text('Disabled users cannot authenticate.'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _EditorSection(
            title: 'Membership & access',
            icon: Icons.admin_panel_settings_outlined,
            children: [
              ApiMultiSelectField(
                label: 'Groups',
                choices: _groupChoices,
                selected: _groups,
                prefixIcon: Icons.groups_outlined,
                helperText: 'Select the firewall groups this user belongs to.',
                searchHint: 'Search groups',
                onChanged: (values) => setState(() => _groups = values),
              ),
              const SizedBox(height: 12),
              ApiMultiSelectField(
                label: 'Direct access rights',
                choices: _privilegeChoices,
                selected: _privileges,
                prefixIcon: Icons.policy_outlined,
                helperText: 'Direct user privileges. Group rights are inherited separately.',
                searchHint: 'Search access rights',
                onChanged: (values) => setState(() => _privileges = values),
              ),
            ],
          ),
          if (_shellChoices.isNotEmpty ||
              _languageChoices.isNotEmpty ||
              widget.initial.containsKey('landing_page')) ...[
            const SizedBox(height: 14),
            _EditorSection(
              title: 'Advanced',
              icon: Icons.tune,
              children: [
                if (_shellChoices.isNotEmpty) ...[
                  ApiSingleSelectField(
                    label: 'Login shell',
                    choices: _shellChoices,
                    value: _shell,
                    onChanged: (value) => setState(() => _shell = value),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_languageChoices.isNotEmpty) ...[
                  ApiSingleSelectField(
                    label: 'Language',
                    choices: _languageChoices,
                    value: _language,
                    onChanged: (value) => setState(() => _language = value),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.initial.containsKey('landing_page'))
                  TextField(
                    controller: _landingPage,
                    decoration: const InputDecoration(labelText: 'Landing page'),
                  ),
              ],
            ),
          ],
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
            label: Text(editing ? 'Save changes' : 'Add user'),
          ),
        ],
      ),
    );
  }
}

class _GroupEditorScreen extends StatefulWidget {
  const _GroupEditorScreen({
    required this.repository,
    required this.audit,
    required this.initial,
    this.group,
  });

  final UserManagementRepository repository;
  final AuditRepository audit;
  final Map<String, dynamic> initial;
  final FirewallGroupSummary? group;

  @override
  State<_GroupEditorScreen> createState() => _GroupEditorScreenState();
}

class _GroupEditorScreenState extends State<_GroupEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _sourceNetworks;
  late final List<ApiChoice> _memberChoices;
  late final List<ApiChoice> _privilegeChoices;
  late Set<String> _members;
  late Set<String> _privileges;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: _scalar(widget.initial['name'], widget.group?.name ?? ''),
    );
    _description = TextEditingController(
      text: _scalar(
        widget.initial['description'] ?? widget.initial['descr'],
        widget.group?.description ?? '',
      ),
    );
    _sourceNetworks = TextEditingController(
      text: _scalar(
        widget.initial['source_networks'] ?? widget.initial['sourceNetworks'],
        widget.group?.sourceNetworks ?? '',
      ),
    );
    _memberChoices = UserManagementRepository.choices(widget.initial, 'member');
    _members = UserManagementRepository.selectedChoices(widget.initial, 'member');
    _privilegeChoices = UserManagementRepository.choices(widget.initial, 'priv');
    _privileges = UserManagementRepository.selectedChoices(widget.initial, 'priv');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _sourceNetworks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _show('Group name is required.');
      return;
    }
    setState(() => _busy = true);
    final values = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'source_networks': _sourceNetworks.text.trim(),
      'scope': _scalar(widget.initial['scope'], widget.group?.scope ?? 'user'),
      'member': UserManagementRepository.encodeChoices(_members),
      'priv': UserManagementRepository.encodeChoices(_privileges),
    };
    try {
      await widget.repository.saveGroup(uuid: widget.group?.uuid, values: values);
      try {
        await widget.audit.record(
          action: widget.group == null ? 'Add group' : 'Edit group',
          target: _name.text.trim(),
          result: 'success',
          details: '${_members.length} members · ${_privileges.length} access rights',
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      _show('Unable to save group: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.group != null;
    final systemGroup = widget.group?.isSystem ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit group' : 'Add group')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EditorSection(
            title: 'Group',
            icon: Icons.groups_outlined,
            children: [
              TextField(
                controller: _name,
                enabled: !editing || !systemGroup,
                decoration: const InputDecoration(labelText: 'Group name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sourceNetworks,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Source networks',
                  hintText: 'Optional network restrictions',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _EditorSection(
            title: 'Members & access rights',
            icon: Icons.policy_outlined,
            children: [
              ApiMultiSelectField(
                label: 'Members',
                choices: _memberChoices,
                selected: _members,
                prefixIcon: Icons.people_outline,
                helperText: 'Select users that belong to this group.',
                searchHint: 'Search users',
                onChanged: (values) => setState(() => _members = values),
              ),
              const SizedBox(height: 12),
              ApiMultiSelectField(
                label: 'Access rights',
                choices: _privilegeChoices,
                selected: _privileges,
                prefixIcon: Icons.security_outlined,
                helperText: 'Select the OPNsense privileges inherited by group members.',
                searchHint: 'Search access rights',
                onChanged: (values) => setState(() => _privileges = values),
              ),
            ],
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
            label: Text(editing ? 'Save changes' : 'Add group'),
          ),
        ],
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tone,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(text),
        ),
      );
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  final String title;
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.manage_accounts_outlined, size: 48),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

String _scalar(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String || value is num) return value.toString().trim();
  if (value is bool) return value ? '1' : '0';
  return fallback;
}

bool _bool(dynamic value, bool fallback) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  if (const {'1', 'true', 'yes', 'on', 'enabled'}.contains(text)) return true;
  if (const {'0', 'false', 'no', 'off', 'disabled'}.contains(text)) return false;
  return fallback;
}

String? _selectedOne(dynamic raw) {
  final selected = parseApiChoices(raw)
      .where((choice) => choice.selected)
      .map((choice) => choice.value)
      .toList();
  if (selected.isNotEmpty) return selected.first;
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  return null;
}
