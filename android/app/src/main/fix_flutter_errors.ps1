# Fix Flutter Errors Script
# Run this script from your Flutter project root directory

Write-Host "Fixing Flutter errors..." -ForegroundColor Green

# Function to backup a file
function Backup-File {
    param($filePath)
    $backupPath = "$filePath.backup"
    Copy-Item $filePath $backupPath
    Write-Host "Backup created: $backupPath" -ForegroundColor Yellow
}

# 1. Fix ConnectivityResult error in home_screen.dart
$homeScreenPath = "lib\screens\home_screen.dart"
if (Test-Path $homeScreenPath) {
    Write-Host "Fixing ConnectivityResult error in home_screen.dart..." -ForegroundColor Cyan
    
    # Backup the file
    Backup-File $homeScreenPath
    
    # Read the content
    $content = Get-Content $homeScreenPath
    
    # Fix line 145 (adjust line number if needed)
    # Look for connectivityResult == ConnectivityResult.xxx pattern
    $fixedContent = @()
    for ($i = 0; $i -lt $content.Length; $i++) {
        $line = $content[$i]
        $lineNumber = $i + 1
        
        # Check if this is around line 145 and contains the pattern
        if ($lineNumber -ge 140 -and $lineNumber -le 150 -and $line -match "connectivityResult\s*(==|!=)\s*ConnectivityResult\.") {
            Write-Host "Found connectivity comparison at line $lineNumber" -ForegroundColor Yellow
            Write-Host "Before: $line" -ForegroundColor Gray
            
            # Replace == with .contains( and add closing )
            if ($line -match "connectivityResult\s*==\s*(ConnectivityResult\.\w+)") {
                $connectivityType = $matches[1]
                $line = $line -replace "connectivityResult\s*==\s*$connectivityType", "connectivityResult.contains($connectivityType)"
            }
            # Replace != with !.contains( and add closing )
            elseif ($line -match "connectivityResult\s*!=\s*(ConnectivityResult\.\w+)") {
                $connectivityType = $matches[1]
                $line = $line -replace "connectivityResult\s*!=\s*$connectivityType", "!connectivityResult.contains($connectivityType)"
            }
            
            Write-Host "After:  $line" -ForegroundColor Green
        }
        $fixedContent += $line
    }
    
    # Write the fixed content back
    $fixedContent | Set-Content $homeScreenPath
    Write-Host "Fixed ConnectivityResult error in home_screen.dart" -ForegroundColor Green
} else {
    Write-Host "Warning: home_screen.dart not found at $homeScreenPath" -ForegroundColor Red
}

# 2. Fix deprecated withOpacity error in reveal_splash_screen.dart
$revealScreenPath = "lib\screens\reveal_splash_screen.dart"
if (Test-Path $revealScreenPath) {
    Write-Host "`nFixing deprecated withOpacity error in reveal_splash_screen.dart..." -ForegroundColor Cyan
    
    # Backup the file
    Backup-File $revealScreenPath
    
    # Read the content
    $content = Get-Content $revealScreenPath
    
    # Fix line 298 (adjust line number if needed)
    $fixedContent = @()
    for ($i = 0; $i -lt $content.Length; $i++) {
        $line = $content[$i]
        $lineNumber = $i + 1
        
        # Check if this is around line 298 and contains .withOpacity(
        if ($lineNumber -ge 295 -and $lineNumber -le 305 -and $line -match "\.withOpacity\(") {
            Write-Host "Found deprecated withOpacity at line $lineNumber" -ForegroundColor Yellow
            Write-Host "Before: $line" -ForegroundColor Gray
            
            # Extract the color variable/expression before .withOpacity
            if ($line -match "(\w+|\S+)\s*\.withOpacity\(") {
                $colorExpression = $matches[1]
                
                # Handle different cases
                if ($colorExpression -match "^Colors\." -or $colorExpression -match "^Color\(") {
                    # Already starts with Colors. or Color(
                    $line = $line -replace "$colorExpression\.withOpacity\(", "Color($colorExpression.value).withOpacity("
                } elseif ($colorExpression -match "^\w+$") {
                    # Variable name
                    $line = $line -replace "$colorExpression\.withOpacity\(", "Color($colorExpression.value).withOpacity("
                } else {
                    # Complex expression, wrap in Color(expression.value)
                    $line = $line -replace "\.withOpacity\(", ".value).withOpacity("
                    $line = "Color($line"
                }
            }
            
            Write-Host "After:  $line" -ForegroundColor Green
        }
        $fixedContent += $line
    }
    
    # Write the fixed content back
    $fixedContent | Set-Content $revealScreenPath
    Write-Host "Fixed withOpacity error in reveal_splash_screen.dart" -ForegroundColor Green
} else {
    Write-Host "Warning: reveal_splash_screen.dart not found at $revealScreenPath" -ForegroundColor Red
}

# 3. Alternative: Create a more comprehensive fix script that searches the entire project
Write-Host "`nSearching for other potential withOpacity issues..." -ForegroundColor Cyan

# Find all Dart files in the project
$dartFiles = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse

foreach ($file in $dartFiles) {
    $content = Get-Content $file.FullName
    $foundIssues = $false
    
    for ($i = 0; $i -lt $content.Length; $i++) {
        $line = $content[$i]
        $lineNumber = $i + 1
        
        # Look for deprecated withOpacity pattern
        if ($line -match "\.withOpacity\(" -and $line -notmatch "Color\(.*\.value\)\.withOpacity\(") {
            if (-not $foundIssues) {
                Write-Host "`nFound potential withOpacity issues in $($file.Name):" -ForegroundColor Yellow
                $foundIssues = $true
            }
            Write-Host "  Line $lineNumber : $line" -ForegroundColor Gray
        }
    }
}

Write-Host "`nScript completed!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Run 'flutter analyze' to check if errors are fixed" -ForegroundColor White
Write-Host "2. If issues persist, restore from backup files and use manual fix" -ForegroundColor White
Write-Host "3. Backup files have .backup extension" -ForegroundColor White