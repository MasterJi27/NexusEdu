const fs = require('fs');
const path = require('path');

function replaceInFile(filePath, searchRegex, replaceWith) {
  if (!fs.existsSync(filePath)) return;
  let content = fs.readFileSync(filePath, 'utf8');
  content = content.replace(searchRegex, replaceWith);
  fs.writeFileSync(filePath, content, 'utf8');
}

function getAllFiles(dirPath, arrayOfFiles) {
  let files = fs.readdirSync(dirPath)

  arrayOfFiles = arrayOfFiles || []

  files.forEach(function(file) {
    if (fs.statSync(dirPath + "/" + file).isDirectory()) {
      arrayOfFiles = getAllFiles(dirPath + "/" + file, arrayOfFiles)
    } else {
      if(file.endsWith('.dart')) {
          arrayOfFiles.push(path.join(dirPath, "/", file))
      }
    }
  })

  return arrayOfFiles
}

const files = getAllFiles('lib');
files.forEach(f => {
  replaceInFile(f, /Colors\.white50/g, 'Colors.white54');
});

replaceInFile('lib/features/monetization/presentation/screens/api_licensing_screen.dart', /Estimated Revenue: \$145,028\.00/g, 'Estimated Revenue: \\$145,028.00');
replaceInFile('lib/features/monetization/presentation/screens/data_monetization_dashboard_screen.dart', /Est\. Value: \$45,000/g, 'Est. Value: \\$45,000');
replaceInFile('lib/features/future_tech/presentation/screens/web3_crypto_wallet_screen.dart', /\$NEXUS/g, '\\$NEXUS');
replaceInFile('lib/features/future_tech/presentation/screens/web3_crypto_wallet_screen.dart', /\$14\.50/g, '\\$14.50');
replaceInFile('lib/features/practice/presentation/screens/ar_explorer_screen.dart', /_buildArButton\(Icons\.360, 'Rotate'\)/g, "_buildArButton(Icons.threesixty, 'Rotate')");

let bossPath = 'lib/features/teacher/presentation/screens/boss_battle_screen.dart';
if(fs.existsSync(bossPath)) {
  let c = fs.readFileSync(bossPath, 'utf8');
  if(!c.includes('flutter_animate.dart')) {
    c = "import 'package:flutter_animate/flutter_animate.dart';\n" + c;
    fs.writeFileSync(bossPath, c, 'utf8');
  }
}
console.log('Script done');
