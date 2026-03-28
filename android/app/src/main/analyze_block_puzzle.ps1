# Block Puzzle Project Analyzer - Ready to Use
Write-Host "╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     BLOCK PUZZLE PROJECT ANALYZER v1.0    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Get project path
$projectPath = Read-Host "📁 Enter your project path (or press Enter for current folder)"
if ([string]::IsNullOrWhiteSpace($projectPath)) {
    $projectPath = Get-Location
}

if (-not (Test-Path $projectPath)) {
    Write-Host "❌ ERROR: Path not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "✅ Project found at: $projectPath" -ForegroundColor Green
Write-Host ""

# Create analyzer Dart file
$analyzerContent = @'
import 'dart:io';
import 'dart:convert';

void main() async {
  print('\n🔍 ANALYZING YOUR BLOCK PUZZLE PROJECT...\n');
  
  final root = Directory.current;
  
  // Check critical files
  await checkCriticalFiles(root);
  
  // Check features
  await checkFeatures(root);
  
  // Generate priority list
  await generatePriorities(root);
}

Future<void> checkCriticalFiles(Directory root) async {
  print('📋 CRITICAL FILES CHECK:');
  print('-' * 40);
  
  final files = {
    'Main App': 'lib/main.dart',
    'Game Screen': 'lib/screens/game_screen.dart',
    'Achievements': 'lib/screens/achievements_screen.dart',
    'Prestige': 'lib/screens/prestige_screen.dart',
    'Economy Provider': 'lib/providers/economy_provider.dart',
    'Game Provider': 'lib/providers/game_provider.dart',
    'Ad Service': 'lib/services/ad_service.dart',
    'Haptic Service': 'lib/services/haptic_service.dart',
    'Sound Service': 'lib/services/sound_service.dart',
    'Skin Service': 'lib/services/skin_service.dart',
  };
  
  int found = 0;
  foreach (var file in files.keys) {
    final path = '${root.path}/${files[file]}';
    if (await File(path).exists()) {
      print('  ✅ $file');
      found++;
    } else {
      print('  ❌ $file');
    }
  }
  print('  📊 Found $found/${files.count} critical files\n');
}

Future<void> checkFeatures(Directory root) async {
  print('🎮 FEATURE ANALYSIS:');
  print('-' * 40);
  
  final features = {
    'Main Menu Screen': 'lib/screens/menu_screen.dart',
    'Daily Challenges': 'lib/screens/daily_challenges.dart',
    'Shop System': 'lib/screens/shop_screen.dart',
    'Player Profile': 'lib/screens/profile_screen.dart',
    'Leaderboards': 'lib/screens/leaderboard_screen.dart',
    'Tournaments': 'lib/screens/tournament_screen.dart',
    'Friends System': 'lib/screens/friends_screen.dart',
    'Notifications': 'lib/services/notification_service.dart',
    'Social Sharing': 'lib/services/social_service.dart',
    'Cloud Save': 'lib/services/cloud_service.dart',
    'In-App Purchases': 'lib/services/iap_service.dart',
    'Tutorial': 'lib/screens/tutorial_screen.dart',
    'Loading Screen': 'lib/widgets/loading_screen.dart',
    'Settings Screen': 'lib/screens/settings_screen.dart',
  };
  
  int found = 0;
  $missing = @();
  
  foreach (var feature in features.keys) {
    final path = '${root.path}/${features[feature]}';
    if (await File(path).exists()) {
      print('  ✅ $feature');
      found++;
    } else {
      print('  ❌ $feature');
      $missing += feature;
    }
  }
  print('  📊 Found $found/${features.count} features\n');
  
  if ($missing.count -gt 0) {
    print('🔴 MISSING FEATURES (${$missing.count}):');
    foreach ($item in $missing) {
      print('   - $item');
    }
    print('');
  }
}

Future<void> generatePriorities(Directory root) async {
  print('📊 PRIORITY RECOMMENDATIONS:');
  print('-' * 40);
  
  // Priority 1: Menu Screen (Critical)
  if (!await File('${root.path}/lib/screens/menu_screen.dart').exists()) {
    print('🔴 PRIORITY 1 - IMMEDIATE: Create Menu Screen');
    print('   → Your app needs a main menu with Play button');
    print('   → Should have game mode selection');
    print('   → Top bar with coins and settings\n');
  }
  
  // Priority 2: Daily Engagement
  if (!await File('${root.path}/lib/screens/daily_challenges.dart').exists()) {
    print('🟡 PRIORITY 2 - HIGH: Daily Challenges');
    print('   → Keep players coming back daily');
    print('   → Login streaks and rewards');
    print('   → Rotating objectives\n');
  }
  
  // Priority 3: Shop
  if (!await File('${root.path}/lib/screens/shop_screen.dart').exists()) {
    print('🟠 PRIORITY 3 - MEDIUM: Shop System');
    print('   → Monetize with skins and power-ups');
    print('   → Premium currency (gems)');
    print('   → Daily free gifts\n');
  }
  
  // Priority 4: Social Features
  if (!await File('${root.path}/lib/screens/leaderboard_screen.dart').exists()) {
    print('🔵 PRIORITY 4 - MEDIUM: Leaderboards');
    print('   → Add competition between players');
    print('   → Global and friends rankings\n');
  }
  
  // Priority 5: Profile
  if (!await File('${root.path}/lib/screens/profile_screen.dart').exists()) {
    print('💜 PRIORITY 5 - LOW: Player Profile');
    print('   → Show stats and achievements');
    print('   → Customizable avatar\n');
  }
  
  // Check main.dart for MenuScreen
  final mainFile = File('${root.path}/lib/main.dart');
  if (await mainFile.exists()) {
    final content = await mainFile.readAsString();
    if (content.contains('MenuScreen')) {
      print('✅ Your main.dart already has MenuScreen configured!');
    } else {
      print('⚠️  Update main.dart to use MenuScreen as home route');
    }
  }
}

Future<void> saveReport(Directory root) async {
  final report = StringBuffer();
  report.writeln('BLOCK PUZZLE ANALYSIS REPORT');
  report.writeln('Generated: ${DateTime.now()}');
  report.writeln('Project: ${root.path}');
  
  final reportFile = File('${root.path}/analysis_report_${DateTime.now().millisecondsSinceEpoch}.txt');
  await reportFile.writeAsString(report.toString());
  print('📝 Full report saved to: ${reportFile.path}');
}
'@

# Save the analyzer file
$analyzerPath = Join-Path $projectPath "analyze_project.dart"
$analyzerContent | Out-File -FilePath $analyzerPath -Encoding utf8 -Force

Write-Host "✅ Analyzer saved to: $analyzerPath" -ForegroundColor Green
Write-Host ""

# Run the analyzer
Write-Host "🚀 Running analysis..." -ForegroundColor Yellow
Write-Host ""

Set-Location $projectPath
flutter run analyze_project.dart

Write-Host ""
Write-Host "✨ Analysis complete! Check the results above." -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit"