import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Appearance
  String _theme = 'Dark';
  double _fontSize = 1;
  String _accentColor = 'Purple';

  // Notifications
  bool _dailyReminder = true;
  bool _quizNotifications = true;
  bool _streakAlerts = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);

  // Language
  String _appLanguage = 'English';
  String _aiResponseLanguage = 'English';

  // Accessibility
  bool _highContrast = false;
  bool _largeText = false;
  bool _screenReader = false;
  bool _reduceAnimations = false;

  // Study Preferences
  double _dailyGoal = 3;
  String _examType = 'None';
  String _classLevel = '10';
  String _board = 'CBSE';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _theme = prefs.getString('settings_theme') ?? 'Dark';
      _fontSize = prefs.getDouble('settings_font_size') ?? 1;
      _accentColor = prefs.getString('settings_accent_color') ?? 'Purple';
      _dailyReminder = prefs.getBool('settings_daily_reminder') ?? true;
      _quizNotifications = prefs.getBool('settings_quiz_notifications') ?? true;
      _streakAlerts = prefs.getBool('settings_streak_alerts') ?? true;
      final hour = prefs.getInt('settings_reminder_hour') ?? 8;
      final minute = prefs.getInt('settings_reminder_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
      _appLanguage = prefs.getString('settings_app_language') ?? 'English';
      _aiResponseLanguage = prefs.getString('settings_ai_language') ?? 'English';
      _highContrast = prefs.getBool('settings_high_contrast') ?? false;
      _largeText = prefs.getBool('settings_large_text') ?? false;
      _screenReader = prefs.getBool('settings_screen_reader') ?? false;
      _reduceAnimations = prefs.getBool('settings_reduce_animations') ?? false;
      _dailyGoal = prefs.getDouble('settings_daily_goal') ?? 3;
      _examType = prefs.getString('settings_exam_type') ?? 'None';
      _classLevel = prefs.getString('settings_class_level') ?? '10';
      _board = prefs.getString('settings_board') ?? 'CBSE';
    });
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          _buildSection('Appearance', Icons.palette, [
            _buildThemeSelector(),
            _buildFontSizeSelector(),
            _buildAccentColorSelector(),
          ]),
          const SizedBox(height: 20),
          _buildSection('Notifications', Icons.notifications, [
            _buildSwitchTile('Daily study reminder', _dailyReminder, (v) {
              setState(() => _dailyReminder = v);
              _saveBool('settings_daily_reminder', v);
            }),
            _buildSwitchTile('Quiz notifications', _quizNotifications, (v) {
              setState(() => _quizNotifications = v);
              _saveBool('settings_quiz_notifications', v);
            }),
            _buildSwitchTile('Streak alerts', _streakAlerts, (v) {
              setState(() => _streakAlerts = v);
              _saveBool('settings_streak_alerts', v);
            }),
            _buildTimePicker(),
          ]),
          const SizedBox(height: 20),
          _buildSection('Language', Icons.language, [
            _buildRadioGroup('App language', ['English', 'Hindi', 'Hinglish'], _appLanguage, (v) {
              setState(() => _appLanguage = v);
              _saveString('settings_app_language', v);
            }),
            const Divider(color: Colors.white10, height: 16),
            _buildRadioGroup('AI response language', ['English', 'Hindi', 'Auto'], _aiResponseLanguage, (v) {
              setState(() => _aiResponseLanguage = v);
              _saveString('settings_ai_language', v);
            }),
          ]),
          const SizedBox(height: 20),
          _buildSection('Accessibility', Icons.accessibility_new, [
            _buildSwitchTile('High contrast mode', _highContrast, (v) {
              setState(() => _highContrast = v);
              _saveBool('settings_high_contrast', v);
            }),
            _buildSwitchTile('Large text', _largeText, (v) {
              setState(() => _largeText = v);
              _saveBool('settings_large_text', v);
            }),
            _buildSwitchTile('Screen reader optimized', _screenReader, (v) {
              setState(() => _screenReader = v);
              _saveBool('settings_screen_reader', v);
            }),
            _buildSwitchTile('Reduce animations', _reduceAnimations, (v) {
              setState(() => _reduceAnimations = v);
              _saveBool('settings_reduce_animations', v);
            }),
          ]),
          const SizedBox(height: 20),
          _buildSection('Study Preferences', Icons.school, [
            _buildGoalSlider(),
            _buildDropdownTile('Exam type', _examType, ['None', 'JEE', 'NEET', 'CBSE Board', 'State Board'], (v) {
              setState(() => _examType = v);
              _saveString('settings_exam_type', v);
            }),
            _buildDropdownTile('Class level', _classLevel, ['6', '7', '8', '9', '10', '11', '12'], (v) {
              setState(() => _classLevel = v);
              _saveString('settings_class_level', v);
            }),
            _buildDropdownTile('Board', _board, ['CBSE', 'ICSE', 'State Board'], (v) {
              setState(() => _board = v);
              _saveString('settings_board', v);
            }),
          ]),
          const SizedBox(height: 20),
          _buildSection('About', Icons.info_outline, [
            _buildInfoTile('App version', '1.0.0'),
            _buildInfoTile('Developer', 'Ragha (Raghavkathuria@devflow.me)'),
            _buildInfoTile('GitHub', 'github.com/MasterJi27/NexusEdu'),
            _buildActionTile('Privacy Policy', Icons.privacy_tip, () {
              context.push('/privacy-policy');
            }),
            _buildActionTile('Rate App', Icons.star, () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening Play Store...')),
              );
            }),
            _buildActionTile('Share App', Icons.share, () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share flow coming soon.')),
              );
            }),
          ]),
          const SizedBox(height: 20),
          _buildSection('Data', Icons.storage, [
            _buildActionTile('Clear all data', Icons.delete_forever, () {
              _showClearDataDialog();
            }, color: Colors.redAccent),
            _buildActionTile('Export study data', Icons.download, () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export flow coming soon.')),
              );
            }),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: Colors.deepPurpleAccent, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    ).animate().fade();
  }

  Widget _buildThemeSelector() {
    final themes = ['System', 'Light', 'Dark'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: themes.map((t) {
          final selected = _theme == t;
          return GestureDetector(
            onTap: () {
              setState(() => _theme = t);
              _saveString('settings_theme', t);
            },
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? Colors.deepPurpleAccent.withAlpha(40) : Colors.white.withAlpha(10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.deepPurpleAccent : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    t == 'System' ? Icons.brightness_auto : t == 'Light' ? Icons.light_mode : Icons.dark_mode,
                    color: selected ? Colors.deepPurpleAccent : Colors.white54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t,
                  style: TextStyle(
                    color: selected ? Colors.deepPurpleAccent : Colors.white54,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFontSizeSelector() {
    final sizes = ['Small', 'Medium', 'Large', 'Extra Large'];
    final values = [0.0, 1.0, 2.0, 3.0];
    final currentIndex = values.indexOf(_fontSize);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Font size', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(sizes[currentIndex >= 0 ? currentIndex : 1], style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.deepPurpleAccent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.deepPurpleAccent,
              overlayColor: Colors.deepPurpleAccent.withAlpha(30),
            ),
            child: Slider(
              value: _fontSize,
              min: 0,
              max: 3,
              divisions: 3,
              onChanged: (v) {
                setState(() => _fontSize = v);
                _saveDouble('settings_font_size', v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccentColorSelector() {
    final colors = {
      'Purple': Colors.deepPurpleAccent,
      'Blue': Colors.blueAccent,
      'Green': Colors.greenAccent,
      'Red': Colors.redAccent,
      'Orange': Colors.orangeAccent,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Accent color', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 10),
          Row(
            children: colors.entries.map((e) {
              final selected = _accentColor == e.key;
              return GestureDetector(
                onTap: () {
                  setState(() => _accentColor = e.key);
                  _saveString('settings_accent_color', e.key);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 14),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: e.value,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: e.value.withAlpha(80), blurRadius: 12)]
                        : [],
                  ),
                  child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.deepPurpleAccent,
            activeTrackColor: Colors.deepPurpleAccent.withAlpha(80),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker() {
    final hour = _reminderTime.hourOfPeriod;
    final minute = _reminderTime.minute.toString().padLeft(2, '0');
    final period = _reminderTime.period == DayPeriod.am ? 'AM' : 'PM';
    final displayTime = '$hour:$minute $period';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Reminder time', style: TextStyle(color: Colors.white, fontSize: 15)),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _reminderTime,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Colors.deepPurpleAccent,
                        surface: Color(0xFF1E1E1E),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _reminderTime = picked);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('settings_reminder_hour', picked.hour);
                await prefs.setInt('settings_reminder_minute', picked.minute);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurpleAccent.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.deepPurpleAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(displayTime, style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioGroup(String title, List<String> options, String selected, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          ...options.map((opt) {
            return RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 14)),
              value: opt,
              groupValue: selected,
              activeColor: Colors.deepPurpleAccent,
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGoalSlider() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daily study goal', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text('${_dailyGoal.round()} hrs', style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.deepPurpleAccent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.deepPurpleAccent,
              overlayColor: Colors.deepPurpleAccent.withAlpha(30),
            ),
            child: Slider(
              value: _dailyGoal,
              min: 1,
              max: 10,
              divisions: 9,
              onChanged: (v) {
                setState(() => _dailyGoal = v);
                _saveDouble('settings_daily_goal', v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(String title, String value, List<String> options, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurpleAccent.withAlpha(60)),
            ),
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1E1E1E),
              underline: const SizedBox(),
              isDense: true,
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.deepPurpleAccent, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String subtitle) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
    );
  }

  Widget _buildActionTile(String title, IconData icon, VoidCallback onTap, {Color? color}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(title, style: TextStyle(color: color ?? Colors.white, fontSize: 15)),
      trailing: Icon(icon, color: color ?? Colors.deepPurpleAccent, size: 20),
      onTap: onTap,
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Clear all data?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently remove all your study progress, flashcards, notes, and preferences.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.pop(ctx);
                setState(() => _loadSettings());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared.')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
