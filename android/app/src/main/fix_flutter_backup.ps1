# fix_flutter_backup.ps1
$projectPath = Get-Location

# 1. Replace deprecated .withOpacity
Get-ChildItem "$projectPath\lib" -Recurse -Include *.dart | ForEach-Object {
    (Get-Content $_.FullName) |
    ForEach-Object { $_ -replace "\.withOpacity\(", ".withValues(alpha:" } |
    Set-Content $_.FullName
}

# 2. Create missing assets/images directory
$assetDir = "$projectPath\assets\images"
if (!(Test-Path $assetDir)) { New-Item -ItemType Directory -Force -Path $assetDir }

# 3. Create placeholder my_list.dart
$myListFile = "$projectPath\lib\utils\my_list.dart"
if (!(Test-Path $myListFile)) {
    New-Item -ItemType File -Force -Path $myListFile
    Add-Content $myListFile @"
import 'package:flutter/material.dart';

class MyList extends StatelessWidget {
  const MyList({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(); // placeholder
  }
}
"@
}

# 4. Create placeholder reveal_splash_screen.dart
$revealFile = "$projectPath\lib\screens\reveal_splash_screen.dart"
if (!(Test-Path $revealFile)) {
    New-Item -ItemType File -Force -Path $revealFile
    Add-Content $revealFile @"
import 'package:flutter/material.dart';

class RevealSplashScreen extends StatelessWidget {
  const RevealSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(); // placeholder
  }
}
"@
}

# 5. Run flutter analyze
flutter analyze
