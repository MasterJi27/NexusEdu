import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:nexus_edu/core/services/youtube_discovery_service.dart';

class FeedState {
  final List<LearningShort> videos;
  final Set<String> completedShortIds;
  final String? selectedClass;
  final String selectedSubject;
  final String selectedTopic;
  final String? guestQuery;

  FeedState({
    required this.videos,
    required this.completedShortIds,
    this.selectedClass,
    this.selectedSubject = 'All',
    this.selectedTopic = 'All',
    this.guestQuery,
  });

  FeedState copyWith({
    List<LearningShort>? videos,
    Set<String>? completedShortIds,
    String? selectedClass,
    String? selectedSubject,
    String? selectedTopic,
    String? guestQuery,
    bool clearGuestQuery = false,
    bool clearSelectedClass = false,
  }) {
    return FeedState(
      videos: videos ?? this.videos,
      completedShortIds: completedShortIds ?? this.completedShortIds,
      selectedClass: clearSelectedClass
          ? null
          : (selectedClass ?? this.selectedClass),
      selectedSubject: selectedSubject ?? this.selectedSubject,
      selectedTopic: selectedTopic ?? this.selectedTopic,
      guestQuery: clearGuestQuery ? null : (guestQuery ?? this.guestQuery),
    );
  }
}

class FeedNotifier extends AsyncNotifier<FeedState> {
  @override
  Future<FeedState> build() async {
    final selectedClass = await LearnerProfileService.getSelectedClass();
    final completed = await LearnerProfileService.getCompletedShortIds();

    final initialVideos = selectedClass == null
        ? const <LearningShort>[]
        : LearningCatalog.shortsFor(className: selectedClass);

    return FeedState(
      videos: initialVideos,
      completedShortIds: completed,
      selectedClass: selectedClass,
    );
  }

  Future<void> submitGuestTopic(String query) async {
    state = const AsyncValue.loading();

    try {
      final localResults = LearningCatalog.searchShorts(query);
      final apiResults = await YoutubeDiscoveryService.searchEducationalShorts(
        query: query,
      );

      final merged = LearningCatalog.mergeUnique(
        apiResults,
        localResults,
      ).take(10).toList();

      final currentState = state.asData?.value;
      if (currentState != null) {
        state = AsyncValue.data(
          currentState.copyWith(
            videos: merged,
            guestQuery: query,
            clearSelectedClass: true,
            selectedSubject: 'All',
            selectedTopic: 'All',
          ),
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> changeClass(String? className) async {
    await LearnerProfileService.setSelectedClass(className);

    final currentState = state.asData?.value;
    if (currentState == null) return;

    if (className == null) {
      state = AsyncValue.data(
        currentState.copyWith(
          videos: const [],
          selectedClass: null,
          clearSelectedClass: true,
          selectedSubject: 'All',
          selectedTopic: 'All',
          clearGuestQuery: true,
        ),
      );
      return;
    }

    final videos = LearningCatalog.shortsFor(className: className);
    state = AsyncValue.data(
      currentState.copyWith(
        videos: videos,
        selectedClass: className,
        selectedSubject: 'All',
        selectedTopic: 'All',
        clearGuestQuery: true,
      ),
    );
  }

  void applySyllabusFilter({String? subject, String? topic}) {
    final currentState = state.asData?.value;
    if (currentState == null) return;

    final nextSubject = subject ?? currentState.selectedSubject;
    final nextTopic =
        topic ?? (subject == null ? currentState.selectedTopic : 'All');
    final className = currentState.selectedClass;

    if (className == null) return;

    final videos = LearningCatalog.shortsFor(
      className: className,
      subject: nextSubject,
      topic: nextTopic,
    );

    state = AsyncValue.data(
      currentState.copyWith(
        videos: videos.isEmpty
            ? LearningCatalog.shortsFor(className: className)
            : videos,
        selectedSubject: nextSubject,
        selectedTopic: nextTopic,
      ),
    );
  }

  Future<void> markCompleted(LearningShort video) async {
    await LearnerProfileService.markShortCompleted(video.videoId);
    final completed = await LearnerProfileService.getCompletedShortIds();

    final currentState = state.asData?.value;
    if (currentState != null) {
      state = AsyncValue.data(
        currentState.copyWith(completedShortIds: completed),
      );
    }
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
