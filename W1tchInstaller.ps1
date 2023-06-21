




# Check if the script is running with administrator privileges

Write-Host "Checking for administrator privileges..."
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Relaunch the script with administrator privileges
    Write-Host "Launching as Administrator..."
    Start-Process powershell.exe "-File `"$PSCommandPath`"" -Verb RunAs
    Exit
}
Clear-Host
Write-Host -ForegroundColor Blue "----------------------------------------------------------------------------------------------------------------- `n"
$asciiArt = @'
Y8b Y8b Y888P   d88   d8            888     
 Y8b Y8b Y8P   d888  d88    e88'888 888 ee  
  Y8b Y8b Y   d"888 d88888 d888  '8 888 88b 
   Y8b Y8b      888  888   Y888   , 888 888 
    Y8P Y       888  888    "88,e8' 888 888 


'@
Write-Host -ForegroundColor Magenta -NoNewline $asciiArt
Write-host -ForegroundColor Magenta "W1tch Auto Installer"
Write-Host -ForegroundColor Magenta "By voidshaman"
Write-Host -ForegroundColor Blue -NoNewline "Purchase your Dis2rbed License at "
Write-Host -ForegroundColor Red  "https://v0id.pw"
Write-Host -ForegroundColor Blue "`n-----------------------------------------------------------------------------------------------------------------"

Write-Host "`n"

# Define variables
$DownloadURL = "https://w1tch.net/files/file/1-w1tch-launcher/"
$InstallPath = "C:\W1tch"
$ZipFileName = "WLauncher.zip"
$LauncherName = "WLauncher.exe"
$UserAgent = "v0id.pw"
$OutputDirectory = "$env:TEMP\W1tchAutoInstall"
$ZipPath = "$OutputDirectory\$ZipFileName"
$Dependencies = @(
    "C:\Windows\System32\msvcp140.dll", 
    "C:\Program Files\dotnet\dotnet.exe"
)
$DependenciesURL = @(
    "https://aka.ms/vs/16/release/vc_redist.x64.exe", 
    "https://download.visualstudio.microsoft.com/download/pr/b70ad520-0e60-43f5-aee2-d3965094a40d/667c122b3736dcbfa1beff08092dbfc3/dotnet-sdk-3.1.426-win-x64.exe"
)
#Creating temp directory
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
}

function Test-Dependencies {
    Write-Host "Checking for dependencies..."
    for ($i = 0; $i -lt $Dependencies.Count; $i++) {
        $dep = $Dependencies[$i]
        if (-not (Test-Path $dep)) {
            Write-Host -NoNewline "$dep is not installed. Do you want to install it? [Y/N]:"
            $response = Read-Host
            if ($response -eq "Y") {
                
                Start-BitsTransfer -Source $DependenciesURL[$i] -Destination "$OutputDirectory\dep$i.exe"
                Start-Process -Wait -FilePath "$OutputDirectory\dep$i.exe" -ArgumentList '/norestart'
                
                # Check for dotnet.exe
                if ($dep -eq "C:\Program Files\dotnet\dotnet.exe") {
                    if (-not (Test-Path $dep)) {
                        # Look for dotnet.7z
                        if (Test-Path "C:\Program Files\dotnet\dotnet.7z") {
                            # Check if 7Zip4Powershell module is installed
                            if (-not (Get-Module -ListAvailable -Name 7Zip4Powershell)) {
                                Write-Host -NoNewline "7Zip4Powershell is not installed.`n 7Zip4Powershell is a safe software made to unzip 7zip files with Powershell (https://github.com/thoemmi/7Zip4Powershell) `n Do you want to install it? [Y/N]:"
                                $response = Read-Host
                                if ($response -eq "Y") {
                                    Install-Module -Name 7Zip4Powershell -Scope CurrentUser
                                }
                                else {
                                    Write-Host "Continuing without installing 7Zip4Powershell..."
                                    return $false
                                }
                            }
                            # Extract dotnet.7z
                            if (Get-Module -ListAvailable -Name 7Zip4Powershell) {
                                Write-Host "Extracting dotnet.7z..."
                                Expand-7Zip "C:\Program Files\dotnet\dotnet.7z" "C:\Program Files\dotnet"
                            }
                        }
                    }
                }
            }
            else {
                Write-Host "Continuing without installing $dep..."
            }
        }
        else {
            Write-Host " > $dep\: [OK]"
        }
    }Write-Host -ForegroundColor Green "`nDependencies check complete. `n "
}

