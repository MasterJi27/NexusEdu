/// Pagination helper for 1M-scale lists.
/// Cursor-based pagination: server returns `nextCursor` (opaque string) and `hasMore`.
/// Use with [PaginatedListView] for infinite scroll.

class PaginatedList<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  const PaginatedList({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  bool get isLast => !hasMore;

  PaginatedList<T> copyWith({
    List<T>? items,
    String? nextCursor,
    bool? hasMore,
  }) {
    return PaginatedList<T>(
      items: items ?? this.items,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  static PaginatedList<T> empty<T>() =>
      PaginatedList<T>(items: const [], hasMore: false);
}
