<#
.SYNOPSIS
    Watches a folder for Packet Tracer file changes and auto-commits/pushes to GitHub.

.DESCRIPTION
    Uses FileSystemWatcher to detect changes to .pkt / .pka files (and any other
    files in the folder). Debounces rapid-fire save events (Packet Tracer often
    writes temp files during a save) and pushes a batch commit after a quiet period.

    Leave this running in a PowerShell window (or set it up as a scheduled task /
    startup script - see notes at the bottom) while you work in Packet Tracer.

.EXAMPLE
    .\Watch-PTSync.ps1 -FolderPath "C:\Users\you\Documents\Packet Tracer"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FolderPath,

    [string]$Branch = "main",

    # Seconds to wait after the last detected change before committing/pushing.
    # Prevents spamming commits while Packet Tracer is mid-write.
    [int]$DebounceSeconds = 15,

    # Only watch these extensions (comma separated, no dot needed)
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

# Shared state for debounce logic
$script:lastChangeTime = Get-Date
$script:pendingChange = $false
$script:lock = New-Object object

function Do-Sync {
    Set-Location $FolderPath

    # Check if there's actually anything to commit
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

# Build filter description for logging
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

    # Ignore git internals and the .gitignore file itself
    if ($path -match '\\\.git\\') { return }

    # Only react to our target extensions (or any file, if Extensions is empty)
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
