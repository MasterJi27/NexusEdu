import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';

/// Real XP leaderboard, read from `GET /api/users/leaderboard`.
///
/// This screen used to render a hardcoded podium (Sarah/Alex/John, or
/// Mia/Leo/Zoe on a "Campus" tab) above ten rows of `Student N` with XP
/// derived from `1500 - index * 50` — entirely invented, and shown to students
/// as though they were competing against real people. Per `PRODUCT.md`, a
/// number that cannot be traced to real activity must not be presented as
/// fact, so all of it is gone.
///
/// The "Campus" segment went with it: there is no campus or institution model
/// in the schema, so a campus-scoped ranking was a claim the backend could not
/// answer. When there is genuinely nothing to rank yet, this shows an honest
/// empty state instead of filling the space.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    if (!SecureApiService().isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }
    final entries = await SecureApiService().getLeaderboard();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NexusScreen(title: 'Leaderboard', body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.lg),
        child: NexusStateView.loading(rows: 5),
      );
    }
    if (!SecureApiService().isLoggedIn) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpace.xl),
          child: NexusStateView.empty(
            title: 'Sign in to see the leaderboard',
            description:
                'Rankings are based on real XP earned by signed-in students.',
            icon: Icons.lock_outline,
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: NexusStateView.error(message: _error!, onRetry: _load),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: NexusStateView.empty(
            title: 'No rankings yet',
            description:
                'Once students start earning XP, the top scorers appear here.',
            icon: Icons.leaderboard_outlined,
            actionLabel: 'Refresh',
            onAction: _load,
          ),
        ),
      );
    }

    final myId = SecureApiService().userId;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = Map<String, dynamic>.from(_entries[index] as Map);
          return _buildRow(context, entry, index + 1, entry['id'] == myId);
        },
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    Map<String, dynamic> entry,
    int rank,
    bool isMe,
  ) {
    final t = context.tokens;
    final name = entry['name'] as String? ?? 'Student';
    final xp = (entry['xp'] as num?)?.toInt() ?? 0;
    final streak = (entry['streak'] as num?)?.toInt() ?? 0;
    final photoUrl = entry['photoUrl'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xs),
      child: NexusCard(
        background: isMe ? t.primaryTint : null,
        borderColor: isMe ? t.primaryTintBorder : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Text('$rank', style: context.typeExtras.figure),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: t.surfaceAlt,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: context.text.labelMedium,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '$name (you)' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typeExtras.bodyStrong,
                  ),
                  if (streak > 0)
                    Text('$streak day streak', style: context.text.bodySmall),
                ],
              ),
            ),
            Text(
              '$xp XP',
              style: context.typeExtras.figure.copyWith(color: t.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
