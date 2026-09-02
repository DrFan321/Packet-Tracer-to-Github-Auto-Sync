
param(
    [Parameter(Mandatory = $true)]
    [string]$FolderPath,

    [string]$Branch = "main",

    [int]$DebounceSeconds = 15,

    [string[]]$Extensions = @("pkt", "pka", "pkz")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $FolderPath)) {
    Write-Host "Folder does not exist: $FolderPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path (Join-Path $FolderPath ".git"))) {
    Write-Host "No git repo found in $FolderPath. Run Setup-PTSync.ps1 first." -ForegroundColor Red
    exit 1
}

Set-Location $FolderPath

$script:lastChangeTime = Get-Date
$script:pendingChange = $false
$script:lock = New-Object object

function Do-Sync {
    Set-Location $FolderPath

    $status = git status --porcelain
    if (-not $status) {
        return
    }

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Changes detected, syncing..." -ForegroundColor Yellow

    git add -A

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $filesChanged = ($status | Measure-Object).Count
    git commit -m "Auto-sync: $timestamp ($filesChanged file(s) changed)" | Out-Null

    try {
        git push origin $Branch 2>&1 | Out-Null
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Pushed to GitHub successfully." -ForegroundColor Green
    } catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Push failed - will retry on next change. Error: $_" -ForegroundColor Red
    }
}

$extList = ($Extensions -join ", ")
Write-Host "Watching: $FolderPath" -ForegroundColor Cyan
Write-Host "Extensions: $extList" -ForegroundColor Cyan
Write-Host "Debounce: $DebounceSeconds seconds" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop." -ForegroundColor Cyan
Write-Host ""

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $FolderPath
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor `
                        [System.IO.NotifyFilters]::FileName -bor `
                        [System.IO.NotifyFilters]::DirectoryName

$action = {
    $path = $Event.SourceEventArgs.FullPath
    $ext = [System.IO.Path]::GetExtension($path).TrimStart(".")

    if ($path -match '\\\.git\\') { return }

    $watchExts = $Event.MessageData
    if ($watchExts.Count -gt 0 -and ($watchExts -notcontains $ext)) { return }

    $global:lastChangeTime = Get-Date
    $global:pendingChange = $true
}

Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action -MessageData $Extensions | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action -MessageData $Extensions | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action -MessageData $Extensions | Out-Null

$global:lastChangeTime = Get-Date
$global:pendingChange = $false

try {
    while ($true) {
        Start-Sleep -Seconds 2

        if ($global:pendingChange) {
            $secondsSinceChange = (Get-Date) - $global:lastChangeTime
            if ($secondsSinceChange.TotalSeconds -ge $DebounceSeconds) {
                $global:pendingChange = $false
                Do-Sync
            }
        }
    }
} finally {
    Get-EventSubscriber | Unregister-Event
    $watcher.Dispose()
    Write-Host "Watcher stopped." -ForegroundColor Cyan
}
