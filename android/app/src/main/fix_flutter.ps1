# --- PowerShell Script to Fix Flutter Errors ---

# Path to your Flutter project
$projectPath = "C:\Users\Hezra\.vscode\flutter_application_1"

# 1️⃣ Fix 'n' typo in home_screen.dart
$homeScreen = Join-Path $projectPath "lib\screens\home_screen.dart"
(Get-Content $homeScreen) -replace ';\s*n\s*_isConnected', ';`r`n_isConnected' | Set-Content $homeScreen

Write-Host "✅ Fixed 'n' typo in home_screen.dart"

# 2️⃣ Replace withOpacity() with withValues() in reveal_splash_screen.dart
$splashScreen = Join-Path $projectPath "lib\screens\reveal_splash_screen.dart"
(Get-Content $splashScreen) | ForEach-Object {
    $_ -replace '\.withOpacity\((.*?)\)', '.withValues(alpha:$1)'
} | Set-Content $splashScreen

Write-Host "✅ Replaced .withOpacity() with .withValues() in reveal_splash_screen.dart"

# 3️⃣ Create missing assets/images folder
$assetsPath = Join-Path $projectPath "assets\images"
if (-not (Test-Path $assetsPath)) {
    New-Item -ItemType Directory -Force -Path $assetsPath | Out-Null
    Write-Host "✅ Created missing assets/images folder"
} else {
    Write-Host "ℹ assets/images folder already exists"
}

Write-Host "`n🎉 All fixes applied! You can now run 'flutter analyze' to check."
