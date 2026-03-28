$root = "lib"

Get-ChildItem -Path $root -Recurse -Filter "*.dart" | ForEach-Object {
    $path = $_.FullName
    $content = Get-Content $path -Raw
    $updated = $content

    # Fix withOpacity deprecation
    $updated = $updated -replace `
        '\.withOpacity\(\s*([0-9]*\.?[0-9]+)\s*\)', `
        '.withValues(alpha: $1)'

    # Fix ConnectivityResult list comparison
    $updated = $updated -replace `
        'final connectivityResult = await Connectivity\(\)\.checkConnectivity\(\);\s*\n\s*_isConnected\s*=\s*connectivityResult\s*!=\s*ConnectivityResult\.none;',
        'final connectivityResult = await Connectivity().checkConnectivity();`n    _isConnected = !connectivityResult.contains(ConnectivityResult.none);'

    if ($content -ne $updated) {
        Set-Content -Path $path -Value $updated -Encoding UTF8
        Write-Host "✔ Fixed:" $path
    }
}
