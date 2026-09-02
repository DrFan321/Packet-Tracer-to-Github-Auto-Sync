<#
.SYNOPSIS
    One-time setup: initializes a git repo in your Packet Tracer save folder
    and connects it to a GitHub remote.

.DESCRIPTION
    Run this ONCE before using Watch-PTSync.ps1.
    It will:
      - Check that git is installed
      - Init a git repo in the target folder (if not already one)
      - Add a .gitignore for Packet Tracer temp/lock files
      - Set the GitHub remote
      - Do an initial commit + push

.EXAMPLE
    .\Setup-PTSync.ps1 -FolderPath "C:\Users\you\Documents\Packet Tracer" -RepoUrl "https://github.com/yourname/packet-tracer-labs.git"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FolderPath,

    [Parameter(Mandatory = $true)]
    [string]$RepoUrl,

    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host "==> $msg" -ForegroundColor Cyan
}

# 1. Check git is installed
try {
    git --version | Out-Null
} catch {
    Write-Host "Git is not installed or not on PATH. Install it from https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}

# 2. Validate folder
if (-not (Test-Path $FolderPath)) {
    Write-Host "Folder does not exist: $FolderPath" -ForegroundColor Red
    exit 1
}

Set-Location $FolderPath
Write-Step "Working in $FolderPath"

# 3. Init repo if needed
if (-not (Test-Path ".git")) {
    Write-Step "Initializing git repository"
    git init | Out-Null
    git checkout -b $Branch | Out-Null
} else {
    Write-Step "Git repository already exists here"
}

# 4. .gitignore for Packet Tracer noise
$gitignorePath = Join-Path $FolderPath ".gitignore"
$gitignoreContent = @"
# Packet Tracer temp/lock/autosave files
*.pkt.lock
*.pka.lock
~`$*
*.tmp
Thumbs.db
"@

if (-not (Test-Path $gitignorePath)) {
    Write-Step "Creating .gitignore"
    Set-Content -Path $gitignorePath -Value $gitignoreContent -Encoding UTF8
} else {
    Write-Step ".gitignore already exists, leaving it alone"
}

# 5. Set remote
$existingRemote = git remote 2>$null
if ($existingRemote -contains "origin") {
    Write-Step "Remote 'origin' already set, updating URL"
    git remote set-url origin $RepoUrl
} else {
    Write-Step "Adding remote 'origin' -> $RepoUrl"
    git remote add origin $RepoUrl
}

# 6. Initial commit
Write-Step "Staging files"
git add -A

$hasCommits = git log --oneline -1 2>$null
if (-not $hasCommits) {
    Write-Step "Creating initial commit"
    git commit -m "Initial commit: Packet Tracer files" | Out-Null
} else {
    git commit -m "Sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null | Out-Null
}

# 7. Push
Write-Step "Pushing to GitHub (you may be prompted to sign in / auth)"
git push -u origin $Branch

Write-Host ""
Write-Host "Setup complete! Now run Watch-PTSync.ps1 to start auto-syncing." -ForegroundColor Green
