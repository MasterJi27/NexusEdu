import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/ai_service.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/youtube_discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _bg = Color(0xFF0F1115);
  static const Color _surface = Color(0xFF171A21);
  static const Color _accent = Color(0xFF7C5CFF);

  bool _dailyReminder = true;
  bool _streakAlerts = true;
  double _dailyGoal = 3;
  String _appLanguage = 'English';
  String _classLevel = '10';
  String _board = 'CBSE';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dailyReminder = prefs.getBool('settings_daily_reminder') ?? true;
      _streakAlerts = prefs.getBool('settings_streak_alerts') ?? true;
      _dailyGoal = prefs.getDouble('settings_daily_goal') ?? 3;
      _appLanguage = prefs.getString('settings_app_language') ?? 'English';
      _classLevel = prefs.getString('settings_class_level') ?? '10';
      _board = prefs.getString('settings_board') ?? 'CBSE';
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  bool get _hasGeminiKey {
    final key = AiService.apiKey?.trim();
    return key != null && key.isNotEmpty && key != 'your_api_key_here';
  }

  Future<void> _showApiKeySheet({
    required String title,
    required String label,
    required Future<void> Function(String value) onSave,
  }) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            4,
            18,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stored locally. Do not share this key in screenshots or support chats.',
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final value = controller.text.trim();
                    if (value.isNotEmpty) {
                      await onSave(value);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save key'),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _Section(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              _ThemeModeSelector(
                value: settings.themeMode,
                onChanged: (mode) {
                  settings.setThemeMode(mode);
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'AI setup',
            icon: Icons.smart_toy_outlined,
            children: [
              _ApiStatusTile(
                connected: _hasGeminiKey,
                connectedTitle: 'OpenRouter connected',
                missingTitle: 'OpenRouter API key needed',
                subtitle: 'Powers AI Tutor, Notes, Quiz, Scanner and all AI tools.',
                onPressed: () => _showApiKeySheet(
                  title: 'OpenRouter key',
                  label: 'OpenRouter API key',
                  onSave: AiService.saveApiKey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Study preferences',
            icon: Icons.school_outlined,
            children: [
              _SliderRow(
                label: 'Daily goal',
                value: _dailyGoal,
                display: '${_dailyGoal.round()} hrs',
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (value) {
                  setState(() => _dailyGoal = value);
                  _saveDouble('settings_daily_goal', value);
                },
              ),
              _DropdownRow(
                label: 'Class',
                value: _classLevel,
                options: const ['6', '7', '8', '9', '10', '11', '12'],
                onChanged: (value) {
                  setState(() => _classLevel = value);
                  _saveString('settings_class_level', value);
                },
              ),
              _DropdownRow(
                label: 'Board',
                value: _board,
                options: const ['CBSE', 'ICSE', 'State Board'],
                onChanged: (value) {
                  setState(() => _board = value);
                  _saveString('settings_board', value);
                },
              ),
              _DropdownRow(
                label: 'Language',
                value: _appLanguage,
                options: const ['English', 'Hindi', 'Hinglish'],
                onChanged: (value) {
                  setState(() => _appLanguage = value);
                  _saveString('settings_app_language', value);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Notifications',
            icon: Icons.notifications_none,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Daily study reminder'),
                subtitle: const Text('Gentle reminder to keep your streak'),
                value: _dailyReminder,
                onChanged: (value) {
                  setState(() => _dailyReminder = value);
                  _saveBool('settings_daily_reminder', value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Streak alerts'),
                subtitle: const Text('Notify before your streak breaks'),
                value: _streakAlerts,
                onChanged: (value) {
                  setState(() => _streakAlerts = value);
                  _saveBool('settings_streak_alerts', value);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Play Store & data',
            icon: Icons.verified_user_outlined,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.privacy_tip_outlined, color: _accent),
                title: const Text('Privacy policy'),
                subtitle: const Text('Required for Play Store listing'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/privacy-policy'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                title: const Text('Clear local data'),
                subtitle: const Text('Notes, preferences and cached progress'),
                onTap: _confirmClearData,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all local data?'),
        content: const Text(
          'This removes notes, settings, progress and cached app data from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await AppSettings.instance.load();
    if (!mounted) return;
    await _loadSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Local data cleared.')));
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF171A21),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2F3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF7C5CFF), size: 20),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = [
      (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
      (ThemeMode.light, 'Light', Icons.light_mode_outlined),
      (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
    ];
    return Row(
      children: [
        for (final entry in entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(entry.$3, size: 16),
                label: Text(entry.$2),
                selected: value == entry.$1,
                onSelected: (_) => onChanged(entry.$1),
              ),
            ),
          ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.display,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String display;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(display, style: const TextStyle(color: Color(0xFF7C5CFF))),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ApiStatusTile extends StatelessWidget {
  const _ApiStatusTile({
    required this.connected,
    required this.connectedTitle,
    required this.missingTitle,
    required this.subtitle,
    required this.onPressed,
  });

  final bool connected;
  final String connectedTitle;
  final String missingTitle;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        connected ? Icons.check_circle : Icons.error_outline,
        color: connected ? Colors.greenAccent : Colors.orangeAccent,
      ),
      title: Text(
        connected ? connectedTitle : missingTitle,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: TextButton(
        onPressed: onPressed,
        child: Text(connected ? 'Change' : 'Add', style: const TextStyle(color: Color(0xFF7C5CFF))),
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<String>(
            value: value,
            dropdownColor: const Color(0xFF171A21),
            items: options
                .map(
                  (option) =>
                      DropdownMenuItem(value: option, child: Text(option)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}
