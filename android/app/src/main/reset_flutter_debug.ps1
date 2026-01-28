# ===============================
# Flutter + VS Code Full Reset Script
# ===============================

# --- Project path (change if needed) ---
$projectPath = "C:\Users\Hezra\.vscode\flutter_application_1"

# --- Kill stuck processes ---
Write-Host "Killing VS Code, Dart, and Flutter processes..."
taskkill /F /IM Code.exe > $null 2>&1
taskkill /F /IM dart.exe > $null 2>&1
taskkill /F /IM flutter.exe > $null 2>&1

# --- Reset VS Code UI ---
$settingsPath = "$env:APPDATA\Code\User\settings.json"
if (-Not (Test-Path $settingsPath)) {
    New-Item -ItemType File -Path $settingsPath -Force
    '{}' | Out-File -Encoding UTF8 $settingsPath
}

$json = Get-Content $settingsPath -Raw | ConvertFrom-Json

# Restore UI elements
$json."workbench.statusBar.visible" = $true
$json."workbench.activityBar.visible" = $true
$json."workbench.sideBar.location" = "left"
$json."workbench.panel.defaultLocation" = "bottom"
$json."workbench.panel.opensMaximized" = $false
$json."workbench.editor.showTabs" = $true

# Save changes
$json | ConvertTo-Json -Depth 100 | Set-Content $settingsPath -Encoding UTF8

# --- Clean Flutter project ---
Write-Host "Cleaning Flutter project..."
cd $projectPath
flutter clean
flutter pub get

# --- Open VS Code ---
Write-Host "Opening VS Code..."
Start-Process code $projectPath

# --- Optional: run Flutter debug in terminal ---
Write-Host "Starting Flutter debug (terminal)..."
flutter run --debug
