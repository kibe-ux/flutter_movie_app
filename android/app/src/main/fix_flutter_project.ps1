# ---------------------------
# Flutter Project Unlock & Setup
# ---------------------------

# Variables
$oldFolder = "C:\Users\Hezra\.vscode\block-puzzle"
$newFolderName = "block_puzzle"
$newParent = "C:\FlutterProjects"
$newFolder = Join-Path $newParent $newFolderName

# Step 1: Close VS Code / Antigravity if running
Get-Process | Where-Object { $_.Name -match "Code|Antigravity" } | Stop-Process -Force -ErrorAction SilentlyContinue

# Step 2: Create target parent folder if it doesn't exist
if (-Not (Test-Path $newParent)) {
    New-Item -ItemType Directory -Path $newParent
}

# Step 3: Move & rename project
Move-Item -Path $oldFolder -Destination $newFolder

# Step 4: Enter project folder
Set-Location $newFolder

# Step 5: Generate missing Flutter platforms
flutter create .

# Step 6: Clean & get dependencies
flutter clean
flutter pub get

Write-Host "✅ Project moved, renamed, and ready! Run 'flutter run' now."
