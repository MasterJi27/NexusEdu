import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_edu/core/services/app_settings.dart';
import 'package:nexus_edu/core/services/streak_notification_service.dart';
import 'package:nexus_edu/core/theme/design_tokens.dart';
import 'package:nexus_edu/shared/widgets/nexus_button.dart';
import 'package:nexus_edu/shared/widgets/nexus_card.dart';
import 'package:nexus_edu/shared/widgets/nexus_chip_group.dart';
import 'package:nexus_edu/shared/widgets/nexus_list_row.dart';
import 'package:nexus_edu/shared/widgets/nexus_screen.dart';
import 'package:nexus_edu/shared/widgets/nexus_section_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
      _streakAlerts = prefs.getBool('settings_streak_alerts') ?? true;
      _dailyGoal = prefs.getDouble('settings_daily_goal') ?? 3;
      _appLanguage = prefs.getString('settings_app_language') ?? 'English';
      _classLevel = prefs.getString('settings_class_level') ?? '10';
      _board = prefs.getString('settings_board') ?? 'CBSE';
    });
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final settings = AppSettings.instance;
    return NexusScreen(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.md,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          const NexusSectionHeader(title: 'Appearance', spaceAbove: 0),
          NexusCard(
            child: _ThemeModeSelector(
              value: settings.themeMode,
              onChanged: (mode) {
                settings.setThemeMode(mode);
                setState(() {});
              },
            ),
          ),
          const NexusSectionHeader(title: 'Study preferences'),
          NexusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: AppSpace.sm),
                _DropdownRow(
                  label: 'Class',
                  value: _classLevel,
                  options: const ['6', '7', '8', '9', '10', '11', '12'],
                  onChanged: (value) {
                    setState(() => _classLevel = value);
                    _saveString('settings_class_level', value);
                  },
                ),
                const SizedBox(height: AppSpace.sm),
                _DropdownRow(
                  label: 'Board',
                  value: _board,
                  options: const ['CBSE', 'ICSE', 'State Board'],
                  onChanged: (value) {
                    setState(() => _board = value);
                    _saveString('settings_board', value);
                  },
                ),
                const SizedBox(height: AppSpace.sm),
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
          ),
          const NexusSectionHeader(title: 'Notifications'),
          NexusCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Streak alerts'),
                  subtitle: const Text(
                    'A 7pm reminder before your streak breaks',
                  ),
                  value: _streakAlerts,
                  onChanged: (value) async {
                    setState(() => _streakAlerts = value);
                    await StreakNotificationService.instance.setEnabled(value);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          value
                              ? 'Streak alerts on — reminder set for 7pm.'
                              : 'Streak alerts off.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const NexusSectionHeader(title: 'AI & data'),
          NexusCard(
            child: Column(
              children: [
                NexusListRow(
                  leadingIcon: Icons.data_usage,
                  title: 'AI usage & tokens',
                  subtitle: 'See your token usage and daily AI limit',
                  trailing: Icon(Icons.chevron_right, color: t.inkFaint),
                  onTap: () => context.push('/ai-usage'),
                ),
                NexusListRow(
                  leadingIcon: Icons.delete_outline,
                  title: 'Clear local data',
                  subtitle: 'Notes, preferences and cached progress',
                  onTap: _confirmClearData,
                ),
              ],
            ),
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
          NexusButton(
            label: 'Cancel',
            variant: NexusButtonVariant.secondary,
            size: NexusButtonSize.small,
            onPressed: () => Navigator.pop(context, false),
          ),
          NexusButton(
            label: 'Clear',
            variant: NexusButtonVariant.danger,
            size: NexusButtonSize.small,
            onPressed: () => Navigator.pop(context, true),
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

/// Light and dark are both real, complete themes (`lib/core/theme/app_theme.dart`),
/// so this genuinely switches the app's appearance rather than confirming a
/// fixed one — picking "Light" here used to render the same dark surface.
class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  static const _labels = {
    ThemeMode.system: 'System',
    ThemeMode.light: 'Light',
    ThemeMode.dark: 'Dark',
  };

  @override
  Widget build(BuildContext context) {
    return NexusChipGroup(
      label: 'Theme',
      options: _labels.values.toList(),
      selected: {_labels[value]!},
      onChanged: (selection) {
        final label = selection.first;
        final mode = _labels.entries
            .firstWhere((entry) => entry.value == label)
            .key;
        onChanged(mode);
      },
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
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.text.bodyMedium)),
            Text(
              display,
              style: context.typeExtras.figure.copyWith(color: t.primary),
            ),
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
    final t = context.tokens;
    return Row(
      children: [
        Expanded(child: Text(label, style: context.text.bodyMedium)),
        DropdownButton<String>(
          value: value,
          dropdownColor: t.surface,
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
    );
  }
}
