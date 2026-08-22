import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/core/utils/pagination.dart';
import 'package:nexus_edu/shared/utils/app_snackbar.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/paginated_list.dart';

const _imPermissionOptions = <(String, String)>[
  ('live_classes', 'Live classes'),
  ('manage_users', 'Users & roles'),
  ('create_im', 'Create IAM accounts'),
];

/// Principal (or IAM with user-management access): search any account and
/// assign a role — Teacher, HOD, IAM (with an access scope), Student or
/// Parent. HOD gets live-class observation automatically.
class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _api = SecureApiService();
  final _search = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  String? _savingId;
  String? _cursor;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  PaginatedList<Map<String, dynamic>> get _paginatedUsers =>
      PaginatedList(items: _users, nextCursor: _cursor, hasMore: _hasMore);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _api.getAdminUsersResult(query: _search.text.trim());
    if (!mounted) return;
    if (!handleResultError(context, result)) {
      setState(() {
        _loading = false;
        _error = (result as Failure).message;
      });
      return;
    }
    final data = (result as Success<Map<String, dynamic>>).data;
    setState(() {
      _loading = false;
      _users = (data['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      // TODO: when backend paginates admin/users, parse nextCursor/hasMore
      _cursor = data['nextCursor'] as String?;
      _hasMore = data['hasMore'] as bool? ?? false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      // TODO: paginate with ?limit=20&cursor=_cursor when backend supports it
      // final result = await _api.getAdminUsers(query: _search.text.trim(), cursor: _cursor);
      // if (!mounted) return;
      // setState(() {
      //   _users.addAll((result['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
      //   _cursor = result['nextCursor'] as String?;
      //   _hasMore = result['hasMore'] as bool? ?? false;
      // });
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _assignRole(Map<String, dynamic> user) async {
    final currentRole = user['role']?.toString() ?? 'student';
    final perms = (user['imPermissions'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toSet();
    String selected = currentRole == 'admin' ? 'teacher' : currentRole;
    final selectedPerms = Set<String>.from(perms);
    if (selected == 'im' && selectedPerms.isEmpty) selectedPerms.add('live_classes');
    final t = context.tokens;

    final role = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: t.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Text(
                'Role for ${user['name']}',
                style: context.text.titleMedium,
              ),
            ),
            RadioGroup<String>(
              groupValue: selected,
              onChanged: (v) {
                selected = v ?? 'teacher';
                if (v == 'hod') selectedPerms..clear()..add('live_classes');
                sheetContext.pop(selected);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (value, label) in const <(String, String)>[
                    ('teacher', 'Teacher'),
                    ('hod', 'HOD (Head of Department)'),
                    ('im', 'IAM (Institute Manager)'),
                    ('student', 'Student'),
                    ('parent', 'Parent'),
                  ])
                    RadioListTile<String>(
                      value: value,
                      title: Text(label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      ),
    );
    if (role == null || !mounted || role == currentRole) return;

    var permissions = const <String>[];
    if (role == 'im') {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: t.surface,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Text(
                    'Access for the IAM account',
                    style: context.text.titleMedium,
                  ),
                ),
                for (final (key, label) in _imPermissionOptions)
                  CheckboxListTile(
                    value: selectedPerms.contains(key),
                    title: Text(label),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                    onChanged: (checked) => setSheetState(() {
                      if (checked == true) {
                        selectedPerms.add(key);
                      } else {
                        selectedPerms.remove(key);
                      }
                    }),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppSpace.minTapTarget)),
                    onPressed: () => sheetContext.pop(true),
                    child: const Text('Save role'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
      permissions = selectedPerms.toList();
    }

    setState(() => _savingId = user['id'] as String);
    final result = await _api.assignUserRoleResult(
      user['id'] as String,
      role: role,
      permissions: permissions,
    );
    if (!mounted) return;
    setState(() => _savingId = null);
    if (!handleResultError(context, result)) {
      return;
    }
    await _load();
  }

  String _roleLabel(String role) => switch (role) {
        'admin' => 'Principal',
        'im' => 'IAM',
        'hod' => 'HOD',
        'parent' => 'Parent',
        'teacher' => 'Teacher',
        _ => 'Student',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusScreen(
      title: 'Users & roles',
      body: Column(
        children: [
          Padding(
            padding: AppSpace.pageH,
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search by name, email or student ID',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: AppSpace.pageH,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              NexusBanner(message: _error!, kind: NexusBannerKind.error),
                              const SizedBox(height: AppSpace.sm),
                              OutlinedButton(onPressed: _load, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: PaginatedListView<Map<String, dynamic>>(
                          items: _paginatedUsers.items,
                          hasMore: _paginatedUsers.hasMore,
                          isLoading: _isLoadingMore,
                          onLoadMore: _loadMore,
                          padding: AppSpace.pageH,
                          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm),
                          itemBuilder: (context, user, index) {
                            final isAdmin = user['role']?.toString() == 'admin';
                            final saving = _savingId == user['id'] as String;
                            return Material(
                              color: t.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.brMd,
                                side: BorderSide(color: t.border),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: t.primaryTint,
                                  child: Icon(
                                    isAdmin ? Icons.workspace_premium_outlined : Icons.person_outline,
                                    color: t.primary,
                                  ),
                                ),
                                title: Text(
                                  user['name']?.toString() ?? 'Unknown',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${user['email']}'
                                  '${(user['studentId']?.toString().isNotEmpty ?? false) ? ' · ${user['studentId']}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: isAdmin
                                    ? Chip(
                                        label: Text(
                                          _roleLabel('admin'),
                                          style: context.text.labelSmall?.copyWith(color: t.primary),
                                        ),
                                        backgroundColor: t.primaryTint,
                                        side: BorderSide.none,
                                      )
                                    : saving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : FilledButton.tonal(
                                            onPressed: () => _assignRole(user),
                                            child: Text(_roleLabel(user['role']?.toString() ?? 'student')),
                                          ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}