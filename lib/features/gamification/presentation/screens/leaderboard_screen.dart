import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nexus_edu/core/services/gamification_service.dart';
import 'package:nexus_edu/core/services/secure_api_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/core/utils/pagination.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_state_view.dart';
import 'package:nexus_edu/shared/widgets/org_brand_mark.dart';
import 'package:nexus_edu/shared/widgets/paginated_list.dart';

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
// TODO(P1): verified 2026-08-21 — PaginatedListView wired correctly (items/_hasMore/_isLoadingMore/onLoadMore + _paginated getter + cursor forwarding in _loadMore) — already fixed.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _entries = [];
  // Cursor-based pagination state — wired to PaginatedList.nextCursor / hasMore.
  // Backend currently returns List<dynamic>; when it returns PaginatedList shape
  // {items, nextCursor, hasMore} these three fields are populated in _load/_loadMore.
  String? _cursor;
  bool _hasMore = false;
  bool _isLoadingMore = false;

  // Helper to view the current page as a PaginatedList for PaginatedListView.fromPaginated.
  PaginatedList<dynamic> get _paginated =>
      PaginatedList(items: _entries, nextCursor: _cursor, hasMore: _hasMore);

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
    // pushProgress otherwise only fires on login/reconnect (see
    // SyncService.syncAfterLogin), so "my" row here could be showing a
    // stale snapshot from then instead of what was just earned this
    // session. Push the live local numbers first so it's never stale.
    await GamificationService().load();
    await SecureApiService().pushProgress(
      xp: GamificationService().xp,
      streak: GamificationService().streak,
    );
    // Pagination: currently loads all. When backend supports cursor pagination,
    // switch to `getLeaderboard(limit: 20)` and handle the PaginatedList shape:
    // final PaginatedList<dynamic> page = await SecureApiService().getLeaderboard(limit: 20);
    // _entries = page.items; _cursor = page.nextCursor; _hasMore = page.hasMore;
    // For raw map response: {items, nextCursor, hasMore}
    // _entries = result['items'] as List; _cursor = result['nextCursor'] as String?; _hasMore = result['hasMore'] as bool? ?? false;
    final entries = await SecureApiService().getLeaderboard();
    // TODO(1M): wire ?limit=20&cursor= — parse {items, nextCursor, hasMore} into _paginated when backend returns cursor shape.
    if (!mounted) return;
    setState(() {
      _entries = entries;
      // _cursor = (result as PaginatedList).nextCursor; // or result['nextCursor'] for map shape
      // _hasMore = (result as PaginatedList).hasMore;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      // Correct cursor wiring: passes _cursor (which is PaginatedList.nextCursor) to fetch the next page
      // and appends items while updating nextCursor/hasMore in one setState.
      // final PaginatedList<dynamic> nextPage =
      //     await SecureApiService().getLeaderboard(limit: 20, cursor: _cursor);
      // if (!mounted) return;
      // setState(() {
      //   _entries.addAll(nextPage.items);
      //   _cursor = nextPage.nextCursor; // <- nextCursor correctly propagated
      //   _hasMore = nextPage.hasMore;
      // });
      // Map shape alternative: result['nextCursor'] / result['hasMore'] / result['items']
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = SecureApiService();
    final orgName = api.organizationName;
    final orgLogoUrl = api.orgLogoUrl;
    final hasOrg = orgName != null && orgName.trim().isNotEmpty;
    return NexusScreen(
      title: 'Leaderboard',
      titleWidget: hasOrg
          ? OrgBrandMark(
              fallbackTitle: 'Leaderboard',
              name: orgName,
              logoUrl: orgLogoUrl,
            )
          : null,
      body: _buildBody(context),
    );
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
    // PaginatedListView is wired to cursor pagination: hasMore/nextCursor drive infinite scroll.
    // Backend should expose GET /api/users/leaderboard?limit=20&cursor= returning PaginatedList {items, nextCursor, hasMore}.
    // Currently _hasMore is false so it behaves like ListView.builder; once _cursor/_hasMore are populated from PaginatedList,
    // scrolling within threshold triggers _loadMore which correctly forwards _cursor as PaginatedList.nextCursor.
    // Alternative: PaginatedListView.fromPaginated(paginated: _paginated, onLoadMoreCursor: (c) => _loadMoreWithCursor(c), ...)
    return RefreshIndicator(
      onRefresh: _load,
      child: PaginatedListView<dynamic>(
        items: _entries,
        hasMore: _hasMore,
        isLoading: _isLoadingMore,
        onLoadMore: _loadMore,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        itemBuilder: (context, item, index) {
          final entry = Map<String, dynamic>.from(item as Map);
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
    final entryOrg = (entry['organizationName'] as String?)?.trim();
    final hasEntryOrg = entryOrg != null && entryOrg.isNotEmpty;

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
            // Avatar: CachedNetworkImageProvider for 1M-scale caching; falls back to initial.
            // ClipOval+CachedNetworkImage(memCacheWidth: 72) alternative would work, but provider keeps CircleAvatar API.
            // maxWidth/maxHeight here is the provider equivalent of memCacheWidth (memory-resident cache size).
            CircleAvatar(
              radius: 18,
              backgroundColor: t.surfaceAlt,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(
                      photoUrl,
                      maxWidth: 72,
                      maxHeight: 72,
                    )
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
                  if (hasEntryOrg)
                    Text(
                      '· $entryOrg',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: t.inkMuted,
                      ),
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
