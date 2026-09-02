# Packet Tracer to GitHub Auto-Sync

Automatically commits and pushed your Packet Tracer save files to a GitHub repository whenever you save.

## Requirements
- Windows
- [Git for Windows](https://git-scm.com/download/win) installed
- A GitHub account + an empty repository created for your save files
- Git authenticated on this machine (either via [GitHub CLI](https://cli.github.com/) `gh auth login`, [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager) (comes bundled with Git for Windows and is usually already set up), or an SSH key)

## Files
- `Setup.ps1` - run to initialize the repository and link it to GitHub
- `Watch.ps1` - run to watch the save folder and upload save files to the repository
