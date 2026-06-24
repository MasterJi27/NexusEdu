import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/features/feed/presentation/providers/feed_provider.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Type a topic first.')));
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const Text(
                'Choose learning class',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Guest mode'),
                subtitle: const Text('Ask by topic every time'),
                onTap: () => Navigator.pop(context, guestModeValue),
              ),
              const Divider(),
              for (final className in LearningCatalog.classes)
                ListTile(
                  leading: Icon(
                    currentSelectedClass == className
                        ? Icons.radio_button_checked
                        : Icons.school_outlined,
                    color: currentSelectedClass == className
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(className),
                  subtitle: Text(
                    '${LearningCatalog.subjectsFor(className).length} subjects, '
                    '${LearningCatalog.topicsFor(className, null).length} topics',
                  ),
                  onTap: () => Navigator.pop(context, className),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (nextClass == null) return;
    
    _topicController.clear();
    await ref.read(feedProvider.notifier).changeClass(nextClass == guestModeValue ? null : nextClass);
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

    return feedStateAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
      ),
      data: (feedState) {
        if (feedState.selectedClass == null && feedState.guestQuery == null) {
          return _buildGuestTopicScreen(context, null);
        }

        if (feedState.videos.isEmpty) {
          return _buildEmptyScreen(context, feedState.selectedClass);
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                onPageChanged: (index) => _onPageChanged(index, feedState.videos),
                itemCount: feedState.videos.length,
                itemBuilder: (context, index) {
                  _initController(index, feedState.videos);
                  return _buildShortPage(context, index, feedState);
                },
              ),
              _buildTopFilters(context, feedState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuestTopicScreen(BuildContext context, String? currentSelectedClass) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(40),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.smart_display,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Learning Shorts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Select class',
                    onPressed: () => _showClassPicker(currentSelectedClass),
                    icon: const Icon(
                      Icons.school_outlined,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Text(
                'Guest mode',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'What topic do you want shorts for?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select a class once to unlock syllabus-only recommendations. Without a class, Nexus asks for a topic first.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withAlpha(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurpleAccent.withAlpha(40),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _topicController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submitGuestTopic(),
                  decoration: InputDecoration(
                    hintText: 'Example: cell membrane, quadratic equations',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withAlpha(150)),
                    suffixIcon: IconButton(
                      onPressed: _isDiscovering ? null : _submitGuestTopic,
                      icon: _isDiscovering
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurpleAccent),
                            )
                          : const Icon(Icons.arrow_forward, color: Colors.deepPurpleAccent),
                    ),
                  ),
                ),
              ).animate().fade(duration: 500.ms).slideY(begin: 0.1),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildTopicSuggestion('Biology cell', 0),
                  _buildTopicSuggestion('Newton laws', 1),
                  _buildTopicSuggestion('Photosynthesis', 2),
                  _buildTopicSuggestion('Quadratic equations', 3),
                ],
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.deepPurpleAccent, Colors.purple.withAlpha(200)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurpleAccent.withAlpha(80),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: () => _showClassPicker(currentSelectedClass),
                  icon: const Icon(Icons.school, color: Colors.white),
                  label: const Text(
                    'Select Class for syllabus feed',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ).animate().fade(delay: 500.ms).slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicSuggestion(String topic, int index) {
    return ActionChip(
      label: Text(topic, style: const TextStyle(fontWeight: FontWeight.w600)),
      avatar: const Icon(Icons.bolt, size: 16, color: Colors.amber),
      backgroundColor: Colors.white.withAlpha(20),
      side: BorderSide(color: Colors.white.withAlpha(30)),
      labelStyle: const TextStyle(color: Colors.white),
      onPressed: () {
        _topicController.text = topic;
        _submitGuestTopic();
      },
    ).animate().fade(delay: (100 * index).ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildEmptyScreen(BuildContext context, String? currentSelectedClass) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 72,
                color: Colors.white.withAlpha(130),
              ),
              const SizedBox(height: 20),
              const Text(
                'No shorts matched this filter',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Try another topic or switch class filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withAlpha(160)),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showClassPicker(currentSelectedClass),
                icon: const Icon(Icons.tune),
                label: const Text('Change filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortPage(BuildContext context, int index, FeedState feedState) {
    final video = feedState.videos[index];
    final controller = _controllers[index]!;
    final isCompleted = feedState.completedShortIds.contains(video.videoId);

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        Positioned.fill(
          child: IgnorePointer(
            child: YoutubePlayer(
              controller: controller,
              backgroundColor: Colors.black,
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            onTap: () async {
              final state = await controller.playerState;
              if (state == PlayerState.playing) {
                controller.pauseVideo();
              } else {
                controller.playVideo();
              }
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(204),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withAlpha(230),
                  ],
                  stops: const [0.0, 0.2, 0.6, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 104,
          child: Column(
            children: [
              _buildActionButton(
                icon: isCompleted
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                label: isCompleted ? 'Done' : 'Save',
                color: isCompleted ? Colors.tealAccent : Colors.white,
                onTap: () async {
                  await ref.read(feedProvider.notifier).markCompleted(video);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saved "${video.topic}" to your progress.')),
                    );
                  }
                },
              ),
              _buildActionButton(
                icon: Icons.smart_toy_outlined,
                label: 'Tutor',
                color: Colors.white,
                onTap: () => context.go('/tutor'),
              ),
              _buildActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                color: Colors.white,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share flow coming soon.')),
                  );
                },
              ),
            ],
          ),
        ).animate().fade(delay: 300.ms).slideX(begin: 0.3),
        Positioned(
          left: 16,
          right: 76,
          bottom: 18,
          child: _buildInfoPanel(context, video, isCompleted, feedState.completedShortIds.length),
        ).animate().fade(delay: 150.ms).slideY(begin: 0.18),
      ],
    );
  }

  Widget _buildInfoPanel(
    BuildContext context,
    LearningShort video,
    bool isCompleted,
    int completedCount,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(100),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(35)),
          ),
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMiniChip(video.className),
              _buildMiniChip(video.subject),
              if (video.isApiResult) _buildMiniChip('Live YouTube'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${video.creator} • ${video.topic}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            video.takeaway,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (completedCount / 12).clamp(0.0, 1.0),
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(20),
                  backgroundColor: Colors.white.withAlpha(30),
                  color: isCompleted ? Colors.tealAccent : Colors.amberAccent,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completedCount/12',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
      ),
    );
  }

  Widget _buildTopFilters(BuildContext context, FeedState feedState) {
    final className = feedState.selectedClass;
    final subjects = className == null
        ? const <SubjectSyllabus>[]
        : LearningCatalog.subjectsFor(className);
    final topics = className == null
        ? const <String>[]
        : LearningCatalog.topicsFor(className, feedState.selectedSubject);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withAlpha(200), Colors.transparent],
            ),
          ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.tune,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    onPressed: () => _showClassPicker(className),
                  ),
                ],
              ),
              if (subjects.isNotEmpty)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: subjects.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final isAll = i == 0;
                      final label =
                          isAll ? 'All Subjects' : subjects[i - 1].name;
                      final isSelected = feedState.selectedSubject == label;
                      return ChoiceChip(
                        label: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.white,
                        backgroundColor: Colors.black.withAlpha(100),
                        onSelected: (val) {
                          if (val) {
                            ref.read(feedProvider.notifier).applySyllabusFilter(
                              subject: label,
                              topic: 'All',
                            );
                            _resetControllers(feedState.videos);
                          }
                        },
                      );
                    },
                  ),
                ),
              if (feedState.selectedSubject != 'All' && topics.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: topics.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final isAll = i == 0;
                        final label = isAll ? 'All Topics' : topics[i - 1];
                        final isSelected = feedState.selectedTopic == label;
                        return ChoiceChip(
                          label: Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.black
                                  : Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.tealAccent,
                          backgroundColor: Colors.black.withAlpha(100),
                          onSelected: (val) {
                            if (val) {
                              ref.read(feedProvider.notifier).applySyllabusFilter(
                                topic: label,
                              );
                              _resetControllers(feedState.videos);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    Color? color,
    bool dense = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        avatar: icon == null ? null : Icon(icon, size: dense ? 14 : 16),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
        selectedColor: (color ?? Colors.deepPurpleAccent).withAlpha(200),
        backgroundColor: Colors.white.withAlpha(25),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.white60,
          fontWeight: FontWeight.w700,
          fontSize: dense ? 12 : 13,
        ),
        side: BorderSide(color: selected ? (color ?? Colors.deepPurpleAccent).withAlpha(150) : Colors.white.withAlpha(20)),
        elevation: selected ? 4 : 0,
        shadowColor: color?.withAlpha(100) ?? Colors.deepPurpleAccent.withAlpha(100),
      ),
    );
  }

  Widget _buildMiniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(34),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: Column(
          children: [
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(90),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(40)),
                  ),
                  child: Icon(icon, color: color, size: 27),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
