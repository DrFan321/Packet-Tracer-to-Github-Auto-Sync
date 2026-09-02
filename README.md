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

## 1. Setup

1. First you want to move the scripts to a trusted scripts folder, in order to run the scripts without certificate verification.
2. Next you need to create an exception to this folder by running 
``` powershell
powershell.exe -NoExit -ExecutionPolicy Bypass -Command "Set-Location 'C:\path\to\folder'"
```
3. Change to the directory containing the scripts and run
``` powershell
.\Setup.ps1 -FolderPath "C:\path\to\save\files" -RepoUrl "https://github.com/YOURGITHUBUSERNAME/DESIREDNAMEOFREPO.git"
```
This setup script:
- Initializes git into the save folder
- Adds a `.gitignore` for Packet Tracer lock/temp filers
- Makes an initial commit and pushs it to the repository

YOU NEED TO HAVE A SAVE FILE IN THE FOLDER FOR THE SETUP SCRIPT TO MAKE A REPOSITORY

## 2. Watch the Save Folder

```powershell
.\Watch.ps1 -FolderPath "C:\path\to\save\files"
```

Leave the created PowerShell window open in the background. Every time you save a save file to the specified path, the script with commit and push the file to the repository automatically. You will see status messages in the PowerShell window.

Press `Ctrl+C` to stop watching.

### Optional parameters
- `-DebounceSeconds` - waits longer before syncing (use if you have a slower computer, internet connection, or are working with larger save files)
- `-Branch main` - change this if your default branch is named differently
- `-Extensions` - used to restrict automatic upload to certain file types

## 3. (Optional) Run automatically at login

1. Press `Win + R`, type `shell:startup`, and hit Enter.
2. Right click the folder and select to create a shortcut pointing to
  ```
   powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\path\to\Watch.ps1" -FolderPath "C:\path\to\save\files"
   ```
3. It will now start whenever you log in to windows.

