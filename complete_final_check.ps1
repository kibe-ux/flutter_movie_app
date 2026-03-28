Write-Host "=== FINAL COMPREHENSIVE BUILD CHECK ===" -ForegroundColor Cyan
Write-Host "Checking ALL previously reported issues..." -ForegroundColor Cyan

$allPassed = $true
$issuesFound = @()

# Check compileSdk in build.gradle
Write-Host "`n[1] Checking compileSdk..." -ForegroundColor Yellow
$gradlePath = "android\app\build.gradle"
if (Test-Path $gradlePath) {
    $gradleContent = Get-Content $gradlePath -Raw
    if ($gradleContent -match 'compileSdk\s*=\s*36') {
        Write-Host "   ✅ compileSdk = 36" -ForegroundColor Green
    } else {
        Write-Host "   ❌ compileSdk NOT set to 36" -ForegroundColor Red
        $allPassed = $false
        $issuesFound += "compileSdk not set to 36"
        
        # Show current value
        if ($gradleContent -match 'compileSdk\s*=\s*(\d+)') {
            Write-Host "   Current value: $($matches[1])" -ForegroundColor Yellow
        } else {
            Write-Host "   No compileSdk found!" -ForegroundColor Red
        }
    }
} else {
    Write-Host "   ❌ build.gradle not found!" -ForegroundColor Red
    $allPassed = $false
    $issuesFound += "Missing build.gradle"
}

# Check for duplicate build.gradle.kts
Write-Host "`n[2] Checking for duplicate build files..." -ForegroundColor Yellow
$ktsPath = "android\app\build.gradle.kts"
if (Test-Path $ktsPath) {
    Write-Host "   ❌ Duplicate file still exists: build.gradle.kts" -ForegroundColor Red
    $allPassed = $false
    $issuesFound += "Duplicate build.gradle.kts file exists"
} else {
    Write-Host "   ✅ No duplicate build file" -ForegroundColor Green
}

# Quick build test
if ($allPassed) {
    Write-Host "`n[3] Testing build (this may take a minute)..." -ForegroundColor Yellow
    $buildStartTime = Get-Date
    $buildOutput = flutter build apk --debug 2>&1
    $buildDuration = (Get-Date) - $buildStartTime
    $buildTime = "$([math]::Round($buildDuration.TotalSeconds, 1)) seconds"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ BUILD SUCCESSFUL in $buildTime" -ForegroundColor Green
        
        # Check APK file
        $apkPath = "build\app\outputs\flutter-apk\app-debug.apk"
        if (Test-Path $apkPath) {
            $apkSize = (Get-Item $apkPath).Length / 1MB
            Write-Host "   📦 APK size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Gray
        }
    } else {
        Write-Host "   ❌ BUILD FAILED after $buildTime" -ForegroundColor Red
        
        # Check for specific errors
        $sdkError = $buildOutput | Select-String -Pattern "requires.*SDK|compiles against.*SDK"
        $shaderError = $buildOutput | Select-String -Pattern "Could not write file|Shader compilation|impellerc"
        
        if ($sdkError) {
            Write-Host "   Issue: SDK version mismatch" -ForegroundColor Red
            $issuesFound += "SDK version mismatch"
            $sdkError | ForEach-Object { Write-Host "      $($_.Line)" -ForegroundColor Red }
        } elseif ($shaderError) {
            Write-Host "   Issue: Shader compilation error" -ForegroundColor Red
            $issuesFound += "Shader compilation failed"
            $shaderError | ForEach-Object { Write-Host "      $($_.Line)" -ForegroundColor Red }
        } else {
            Write-Host "   Last 5 lines of output:" -ForegroundColor Gray
            $buildOutput | Select-Object -Last 5 | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
        }
    }
} else {
    Write-Host "`n[3] Skipping build test due to configuration errors" -ForegroundColor Yellow
}

# Final summary
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Host "FINAL SUMMARY" -ForegroundColor Cyan
Write-Host "="*50 -ForegroundColor Cyan

if ($allPassed -and $issuesFound.Count -eq 0) {
    Write-Host "🎉 ALL CHECKS PASSED!" -ForegroundColor Green
    Write-Host "   Your app should now build and run successfully." -ForegroundColor Green
    Write-Host "`n🚀 Try running: flutter run" -ForegroundColor Cyan
} else {
    Write-Host "❌ ISSUES FOUND ($($issuesFound.Count) total)" -ForegroundColor Red
    
    if ($issuesFound.Count -gt 0) {
        Write-Host "`nISSUES TO FIX:" -ForegroundColor Red
        for ($i = 0; $i -lt $issuesFound.Count; $i++) {
            Write-Host "   $($i+1). $($issuesFound[$i])" -ForegroundColor Red
        }
    }
    
    if ($issuesFound -contains "compileSdk not set to 36") {
        Write-Host "`n🔧 To fix compileSdk:" -ForegroundColor Yellow
        Write-Host "   1. Open android/app/build.gradle" -ForegroundColor Gray
        Write-Host "   2. Change compileSdk to 36" -ForegroundColor Gray
        Write-Host "   3. Save the file" -ForegroundColor Gray
    }
    
    if ($issuesFound -contains "Duplicate build.gradle.kts file exists") {
        Write-Host "`n🔧 To fix duplicate file:" -ForegroundColor Yellow
        Write-Host "   1. Delete android/app/build.gradle.kts" -ForegroundColor Gray
    }
}

Write-Host "`n=== CHECK COMPLETE ===" -ForegroundColor Cyan
