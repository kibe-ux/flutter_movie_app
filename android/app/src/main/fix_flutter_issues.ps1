# fix_flutter_issues.ps1
# PowerShell script to fix common Flutter analyze issues

# 1️⃣ Ensure we are in project root
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

# 2️⃣ Fix _isConnected type issue in home_screen.dart
$homeScreen = "lib\screens\home_screen.dart"
if (Test-Path $homeScreen) {
    (Get-Content $homeScreen) |
    ForEach-Object {
        $_ -replace "StreamSubscription<\[ConnectivityResult\]>","StreamSubscription<ConnectivityResult>" `
           -replace "\b_n(\s*=\s*ConnectivityResult.none)","_isConnected`$1"
    } | Set-Content $homeScreen
    Write-Host "✅ Fixed _isConnected type in home_screen.dart"
} else {
    Write-Host "⚠️ File not found: $homeScreen"
}

# 3️⃣ Fix deprecated withOpacity usage in reveal_splash_screen.dart
$splashScreen = "lib\screens\reveal_splash_screen.dart"
if (Test-Path $splashScreen) {
    (Get-Content $splashScreen) |
    ForEach-Object {
        $_ -replace "\.withOpacity\((.*?)\)","\.withValues\(0,0,0,$1\)"
    } | Set-Content $splashScreen
    Write-Host "✅ Replaced .withOpacity() with .withValues() in reveal_splash_screen.dart"
} else {
    Write-Host "⚠️ File not found: $splashScreen"
}

# 4️⃣ Ensure assets/images/ directory exists
$assetsDir = "assets/images/"
if (!(Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Force -Path $assetsDir
    Write-Host "✅ Created missing directory: $assetsDir"
} else {
    Write-Host "ℹ️ Directory already exists: $assetsDir"
}

# 5️⃣ Run flutter format and analyze to apply fixes
Write-Host "🔄 Running flutter format..."
flutter format .

Write-Host "🔄 Running flutter analyze..."
flutter analyze

Write-Host "🎉 Done! Check the analyze output above."
