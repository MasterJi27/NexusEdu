import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/core/utils/result.dart';
import 'package:nexus_edu/shared/utils/app_snackbar.dart';
import 'package:nexus_edu/shared/widgets/nexus_banner.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';

const _imPermissionOptions = <(String, String, String)>[
  ('live_classes', 'Live classes', 'See who is teaching live and watch any class.'),
  ('manage_users', 'Users & roles', 'Search accounts and assign HOD/Institute Manager roles.'),
  ('create_im', 'Create Institute Manager accounts', 'Mint new Institute Manager accounts.'),
];

/// Teacher or Principal: create an Institute Manager account with a specific
/// access scope. The credentials are shown once — hand them to the new Institute Manager;
/// they sign in from the "Institute Manager" persona on the welcome screen.
class CreateImScreen extends StatefulWidget {
  const CreateImScreen({super.key});

  @override
  State<CreateImScreen> createState() => _CreateImScreenState();
}

class _CreateImScreenState extends State<CreateImScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final Set<String> _permissions = {'live_classes'};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    setState(() => _error = null);

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all the fields.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() => _saving = true);
    final result = await SecureApiService().createImAccountResult(
      name: name,
      email: email,
      password: password,
      permissions: _permissions.toList(),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (!handleResultError(context, result)) {
      setState(() => _error = (result as Failure).message);
      return;
    }

    final data = (result as Success<Map<String, dynamic>>).data;
    final created = data['user'] as Map<String, dynamic>? ?? {};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Institute Manager account created'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share these credentials with ${created['name'] ?? name}:'),
              const SizedBox(height: AppSpace.sm),
              _CredentialRow(label: 'Email', value: created['email']?.toString() ?? email),
              const SizedBox(height: AppSpace.xxs),
              _CredentialRow(label: 'Password', value: password),
              const SizedBox(height: AppSpace.sm),
              Text(
                'They sign in from the "Institute Manager" option on the welcome screen.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              dialogContext.pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NexusScreen(
      title: 'Create Institute Manager account',
      body: ListView(
        padding: AppSpace.pageH,
        children: [
          Text(
            'An Institute Manager can be given access to live classes, user '
            'management and creating more Institute Manager accounts — you decide the scope.',
            style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password (min 6 characters)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('Access scope', style: context.text.titleMedium),
          const SizedBox(height: AppSpace.xs),
          for (final (key, title, desc) in _imPermissionOptions) ...[
            CheckboxListTile(
              value: _permissions.contains(key),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _permissions.add(key);
                } else {
                  _permissions.remove(key);
                }
              }),
              title: Text(title),
              subtitle: Text(desc),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
          const SizedBox(height: AppSpace.sm),
          if (_error != null)
            NexusBanner(message: _error!, kind: NexusBannerKind.error),
          const SizedBox(height: AppSpace.md),
          FilledButton(
            onPressed: _saving ? null : _create,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(AppSpace.minTapTarget)),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Institute Manager account'),
          ),
          const SizedBox(height: AppSpace.md),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Text('$label: ', style: context.text.bodySmall?.copyWith(color: t.inkMuted)),
        Expanded(
          child: SelectableText(value, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}