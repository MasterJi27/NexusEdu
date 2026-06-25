import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/data/learning_catalog.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/learner_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _selectedClass;
  Set<String> _completedShorts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final selectedClass = await LearnerProfileService.getSelectedClass();
    final completed = await LearnerProfileService.getCompletedShortIds();
    if (!mounted) return;
    setState(() {
      _selectedClass = selectedClass;
      _completedShorts = completed;
      _isLoading = false;
    });
  }

  bool get _hasGeminiKey {
    final key = AiService.apiKey?.trim();
    return key != null && key.isNotEmpty && key != 'your_api_key_here';
  }

  void _showExamDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          AppSettings.instance.examDate ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final nameController = TextEditingController(
        text: AppSettings.instance.examName,
      );
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Exam Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'e.g. JEE Main'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                AppSettings.instance.setExamDate(date, nameController.text);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard, color: Colors.amber),
            onPressed: () => context.push('/leaderboard'),
            tooltip: 'Leaderboard',
          ),
          IconButton(
            icon: const Icon(Icons.school, color: Colors.teal),
            onPressed: () => context.push('/teacher-dashboard'),
            tooltip: 'Teacher Mode',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                children: [
                  _buildProfileHeader(
                    context,
                  ).animate().fade().slideY(begin: -0.08),
                  const SizedBox(height: 18),
                  _buildStreakCard().animate().fade(delay: 60.ms),
                  const SizedBox(height: 18),
                  _buildClassCard(context).animate().fade(delay: 100.ms),
                  const SizedBox(height: 18),
                  _buildStatsSection(context).animate().fade(delay: 180.ms),
                  const SizedBox(height: 24),
                  _buildExamCountdownCard().animate().fade(delay: 260.ms),
                  const SizedBox(height: 24),
                  _buildCertificatesSection(
                    context,
                  ).animate().fade(delay: 300.ms),
                  const SizedBox(height: 24),
                  _buildAchievementsSection(
                    context,
                  ).animate().fade(delay: 340.ms),
                  const SizedBox(height: 24),
                  _buildRecentActivity(context).animate().fade(delay: 420.ms),
                  const SizedBox(height: 24),
                  _buildLogoutButton(context).animate().fade(delay: 460.ms),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Colors.deepPurple, Colors.blueAccent],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withAlpha(45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const CircleAvatar(
            radius: 42,
            backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alex Learner',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Level 15 Scholar',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusPill(
                    _selectedClass ?? 'Guest mode',
                    _selectedClass == null
                        ? Icons.person_outline
                        : Icons.school,
                    Colors.deepPurpleAccent,
                  ),
                  _buildStatusPill(
                    _hasGeminiKey ? 'AI ready' : 'AI key needed',
                    _hasGeminiKey ? Icons.check_circle : Icons.key_off,
                    _hasGeminiKey ? Colors.teal : Colors.redAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard() {
    final streak = AppSettings.instance.streak;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withAlpha(40),
            Colors.deepOrange.withAlpha(20),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_fire_department,
              color: Colors.orange,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak Day Streak',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak == 0
                      ? 'Start studying today!'
                      : streak >= 7
                      ? 'Amazing consistency!'
                      : 'Keep it going!',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  /*
  Profile appearance controls are intentionally handled from Settings.
  Kept out of the widget tree for launch so Profile stays focused on progress.
  // ignore: unused_element
  Widget _buildThemeSection() {
    final settings = AppSettings.instance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(135),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Appearance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/settings'),
                child: const Text(
                  'Open in Settings →',
                  style: TextStyle(
                    color: Colors.deepPurpleAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...ThemeMode.values.map((mode) {
            final labels = {
              ThemeMode.system: 'System',
              ThemeMode.light: 'Light',
              ThemeMode.dark: 'Dark',
            };
            final icons = {
              ThemeMode.system: Icons.brightness_auto,
              ThemeMode.light: Icons.light_mode,
              ThemeMode.dark: Icons.dark_mode,
            };
            return RadioListTile<ThemeMode>(
              contentPadding: EdgeInsets.zero,
              title: Text(labels[mode]!),
              secondary: Icon(icons[mode]),
              value: mode,
              groupValue: settings.themeMode,
              onChanged: (v) {
                if (v != null) settings.setThemeMode(v);
              },
            );
          }),
        ],
      ),
    );
  }

  */

  Widget _buildExamCountdownCard() {
    final examDate = AppSettings.instance.examDate;
    final examName = AppSettings.instance.examName;
    if (examDate == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withAlpha(135),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).dividerColor.withAlpha(40),
          ),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event, color: Colors.purpleAccent),
          ),
          title: const Text('Set Exam Target'),
          subtitle: const Text('Add a countdown to stay motivated'),
          trailing: FilledButton.tonal(
            onPressed: _showExamDatePicker,
            child: const Text('Set Date'),
          ),
        ),
      );
    }

    final daysLeft = examDate.difference(DateTime.now()).inDays;
    final color = daysLeft <= 7
        ? Colors.redAccent
        : daysLeft <= 30
        ? Colors.orange
        : Colors.teal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(30), color.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.event, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  daysLeft <= 0 ? 'Today!' : '$daysLeft days remaining',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '$daysLeft',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const Text(
                'days',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => AppSettings.instance.clearExamDate(),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(BuildContext context) {
    final subjects = LearningCatalog.subjectsFor(_selectedClass);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withAlpha(135),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withAlpha(35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _selectedClass == null ? Icons.person_outline : Icons.school,
                  color: Colors.deepPurpleAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedClass ?? 'Guest learning',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _selectedClass == null
                          ? 'Shorts will ask topic first.'
                          : '${subjects.length} subjects linked to Shorts.',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final subject in subjects)
                  _buildStatusPill(subject.name, subject.icon, subject.color),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/elearning-class'),
                  icon: const Icon(Icons.tune),
                  label: const Text('Change Class'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go('/feed'),
                  icon: const Icon(Icons.smart_display),
                  label: const Text('Open Shorts'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final items = [
      _StatItem('120', 'Notes Scanned', Icons.document_scanner),
      _StatItem('45', 'Flashcards', Icons.swipe),
      _StatItem(
        '${_completedShorts.length}',
        'Shorts Done',
        Icons.check_circle,
      ),
      _StatItem('3', 'Certificates', Icons.workspace_premium),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.74,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Column(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                item.icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCertificatesSection(BuildContext context) {
    final certificates = LearningCatalog.certificatesFor(
      selectedClass: _selectedClass,
      completedShorts: _completedShorts.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Certifications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.go('/feed'),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Earn more'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 154,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: certificates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final c = certificates[index];
              return Container(
                width: 230,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.color.withAlpha(22),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.color.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(c.icon, color: c.color),
                        const Spacer(),
                        Text(
                          '${(c.progress * 100).round()}%',
                          style: TextStyle(
                            color: c.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      c.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                    const Spacer(),
                    LinearProgressIndicator(
                      value: c.progress,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(20),
                      backgroundColor: c.color.withAlpha(35),
                      color: c.color,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Badges',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildBadge(
              Icons.local_fire_department,
              '7 Day Streak',
              Colors.orange,
            ),
            const SizedBox(width: 14),
            _buildBadge(Icons.psychology, 'Top 5% Thinker', Colors.purple),
            const SizedBox(width: 14),
            _buildBadge(Icons.speed, 'Speed Reader', Colors.blue),
            const SizedBox(width: 14),
            _buildBadge(Icons.verified, 'Certified Learner', Colors.teal),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String tooltip, Color color) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(65), width: 2),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    final activities = [
      _ActivityItem(
        Icons.check,
        Colors.tealAccent,
        'Mastered Big O Notation',
        '2 hours ago',
      ),
      _ActivityItem(
        Icons.smart_display,
        Colors.redAccent,
        _selectedClass == null
            ? 'Used Guest Shorts by topic'
            : 'Watched $_selectedClass syllabus Shorts',
        'Today',
      ),
      _ActivityItem(
        Icons.chat,
        Colors.blueAccent,
        'Chatted with AI Tutor',
        'Yesterday',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final activity in activities)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: activity.color.withAlpha(45),
              child: Icon(activity.icon, color: activity.color),
            ),
            title: Text(activity.title),
            subtitle: Text(activity.subtitle),
          ),
      ],
    );
  }

  Widget _buildStatusPill(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  const _StatItem(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

class _ActivityItem {
  const _ActivityItem(this.icon, this.color, this.title, this.subtitle);
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

Widget _buildLogoutButton(BuildContext context) {
  return GestureDetector(
    onTap: () async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Logout', style: TextStyle(color: Colors.white)),
          content: const Text('Are you sure you want to logout?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', false);
        if (context.mounted) context.go('/login');
      }
    },
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withAlpha(40)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout, color: Colors.redAccent, size: 20),
          SizedBox(width: 8),
          Text('Logout', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    ),
  );
}
