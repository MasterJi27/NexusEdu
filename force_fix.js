const fs = require('fs');

// Fix boss battle screen
let bossPath = 'lib/features/teacher/presentation/screens/boss_battle_screen.dart';
if (fs.existsSync(bossPath)) {
  let c = fs.readFileSync(bossPath, 'utf8');
  if (!c.includes("import 'package:flutter_animate/flutter_animate.dart';")) {
    c = "import 'package:flutter_animate/flutter_animate.dart';\n" + c;
    fs.writeFileSync(bossPath, c, 'utf8');
    console.log("Fixed boss battle screen");
  }
}

// Fix main.dart StateProvider
let mainPath = 'lib/main.dart';
if (fs.existsSync(mainPath)) {
  let m = fs.readFileSync(mainPath, 'utf8');
  m = m.replace(
    'final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);',
    `class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;
  void toggle() => state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
}
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);`
  );
  fs.writeFileSync(mainPath, m, 'utf8');
  console.log("Fixed main.dart");
}