function Create-Shortcut {
    param (
        [string]$TargetPath,
        [string]$ShortcutPath
    )

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.Save()

    $bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20 # Set byte 21 (0x15) bit 6 (0x20) ON
    [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)
}
function Get-Software {

    # Check if the software is already installed
    if (Test-Path "C:\W1tch\WLauncher.dll") {
        Write-Host -NoNewline "The software is already installed. Do you wish to reinstall? This will delete C:W1tch. [Y/N]:"
        $response = Read-Host
        if ($response -eq "N") {
            return $true
        }
        else {
            # Remove existing installation
            try {
                Write-Host -ForegroundColor Gray "`nRemoving existing installation..."
                Remove-Item "C:\W1tch" -Recurse -Force
                Write-Host -ForegroundColor Green "`nW1tch Launcher has been removed."
            }
            catch {
                Write-Host "`nError deleting old installation: $_. Exiting..."
                return $false
            }
        }
    }

    # Add Windows Defender exclusions if applicable
    Write-Host "`nChecking for Windows Defender exclusions"
    $ExistingExclusions = Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
    if ($ExistingExclusions -contains $InstallPath) {
        Write-Host -ForegroundColor Green "> Exclusions:  [OK]"
    }
    else {
        # Check if Windows Defender is the active antivirus service
        $defenderStatus = Get-MpComputerStatus
        if ($defenderStatus.AMServiceEnabled) {
            $NewExclusions = @(
                "$InstallPath",
                "$InstallPath\*",
                "$InstallPath\WLauncher.exe",
                "$InstallPath\WLauncher.dll"
            )
            Write-Host "Adding exclusions for Windows Defender..."
            try {
                $AllExclusions = $ExistingExclusions + $NewExclusions
                Set-MpPreference -ExclusionPath $AllExclusions
            }
            catch {
                Write-Host "Error adding exclusions: $_. Moving on..."
            }
        }
        else {
            Write-Host "Windows Defender is not the active antivirus service. Checking for other antivirus services..."
    
            $antivirusProduct = Get-WmiObject -Namespace "root\SecurityCenter2" -Class "AntivirusProduct"
            $avName = $antivirusProduct.displayName
            Write-Host "Antivirus software detected: $avName"
            Write-Host "Skipping exclusion addition as we cannot determine your active antivirus software. 
        `nYou can find instructions on how to add exclusions for your antivirus software here: 
        `nhttps://www.google.com/search?q=add+exclusion+$avName" 
            Write-Host -ForegroundColor Red -BackgroundColor Black "This is a crucial step to ensure that the software works properly."
        
        }
    }

    

    # Download the zip file to a temporary directory
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    }

    Write-Host "Downloading software. Be patient, this might take a while depending on your geolocation `n "
    try {
        $cli = New-Object System.Net.WebClient
        $cli.Headers['User-Agent'] = $UserAgent
        $pageContent = $cli.DownloadString($DownloadURL)
        $cookies = $cli.ResponseHeaders['Set-Cookie']
        $datePattern = [Regex]::new('https.+download.+csrfKey=[a-z0-9]{32}')
        $matche = $datePattern.Match($pageContent)
        $download = New-Object System.Net.WebClient
        $download.Headers['User-Agent'] = $UserAgent
        $download.Headers['Cookie'] = $cookies
        $url = $matche.Value.Replace('amp;', '')
        
        $download.DownloadFile($url, $ZipPath)
        if (Test-Path $ZipPath) {
            Write-Host "Download succeeded."
        }
        else {
            Write-Host "Download failed."
            return $false
        }
    }
    catch {
        Write-Host "Error downloading file: $_."
        return $false
    }
  
    # Extract the contents of the zip file to the installation directory
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Write-Host "Extracting files..."
    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipPath, $InstallPath)
        
    }
    catch {
        Write-Host "Error extracting files: $_. Exiting..."
        Pause
        Exit
    }
    Write-Host "Extraction succeeded. W1tch Launcher is now installed."
    # Prompt the user if they would like to create a shortcut
    Write-Host -NoNewline "Do you want to create a desktop shortcut? [Y/N]: "
    $response = Read-Host
    if ($response -eq "Y") {
        $DesktopPath = [Environment]::GetFolderPath("Desktop")
        $ShortcutPath = Join-Path -Path $DesktopPath -ChildPath "WLauncher.lnk"
        $TargetPath = Join-Path -Path $InstallPath -ChildPath $LauncherName
        Create-Shortcut -TargetPath $TargetPath -ShortcutPath $ShortcutPath
        Write-Host -ForegroundColor Green "Shortcut created"
        return $true
    }
    else {
        Write-Host "Have Fun :D"
    }
}


# Check for dependencies
Test-Dependencies

Write-Host -NoNewline "Do you want to download and Install the W1tch Launcher? [Y/N]: "
$response = Read-Host
if ($response -eq "Y") {
    if (-not (Get-Software)) {
        Write-Host "Exiting..."
        Pause
        Exit
    }
}
else {
    Write-Host "Exiting..."
    Pause
    Exit
}

# Run the launcher
Write-Host "Launching software..."
try {
    Start-Process "$InstallPath\$LauncherName" -WorkingDirectory $InstallPath
}
catch {
    Write-Host "Error launching software: $_. Exiting..."
    Pause
    Exit
}

# Clean up temporary files
Write-Host "Cleaning up temporary files..."
try {
    Remove-Item $OutputDirectory -Recurse -Force
}
catch {
    Write-Host "Error cleaning up temporary files: $_. Moving on..."
}

# Pause before exiting
Pause