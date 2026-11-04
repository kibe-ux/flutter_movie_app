param(
    [ValidatePattern('^[a-z][a-z0-9-]{4,61}[a-z0-9]$')]
    [string]$ProjectId = 'my-flutter-app-hezra-202-12dc9',
    [string]$OutputDirectory = 'reports/firestore-security-2026-10-31',
    [ValidateSet('gcloud', 'firebase')]
    [string]$CredentialSource = 'gcloud'
)

$ErrorActionPreference = 'Stop'
$workspace = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$destination = [System.IO.Path]::GetFullPath((Join-Path $workspace $OutputDirectory))
if (-not $destination.StartsWith($workspace + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The export directory must be inside this workspace.'
}

# Use the existing CLI login. Never print or persist access tokens or headers.
if ($CredentialSource -eq 'firebase') {
    $firebaseDirectory = Split-Path (Get-Command firebase -ErrorAction Stop).Source -Parent
    $authModule = Join-Path $firebaseDirectory 'node_modules/firebase-tools/lib/auth.js'
    # The child writes only to this captured pipe; no CLI account/token JSON is
    # displayed or saved. Firebase's own library handles refresh and cache use.
    $tokenScript = @'
const auth = require(process.argv[1]);
const account = auth.getProjectDefaultAccount(process.argv[2]);
if (!account?.tokens?.refresh_token) process.exit(1);
auth.getAccessToken(account.tokens.refresh_token, [
  'https://www.googleapis.com/auth/cloud-platform',
  'https://www.googleapis.com/auth/firebase',
]).then((tokens) => process.stdout.write(tokens.access_token))
  .catch(() => { process.stderr.write('Firebase login could not be refreshed.'); process.exitCode = 1; });
'@
    $accessToken = (& node -e $tokenScript $authModule $workspace 2>$null | Out-String).Trim()
} else {
    $accessToken = (& gcloud auth print-access-token --quiet --verbosity=error 2>$null | Out-String).Trim()
}
if ($LASTEXITCODE -ne 0 -or -not $accessToken -or $accessToken.Contains("`n")) {
    throw 'Could not obtain an access token from the selected CLI login.'
}
$headers = @{ Authorization = 'Bearer ' + $accessToken }
$failedReads = 0
$results = @()
function Read-CloudJson([string]$Uri) {
    try {
        return Invoke-RestMethod -Method Get -Uri $Uri -Headers $headers -TimeoutSec 45
    } catch {
        $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'unavailable' }
        $detail = ''
        if ($_.ErrorDetails.Message) {
            try {
                $cloudError = $_.ErrorDetails.Message | ConvertFrom-Json
                $detail = [string]$cloudError.error.message
            } catch { $detail = 'No structured error details available.' }
        }
        if (-not $detail -and $_.Exception.Response) {
            try {
                $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                $body = $reader.ReadToEnd()
                $reader.Dispose()
                $detail = [string](($body | ConvertFrom-Json).error.message)
            } catch { $detail = 'No structured error details available.' }
        }
        throw "Read-only cloud request failed (HTTP $status): $Uri $detail"
    }
}

try {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    try {
    $release = Read-CloudJson "https://firebaserules.googleapis.com/v1/projects/$ProjectId/releases/cloud.firestore"
    if ($release.rulesetName -notmatch "^projects/$ProjectId/rulesets/[a-zA-Z0-9-]+$") {
        throw 'Unexpected ruleset reference returned by Firebase.'
    }
    $ruleset = Read-CloudJson ('https://firebaserules.googleapis.com/v1/' + $release.rulesetName)
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    $release | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $destination 'release.json') -Encoding UTF8
    $sourceFiles = @()
    $index = 0
    foreach ($file in $ruleset.source.files) {
        $localName = "deployed-$index.rules"
        [System.IO.File]::WriteAllText((Join-Path $destination $localName), [string]$file.content, [System.Text.UTF8Encoding]::new($false))
        $sourceFiles += @{ sourceName = $file.name; localName = $localName }
        $index++
    }
    @{
        projectId = $ProjectId
        exportedAtUtc = [DateTime]::UtcNow.ToString('o')
        rulesetName = $ruleset.name
        rulesetCreatedAt = $ruleset.createTime
        files = $sourceFiles
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $destination 'export.json') -Encoding UTF8
    Write-Output "Exported $index deployed Firestore rule source file(s)."
    $results += @{ resource = 'deployed-rules'; status = 'exported'; sourceFiles = $index }
    } catch {
        $failedReads++
        $results += @{ resource = 'deployed-rules'; status = 'failed'; error = $_.Exception.Message }
        @{ error = $_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'rules-export-error.json') -Encoding UTF8
        Write-Output $_.Exception.Message
    }
    foreach ($resource in @(
        @{ Name = 'releases'; Uri = "https://firebaserules.googleapis.com/v1/projects/$ProjectId/releases?pageSize=100" },
        @{ Name = 'databases'; Uri = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases" },
        @{ Name = 'indexes'; Uri = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/collectionGroups/-/indexes" },
        @{ Name = 'comment-fields'; Uri = "https://firestore.googleapis.com/v1/projects/$ProjectId/databases/(default)/collectionGroups/comments/fields?filter=indexConfig.usesAncestorConfig%3Afalse" }
    )) {
        try {
            $data = Read-CloudJson $resource.Uri
            $data | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $destination ($resource.Name + '.json')) -Encoding UTF8
            Write-Output ('Exported ' + $resource.Name + ' metadata.')
            $results += @{ resource = $resource.Name; status = 'exported'; hasMorePages = [bool]$data.nextPageToken }
            if ($data.nextPageToken) {
                $failedReads++
                Write-Output ('More pages exist for ' + $resource.Name + '; this export is incomplete.')
            }
        } catch {
            $failedReads++
            $results += @{ resource = $resource.Name; status = 'failed'; error = $_.Exception.Message }
            @{ error = $_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination ($resource.Name + '-error.json')) -Encoding UTF8
            Write-Output $_.Exception.Message
        }
    }
} finally {
    $headers.Clear()
    $accessToken = $null
    @{
        projectId = $ProjectId
        checkedAtUtc = [DateTime]::UtcNow.ToString('o')
        credentialSource = $CredentialSource
        complete = ($failedReads -eq 0)
        requests = $results
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $destination 'attempt.json') -Encoding UTF8
}
if ($failedReads -gt 0) { exit 1 }
