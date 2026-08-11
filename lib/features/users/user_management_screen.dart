import 'package:flutter/material.dart';

import '../../core/api/opnsense_api_client.dart';
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
  String _userQuery = '';
  String _groupQuery = '';
  String _userFilter = 'all';

  @override
  void initState() {
    super.initState();
    _repository = UserManagementRepository(
      OpnSenseApiClient(profile: widget.profile, credentials: widget.credentials),
    );
    _audit = AuditRepository(profileId: widget.profile.id);
    _reload();
  }

  void _reload() {
    _users = _repository.loadUsers();
    _groups = _repository.loadGroups();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await Future.wait([_users, _groups]);
  }

  Future<void> _editUser([FirewallUserSummary? user]) async {
    Map<String, dynamic> values = <String, dynamic>{};
    if (user != null && user.uuid.isNotEmpty) {
      try {
        values = await _repository.getUser(user.uuid);
      } catch (_) {
        values = <String, dynamic>{};
      }
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _UserEditor(
          repository: _repository,
          audit: _audit,
          user: user,
          initial: values,
        ),
      ),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _editGroup([FirewallGroupSummary? group]) async {
    Map<String, dynamic> values = <String, dynamic>{};
    if (group != null && group.uuid.isNotEmpty) {
      try {
        values = await _repository.getGroup(group.uuid);
      } catch (_) {
        values = <String, dynamic>{};
      }
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _GroupEditor(
          repository: _repository,
          audit: _audit,
          group: group,
          initial: values,
        ),
      ),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _deleteUser(FirewallUserSummary user) async {
    if (user.isSystem) {
      _message('System users cannot be deleted from Sentinel.');
      return;
    }
    final ok = await _confirm(
      title: 'Delete user?',
      text: 'Delete ${user.name}? This can affect authentication and API access.',
      action: 'Delete',
    );
    if (!ok) return;
    try {
      await _repository.deleteUser(user.uuid);
      await _record('Delete user', user.name, 'success');
      await _refresh();
    } catch (error) {
      await _record('Delete user', user.name, 'failed', error.toString());
      _message('User delete failed: $error');
    }
  }

  Future<void> _deleteGroup(FirewallGroupSummary group) async {
    if (group.isSystem) {
      _message('System groups cannot be deleted from Sentinel.');
      return;
    }
    final ok = await _confirm(
      title: 'Delete group?',
      text: 'Delete ${group.name}? Users relying on this group may lose privileges.',
      action: 'Delete',
    );
    if (!ok) return;
    try {
      await _repository.deleteGroup(group.uuid);
      await _record('Delete group', group.name, 'success');
      await _refresh();
    } catch (error) {
      await _record('Delete group', group.name, 'failed', error.toString());
      _message('Group delete failed: $error');
    }
  }

  Future<void> _generateApiKey(FirewallUserSummary user) async {
    final ok = await _confirm(
      title: 'Generate API key?',
      text: 'Create a new API key for ${user.name}? The secret is shown only once. Store it securely.',
      action: 'Generate',
    );
    if (!ok) return;
    try {
      final generated = await _repository.generateApiKey(user.name);
      await _record('Generate API key', user.name, 'success');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New API credentials'),
          content: SelectableText(
            '${generated.hostname.isEmpty ? '' : 'Host: ${generated.hostname}\n\n'}'
            'API key:\n${generated.key}\n\nAPI secret:\n${generated.secret}\n\n'
            'Copy these now. The secret cannot be retrieved later.',
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
      await _record('Generate API key', user.name, 'failed', error.toString());
      _message('API key generation failed: $error');
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

  Future<void> _record(String action, String target, String result, [String details = '']) async {
    try {
      await _audit.record(
        action: action,
        target: target,
        result: result,
        details: details,
      );
    } catch (_) {}
  }

  void _message(String text) {
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
              tooltip: 'Refresh',
              onPressed: _refresh,
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
        body: TabBarView(
          children: [
            _usersTab(),
            _groupsTab(),
          ],
        ),
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
        if (snapshot.hasError) return _error('Users unavailable', snapshot.error);
        final users = snapshot.data ?? const <FirewallUserSummary>[];
        final query = _userQuery.trim().toLowerCase();
        final filtered = users.where((user) {
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
              _sectionHeader(
                title: 'Firewall users',
                subtitle: '${filtered.length} of ${users.length} shown',
                onAdd: () => _editUser(),
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _userQuery = value),
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
                  for (final item in const {
                    'all': 'All',
                    'enabled': 'Enabled',
                    'disabled': 'Disabled',
                    'admin': 'Admins',
                  }.entries)
                    ChoiceChip(
                      label: Text(item.value),
                      selected: _userFilter == item.key,
                      onSelected: (_) => setState(() => _userFilter = item.key),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              for (final user in filtered) ...[
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(user.isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline),
                    ),
                    title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user.description.isNotEmpty) Text(user.description),
                        if (user.email.isNotEmpty) Text(user.email),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          children: [
                            _pill(user.disabled ? 'Disabled' : 'Enabled', user.disabled ? Colors.orange : Colors.green),
                            if (user.isAdmin) _pill('Admin', Theme.of(context).colorScheme.primary),
                            if (user.isSystem) _pill('System', Theme.of(context).colorScheme.outline),
                          ],
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () => _editUser(user),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _editUser(user);
                        if (value == 'key') _generateApiKey(user);
                        if (value == 'delete') _deleteUser(user);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'key', child: Text('Generate API key')),
                        if (!user.isSystem)
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (filtered.isEmpty) _empty('No users match the selected filters.'),
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
        if (snapshot.hasError) return _error('Groups unavailable', snapshot.error);
        final groups = snapshot.data ?? const <FirewallGroupSummary>[];
        final query = _groupQuery.trim().toLowerCase();
        final filtered = groups.where((group) =>
            query.isEmpty ||
            group.name.toLowerCase().contains(query) ||
            group.description.toLowerCase().contains(query)).toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _sectionHeader(
                title: 'Firewall groups',
                subtitle: '${filtered.length} of ${groups.length} shown',
                onAdd: () => _editGroup(),
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _groupQuery = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search groups',
                ),
              ),
              const SizedBox(height: 14),
              for (final group in filtered) ...[
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                    title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      [
                        if (group.description.isNotEmpty) group.description,
                        if (group.member.isNotEmpty) 'Members: ${group.member}',
                      ].join('\n'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _editGroup(group),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _editGroup(group);
                        if (value == 'delete') _deleteGroup(group);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (!group.isSystem)
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (filtered.isEmpty) _empty('No groups match the search.'),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add')),
      ],
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  Widget _empty(String text) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(text)));

  Widget _error(String title, Object? error) => Center(
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
              FilledButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ),
        ),
      );
}

class _UserEditor extends StatefulWidget {
  const _UserEditor({
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
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  late final TextEditingController _name;
  late final TextEditingController _descr;
  late final TextEditingController _email;
  late final TextEditingController _comment;
  late final TextEditingController _password;
  bool _disabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    String text(String key, [String fallback = '']) => widget.initial[key]?.toString() ?? fallback;
    _name = TextEditingController(text: text('name', widget.user?.name ?? ''));
    _descr = TextEditingController(text: text('descr', widget.user?.description ?? ''));
    _email = TextEditingController(text: text('email', widget.user?.email ?? ''));
    _comment = TextEditingController(text: text('comment', widget.user?.comment ?? ''));
    _password = TextEditingController();
    final disabled = widget.initial['disabled'] ?? widget.user?.disabled;
    _disabled = disabled == true || disabled == 1 || disabled?.toString() == '1';
  }

  @override
  void dispose() {
    _name.dispose();
    _descr.dispose();
    _email.dispose();
    _comment.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username is required.')));
      return;
    }
    setState(() => _busy = true);
    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'descr': _descr.text.trim(),
      'email': _email.text.trim(),
      'comment': _comment.text.trim(),
      'disabled': _disabled ? '1' : '0',
      'scope': widget.initial['scope']?.toString() ?? widget.user?.scope ?? 'user',
    };
    if (_password.text.isNotEmpty) data['password'] = _password.text;

    try {
      await widget.repository.saveUser(uuid: widget.user?.uuid, values: data);
      try {
        await widget.audit.record(
          action: widget.user == null ? 'Add user' : 'Edit user',
          target: _name.text.trim(),
          result: 'success',
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save user: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.user != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit user' : 'Add user')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, enabled: !widget.user!.isSystem || !editing, decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: 12),
          TextField(controller: _descr, decoration: const InputDecoration(labelText: 'Full name / description')),
          const SizedBox(height: 12),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(controller: _comment, decoration: const InputDecoration(labelText: 'Comment')),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: editing ? 'New password (leave blank to keep)' : 'Password'),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Disabled'),
            subtitle: const Text('Disabled users cannot authenticate.'),
            value: _disabled,
            onChanged: (value) => setState(() => _disabled = value),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Group membership and fine-grained privileges are managed in Groups / Effective Privileges. Sentinel preserves those settings when editing a user.'),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(editing ? 'Save changes' : 'Add user'),
          ),
        ],
      ),
    );
  }
}

