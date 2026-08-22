import 'package:flutter/material.dart';
import 'package:nexus_edu/core/utils/pagination.dart';

/// Simple infinite-scroll helper for 1M-scale lists.
///
/// Keeps implementation minimal (no extra package). Uses a [ScrollController]
/// to call [onLoadMore] when the scroll is within [threshold] of the end.
/// For cursor-based APIs, pair with [PaginatedList.nextCursor].
///
/// If you later need full virtualization, replace the inner [ListView.builder]
/// with `infinite_scroll_pagination`'s `PagedListView` — the [PaginatedList]
/// model stays the same.
class PaginatedListView<T> extends StatefulWidget {
  const PaginatedListView({
    super.key,
    required this.items,
    required this.hasMore,
    required this.onLoadMore,
    required this.itemBuilder,
    this.isLoading = false,
    this.threshold = 200,
    this.padding,
    this.emptyWidget,
    this.separatorBuilder,
    this.physics,
  });

  /// Optional cursor-aware constructor that wraps a [PaginatedList].
  factory PaginatedListView.fromPaginated({
    Key? key,
    required PaginatedList<T> paginated,
    required Future<void> Function(String? cursor) onLoadMoreCursor,
    required Widget Function(BuildContext, T, int) itemBuilder,
    bool isLoading = false,
    double threshold = 200,
    EdgeInsetsGeometry? padding,
    Widget? emptyWidget,
    Widget Function(BuildContext, int)? separatorBuilder,
    ScrollPhysics? physics,
  }) {
    return PaginatedListView<T>(
      key: key,
      items: paginated.items,
      hasMore: paginated.hasMore,
      onLoadMore: () => onLoadMoreCursor(paginated.nextCursor),
      itemBuilder: itemBuilder,
      isLoading: isLoading,
      threshold: threshold,
      padding: padding,
      emptyWidget: emptyWidget,
      separatorBuilder: separatorBuilder,
      physics: physics,
    );
  }

  final List<T> items;
  final bool hasMore;
  final Future<void> Function() onLoadMore;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final bool isLoading;
  final double threshold;
  final EdgeInsetsGeometry? padding;
  final Widget? emptyWidget;
  final Widget Function(BuildContext, int)? separatorBuilder;
  final ScrollPhysics? physics;

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late final ScrollController _controller;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onScroll() async {
    if (!widget.hasMore || widget.isLoading || _loadingMore) return;
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    // Trigger when within threshold of bottom.
    if (pos.pixels >= pos.maxScrollExtent - widget.threshold) {
      _loadingMore = true;
      try {
        await widget.onLoadMore();
      } finally {
        if (mounted) _loadingMore = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      if (widget.emptyWidget != null) return widget.emptyWidget!;
      return const SizedBox.shrink();
    }
    return ListView.separated(
      controller: _controller,
      padding: widget.padding,
      physics: widget.physics ?? const ClampingScrollPhysics(),
      itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
      separatorBuilder:
          widget.separatorBuilder ?? (_, _) => const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          // Trailing loader for pagination.
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return widget.itemBuilder(context, widget.items[index], index);
      },
    );
  }
}

/// Non-scroll-controller helper for sheets / shrinkWrap contexts where a full
/// controller is not needed but `onLoadMore` should still fire near the end.
/// Used by bottom sheets that already constrain height.
class PaginatedSliverList<T> extends StatelessWidget {
  const PaginatedSliverList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.hasMore = false,
    this.onLoadMore,
  });

  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final bool hasMore;
  final Future<void> Function()? onLoadMore;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (hasMore && onLoadMore != null) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
            onLoadMore!();
          }
        }
        return false;
      },
      child: ListView.builder(
        // Sheet lists keep shrinkWrap for bounded height inside Flexible/ConstrainedBox.
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (c, i) => itemBuilder(c, items[i], i),
      ),
    );
  }
}
