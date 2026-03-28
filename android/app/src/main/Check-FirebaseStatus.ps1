# =============================
# Firebase Emulator Status + Restart Script
# =============================

# Paths
$projectRoot = "C:\Users\Hezra\.vscode\block_puzzle"
$functionsPath = "$projectRoot\functions"
$hostingPath = "$projectRoot\public"

# Ports
$functionsPort = 5000
$hostingPort = 5001
$uiPort = 4000

# Node check
$nodeVersion = node -v
Write-Host "Node version: $nodeVersion"

# Check Functions folder
if ((Test-Path $functionsPath) -and (Test-Path "$functionsPath\package.json") -and (Test-Path "$functionsPath\index.js")) {
    $functionsStatus = "✅ Functions folder exists and ready"
} else {
    $functionsStatus = "❌ Functions folder missing or incomplete"
}

# Check node_modules
if (Test-Path "$functionsPath\node_modules") {
    $modulesStatus = "✅ Dependencies installed"
} else {
    $modulesStatus = "⚠️ Dependencies not installed. Run 'npm install'"
}

# Check Hosting folder
if (Test-Path $hostingPath) {
    $hostingStatus = "✅ Hosting folder exists"
} else {
    $hostingStatus = "⚠️ Hosting folder missing"
}

# Check if ports are free
function Test-Port($port) {
    $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($conn) { return $false } else { return $true }
}

$functionsPortFree = Test-Port $functionsPort
$hostingPortFree = Test-Port $hostingPort
$uiPortFree = Test-Port $uiPort

# Report
Write-Host "`n--- Firebase Project Status ---`n"
Write-Host $functionsStatus
Write-Host $modulesStatus
Write-Host $hostingStatus
Write-Host "Functions Emulator port $functionsPort: " + ($(if ($functionsPortFree) {"Free"} else {"Occupied"}))
Write-Host "Hosting Emulator port $hostingPort: " + ($(if ($hostingPortFree) {"Free"} else {"Occupied"}))
Write-Host "Emulator UI port $uiPort: " + ($(if ($uiPortFree) {"Free"} else {"Occupied"}))

# Ask user if they want to start/restart emulators
$startEmu = Read-Host "`nDo you want to start/restart Firebase emulators? (y/n)"
if ($startEmu -eq "y") {
    Write-Host "`nStopping any existing emulator processes..."
    
    # Kill Firebase emulators if running
    $emuPIDs = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -like "*firebase*"
    } | Select-Object -ExpandProperty Id

    if ($emuPIDs) {
        $emuPIDs | ForEach-Object { Stop-Process -Id $_ -Force }
        Start-Sleep -Seconds 2
        Write-Host "Old emulator processes stopped."
    } else {
        Write-Host "No old emulator processes found."
    }

    Write-Host "Starting Firebase emulators..."
    Push-Location $projectRoot
    Start-Process powershell -ArgumentList "firebase emulators:start" -NoNewWindow
    Pop-Location
}
