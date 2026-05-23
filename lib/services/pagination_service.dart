import 'package:cloud_firestore/cloud_firestore.dart';

/// Generic pagination cursor for Firestore queries
class PaginationCursor {
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
  final int pageSize;

  PaginationCursor({
    this.lastDocument,
    this.hasMore = true,
    this.pageSize = 20,
  });

  /// Create initial cursor (no previous document yet)
  factory PaginationCursor.initial({int pageSize = 20}) {
    return PaginationCursor(
      lastDocument: null,
      hasMore: true,
      pageSize: pageSize,
    );
  }

  /// Copy with updated state
  PaginationCursor copyWith({
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    bool? hasMore,
    int? pageSize,
  }) {
    return PaginationCursor(
      lastDocument: lastDocument ?? this.lastDocument,
      hasMore: hasMore ?? this.hasMore,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

/// Represents paginated results with cursor for next page
class PaginatedResults<T> {
  final List<T> items;
  final PaginationCursor nextCursor;
  final int totalCount; // For UI display

  PaginatedResults({
    required this.items,
    required this.nextCursor,
    this.totalCount = 0,
  });

  /// Check if there are more items to load
  bool get hasMore => nextCursor.hasMore;

  /// Check if this is the last page
  bool get isLastPage => !hasMore;
}

/// Cache for pagination results to minimize refetches
class PaginationCache<T> {
  final Map<String, List<T>> _cache = {};
  final int maxCacheSize;
  final Duration cacheDuration;

  late DateTime _cacheTime;

  PaginationCache({
    this.maxCacheSize = 500,
    this.cacheDuration = const Duration(minutes: 5),
  }) {
    _cacheTime = DateTime.now();
  }

  /// Store paginated results
  void put(String key, List<T> items) {
    if (_cache.length >= maxCacheSize) {
      _cache.clear(); // Simple eviction policy
    }
    _cache[key] = items;
    _cacheTime = DateTime.now();
  }

  /// Retrieve cached results if still valid
  List<T>? get(String key) {
    if (DateTime.now().difference(_cacheTime) > cacheDuration) {
      _cache.clear();
      return null;
    }
    return _cache[key];
  }

  /// Clear cache
  void clear() {
    _cache.clear();
  }

  /// Check if cache contains key
  bool containsKey(String key) => _cache.containsKey(key);
}

/// Handles infinite scroll and lazy loading patterns
class InfiniteScrollState<T> {
  final List<T> items;
  final PaginationCursor currentCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool isRefreshing;

  const InfiniteScrollState({
    this.items = const [],
    required this.currentCursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.isRefreshing = false,
  });

  /// Create initial state
  factory InfiniteScrollState.initial({int pageSize = 20}) {
    return InfiniteScrollState(
      items: [],
      currentCursor: PaginationCursor.initial(pageSize: pageSize),
      isLoading: true,
      isLoadingMore: false,
      error: null,
    );
  }

  /// Copy with new state
  InfiniteScrollState<T> copyWith({
    List<T>? items,
    PaginationCursor? currentCursor,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? isRefreshing,
  }) {
    return InfiniteScrollState(
      items: items ?? this.items,
      currentCursor: currentCursor ?? this.currentCursor,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  /// Merge new items with existing (for load more)
  InfiniteScrollState<T> appendPage(List<T> newItems, PaginationCursor nextCursor) {
    return copyWith(
      items: [...items, ...newItems],
      currentCursor: nextCursor,
      isLoadingMore: false,
      error: null,
    );
  }

  /// Replace items (for refresh)
  InfiniteScrollState<T> replacePage(List<T> newItems, PaginationCursor nextCursor) {
    return copyWith(
      items: newItems,
      currentCursor: nextCursor,
      isLoading: false,
      isRefreshing: false,
      error: null,
    );
  }

  /// Set loading state
  InfiniteScrollState<T> setLoading(bool loading) {
    return copyWith(isLoading: loading);
  }

  /// Set loading more state
  InfiniteScrollState<T> setLoadingMore(bool loadingMore) {
    return copyWith(isLoadingMore: loadingMore);
  }

  /// Set error
  InfiniteScrollState<T> setError(String? error) {
    return copyWith(error: error, isLoading: false, isLoadingMore: false);
  }

  /// Set refreshing state
  InfiniteScrollState<T> setRefreshing(bool refreshing) {
    return copyWith(isRefreshing: refreshing, isLoading: false);
  }
}