class _GroupEditor extends StatefulWidget {
  const _GroupEditor({
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
  State<_GroupEditor> createState() => _GroupEditorState();
}

class _GroupEditorState extends State<_GroupEditor> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _sourceNetworks;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial['name']?.toString() ?? widget.group?.name ?? '');
    _description = TextEditingController(text: widget.initial['description']?.toString() ?? widget.group?.description ?? '');
    _sourceNetworks = TextEditingController(text: widget.initial['source_networks']?.toString() ?? widget.group?.sourceNetworks ?? '');
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group name is required.')));
      return;
    }
    setState(() => _busy = true);
    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'source_networks': _sourceNetworks.text.trim(),
      'scope': widget.initial['scope']?.toString() ?? widget.group?.scope ?? 'user',
    };
    for (final key in const ['member', 'priv']) {
      if (widget.initial[key] != null) data[key] = widget.initial[key];
    }
    try {
      await widget.repository.saveGroup(uuid: widget.group?.uuid, values: data);
      try {
        await widget.audit.record(
          action: widget.group == null ? 'Add group' : 'Edit group',
          target: _name.text.trim(),
          result: 'success',
        );
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to save group: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.group != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit group' : 'Add group')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Group name')),
          const SizedBox(height: 12),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 12),
          TextField(
            controller: _sourceNetworks,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Source networks',
              hintText: 'Optional, comma-separated networks',
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('Existing group members and privileges are preserved by Sentinel while editing basic group details.'),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(editing ? 'Save changes' : 'Add group'),
          ),
        ],
      ),
    );
  }
}
