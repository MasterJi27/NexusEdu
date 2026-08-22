import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/theme/app_theme.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/features/feed/presentation/providers/feed_provider.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_filter_chips.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class AiFeedScreen extends ConsumerStatefulWidget {
  const AiFeedScreen({super.key});

  @override
  ConsumerState<AiFeedScreen> createState() => _AiFeedScreenState();
}

class _AiFeedScreenState extends ConsumerState<AiFeedScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _topicController = TextEditingController();
  final Map<int, YoutubePlayerController> _controllers = {};

  int _currentIndex = 0;
  bool _isDiscovering = false;

  void _initController(int index, List<LearningShort> videos) {
    if (index < 0 ||
        index >= videos.length ||
        _controllers.containsKey(index)) {
      return;
    }

    _controllers[index] = YoutubePlayerController.fromVideoId(
      videoId: videos[index].videoId,
      autoPlay: index == _currentIndex,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        enableCaption: true,
        interfaceLanguage: 'en',
        strictRelatedVideos: true,
        loop: true,
      ),
    );
  }

  void _resetControllers(List<LearningShort> videos) {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();

    if (videos.isEmpty) return;
    _currentIndex = 0;
    _initController(0, videos);
    _initController(1, videos);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      _controllers[0]?.playVideo();
    });
  }

  void _goToPage(int target, int count) {
    if (target < 0 || target >= count) return;
    if (!_pageController.hasClients) return;
    _pageController.animateToPage(
      target,
      duration: AppMotion.sheet,
      curve: AppMotion.standard,
    );
  }

  void _onPageChanged(int index, List<LearningShort> videos) {
    setState(() => _currentIndex = index);

    for (final entry in _controllers.entries) {
      if (entry.key == index) {
        entry.value.playVideo();
      } else {
        entry.value.pauseVideo();
      }
    }

    _initController(index - 1, videos);
    _initController(index + 1, videos);

    final keysToRemove = <int>[];
    for (final entry in _controllers.entries) {
      if ((entry.key - index).abs() > 2) {
        entry.value.close();
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _controllers.remove(key);
    }
  }

  Future<void> _submitGuestTopic() async {
    final query = _topicController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Type a topic first.')));
      return;
    }

    setState(() => _isDiscovering = true);
    await ref.read(feedProvider.notifier).submitGuestTopic(query);
    if (mounted) setState(() => _isDiscovering = false);

    final videos = ref.read(feedProvider).asData?.value.videos ?? [];
    _resetControllers(videos);
  }

  Future<void> _showClassPicker(String? currentSelectedClass) async {
    const guestModeValue = '__guest__';
    final nextClass = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final t = sheetContext.tokens;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              0,
              AppSpace.lg,
              AppSpace.lg,
            ),
            children: [
              Text(
                'Choose learning class',
                style: sheetContext.text.titleLarge,
              ),
              const SizedBox(height: AppSpace.sm),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Guest mode'),
                subtitle: const Text('Ask by topic every time'),
                onTap: () => Navigator.pop(sheetContext, guestModeValue),
              ),
              Divider(color: t.border),
              for (final className in LearningCatalog.classes)
                ListTile(
                  leading: Icon(
                    currentSelectedClass == className
                        ? Icons.radio_button_checked
                        : Icons.school_outlined,
                    color:
                        currentSelectedClass == className ? t.primary : null,
                  ),
                  title: Text(className),
                  subtitle: Text(
                    '${LearningCatalog.subjectsFor(className).length} subjects, '
                    '${LearningCatalog.topicsFor(className, null).length} topics',
                  ),
                  onTap: () => Navigator.pop(sheetContext, className),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (nextClass == null) return;

    _topicController.clear();
    await ref
        .read(feedProvider.notifier)
        .changeClass(nextClass == guestModeValue ? null : nextClass);
    final videos = ref.read(feedProvider).asData?.value.videos ?? [];
    _resetControllers(videos);
  }

  @override
  void dispose() {
    _topicController.dispose();
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedStateAsync = ref.watch(feedProvider);

    return Theme(
      data: AppTheme.darkTheme,
      child: Builder(
        builder: (context) => feedStateAsync.when(
          loading: () => Scaffold(
            backgroundColor: context.tokens.page,
            body: Center(
              child: CircularProgressIndicator(color: context.tokens.primary),
            ),
          ),
          error: (err, stack) => Scaffold(
            backgroundColor: context.tokens.page,
            body: Center(
              child: Text(
                'Error: $err',
                style: context.text.bodyMedium?.copyWith(color: context.tokens.inkMuted),
              ),
            ),
          ),
          data: (feedState) {
            if (feedState.selectedClass == null && feedState.guestQuery == null) {
              return _buildGuestTopicScreen(context, null);
            }

            if (feedState.videos.isEmpty) {
              return _buildEmptyScreen(context, feedState.selectedClass);
            }

            final currentIndex = _currentIndex.clamp(0, feedState.videos.length - 1);
            final currentVideo = feedState.videos[currentIndex];
            final isCompleted = feedState.completedShortIds.contains(currentVideo.videoId);

            return Scaffold(
              backgroundColor: context.tokens.page,
              body: SafeArea(
                child: Column(
                  children: [
                    _buildTopFilters(context, feedState),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        // The YouTube player is a native platform view (WebView) that
                        // renders and receives touches above Flutter's own widgets, so
                        // neither drag gestures nor overlaid buttons on top of it work
                        // reliably. Navigation controls live below the video instead,
                        // in screen space the player doesn't occupy.
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (index) =>
                            _onPageChanged(index, feedState.videos),
                        itemCount: feedState.videos.length,
                        itemBuilder: (context, index) {
                          _initController(index, feedState.videos);
                          return _buildVideoArea(context, index);
                        },
                      ),
                    ),
                    _buildBottomControlBar(
                      context,
                      video: currentVideo,
                      isCompleted: isCompleted,
                      completedCount: feedState.completedShortIds.length,
                      index: currentIndex,
                      count: feedState.videos.length,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGuestTopicScreen(
    BuildContext context,
    String? currentSelectedClass,
  ) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.primaryTint,
                      borderRadius: AppRadius.brMd,
                    ),
                    child: Icon(Icons.smart_display, color: t.primary),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'Learning Shorts',
                      style: context.text.headlineSmall?.copyWith(
                        color: t.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Select class',
                    onPressed: () => _showClassPicker(currentSelectedClass),
                    icon: Icon(Icons.school_outlined, color: t.ink),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                'Guest mode',
                style: context.text.bodyLarge?.copyWith(color: t.inkMuted),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                'What topic do you want shorts for?',
                style: context.text.headlineLarge?.copyWith(
                  color: t.ink,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'Select a class once to unlock syllabus-only recommendations. Without a class, Nexus asks for a topic first.',
                style: context.text.bodyMedium?.copyWith(
                  color: t.inkMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              Container(
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  borderRadius: AppRadius.brMd,
                  border: Border.all(color: t.border),
                ),
                child: TextField(
                  controller: _topicController,
                  style: context.text.bodyLarge?.copyWith(color: t.ink),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitGuestTopic(),
                  decoration: InputDecoration(
                    hintText: 'Example: cell membrane, quadratic equations',
                    hintStyle: context.text.bodyMedium?.copyWith(color: t.inkFaint),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg,
                      vertical: AppSpace.md,
                    ),
                    prefixIcon: Icon(Icons.search, color: t.inkFaint),
                    suffixIcon: IconButton(
                      onPressed: _isDiscovering ? null : _submitGuestTopic,
                      icon: _isDiscovering
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: t.primary,
                              ),
                            )
                          : Icon(Icons.arrow_forward, color: t.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildTopicSuggestion(context, 'Biology cell', 0),
                  _buildTopicSuggestion(context, 'Newton laws', 1),
                  _buildTopicSuggestion(context, 'Photosynthesis', 2),
                  _buildTopicSuggestion(context, 'Quadratic equations', 3),
                ],
              ),
              const Spacer(),
              const SizedBox(height: AppSpace.lg),
              NexusButton(
                label: 'Select Class for syllabus feed',
                icon: Icons.school,
                fullWidth: true,
                onPressed: () => _showClassPicker(currentSelectedClass),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicSuggestion(BuildContext context, String topic, int index) {
    final t = context.tokens;
    return ActionChip(
      label: Text(
        topic,
        style: context.text.labelLarge?.copyWith(
          color: t.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      avatar: Icon(Icons.bolt, size: 16, color: t.secondary),
      backgroundColor: t.surfaceAlt,
      side: BorderSide(color: t.border),
      onPressed: () {
        _topicController.text = topic;
        _submitGuestTopic();
      },
    );
  }

  Widget _buildEmptyScreen(BuildContext context, String? currentSelectedClass) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 72,
                color: t.inkFaint,
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                'No shorts matched this filter',
                textAlign: TextAlign.center,
                style: context.text.headlineSmall?.copyWith(color: t.ink),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                'Try another topic or switch class filters.',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: t.inkMuted),
              ),
              const SizedBox(height: AppSpace.lg),
              NexusButton(
                label: 'Change filters',
                icon: Icons.tune,
                onPressed: () => _showClassPicker(currentSelectedClass),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoArea(BuildContext context, int index) {
    final controller = _controllers[index]!;
    return Container(
      color: context.tokens.page,
      child: IgnorePointer(
        child: YoutubePlayer(
          controller: controller,
          backgroundColor: context.tokens.page,
        ),
      ),
    );
  }

  // Controls live BELOW the video, never overlapping its bounds. The embedded
  // YouTube player is a native platform view that composites and receives
  // touches above Flutter's own widgets, so anything drawn or tapped on top
  // of it (gradients, buttons, drag gestures) is unreliable-to-invisible.
  Widget _buildBottomControlBar(
    BuildContext context, {
    required LearningShort video,
    required bool isCompleted,
    required int completedCount,
    required int index,
    required int count,
  }) {
    final t = context.tokens;
    final controller = _controllers[index];

    return Container(
      color: t.surface,
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            children: [
              _buildMiniChip(context, video.className),
              _buildMiniChip(context, video.subject),
              if (video.isApiResult) _buildMiniChip(context, 'Live YouTube'),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleMedium?.copyWith(
              color: t.ink,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpace.xxs),
          Text(
            '${video.creator} • ${video.topic}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: t.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (completedCount / 12).clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: AppRadius.brPill,
                  backgroundColor: t.surfaceAlt,
                  color: isCompleted ? t.statusPresent : t.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${index + 1}/$count',
                style: context.text.labelSmall?.copyWith(
                  color: t.inkMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavArrow(
                context,
                icon: Icons.keyboard_arrow_up,
                onTap: () => _goToPage(index - 1, count),
              ),
              IconButton(
                icon: Icon(Icons.play_arrow_rounded, color: t.ink),
                iconSize: 30,
                onPressed: () async {
                  if (controller == null) return;
                  final state = await controller.playerState;
                  if (state == PlayerState.playing) {
                    controller.pauseVideo();
                  } else {
                    controller.playVideo();
                  }
                },
              ),
              _buildNavArrow(
                context,
                icon: Icons.keyboard_arrow_down,
                onTap: () => _goToPage(index + 1, count),
              ),
              _buildActionButton(
                context,
                icon: isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                label: isCompleted ? 'Done' : 'Save',
                color: isCompleted ? t.statusPresent : t.ink,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref.read(feedProvider.notifier).markCompleted(video);
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Saved "${video.topic}" to your progress.')),
                  );
                },
              ),
              _buildActionButton(
                context,
                icon: Icons.smart_toy_outlined,
                label: 'Tutor',
                color: t.ink,
                onTap: () => context.go('/tutor'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopFilters(BuildContext context, FeedState feedState) {
    final t = context.tokens;
    final className = feedState.selectedClass;
    final subjects = className == null
        ? const <SubjectSyllabus>[]
        : LearningCatalog.subjectsFor(className);
    final topics = className == null
        ? const <String>[]
        : LearningCatalog.topicsFor(className, feedState.selectedSubject);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
      color: t.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  className != null
                      ? '$className Feed'
                      : 'Search: "${feedState.guestQuery}"',
                  style: context.text.titleLarge?.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.tune, color: t.ink),
                onPressed: () => _showClassPicker(className),
              ),
            ],
          ),
          if (subjects.isNotEmpty)
            NexusFilterChips<String>(
              options: ['All Subjects', ...subjects.map((s) => s.name)],
              selected: feedState.selectedSubject,
              onSelected: (label) {
                ref.read(feedProvider.notifier).applySyllabusFilter(subject: label, topic: 'All');
                final videos = ref.read(feedProvider).asData?.value.videos ?? feedState.videos;
                _resetControllers(videos);
              },
            ),
          if (feedState.selectedSubject != 'All' && topics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: NexusFilterChips<String>(
                options: ['All Topics', ...topics],
                selected: feedState.selectedTopic,
                onSelected: (label) {
                  ref.read(feedProvider.notifier).applySyllabusFilter(topic: label);
                  final videos = ref.read(feedProvider).asData?.value.videos ?? feedState.videos;
                  _resetControllers(videos);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(BuildContext context, String label) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xs,
        vertical: AppSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        label,
        style: context.text.labelSmall?.copyWith(
          color: t.inkMuted,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNavArrow(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: t.border),
        ),
        child: Icon(icon, color: t.inkMuted, size: 24),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: Column(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: t.border),
              ),
              child: Icon(icon, color: color, size: 27),
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              label,
              style: context.text.labelSmall?.copyWith(
                color: t.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
