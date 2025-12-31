<#
.SYNOPSIS
    Automates the installation and configuration of RustDesk.

.DESCRIPTION
    This script searches the current directory for the latest "rustdesk-*.exe",
    installs it, and subsequently configures server settings and the permanent password.
    It automatically enforces administrative privileges (elevation).

.PARAMETER ConfigString
    The configuration string (Base64), found in the RustDesk client under Settings > Network > ID/Relay Server.
    Can be set here as a default or passed during execution.

.PARAMETER Password
    The permanent password to be set for access.

.PARAMETER NoPause
    (Switch) Prevents the pause at the end of the script and suppresses the file selection prompt 
    (automatically selects the latest file). Ideal for software distribution/silent install.

.EXAMPLE
    .\Install-RustDesk.ps1
    Starts interactive mode. Asks for file confirmation, config, and password.

.EXAMPLE
    .\Install-RustDesk.ps1 -ConfigString "9JC...=" -Password "Secret123!"
    Installs with the specified values but waits for a key press at the end (for verification).

.EXAMPLE
    .\Install-RustDesk.ps1 -ConfigString "9JC...=" -Password "Secret123!" -NoPause
    Fully automatic installation without any user interaction (Silent Mode).
#>

# ==============================================================================================
# PARAMETERS (Default values can be entered here between the quotes)
# ==============================================================================================
param(
    [string]$ConfigString = "",   
    [string]$Password = "",       
    [switch]$NoPause              
)

# ==============================================================================================
# AUTO-ELEVATION (CHECK ADMIN RIGHTS & PASS PARAMETERS)
# ==============================================================================================

# Check if the script is running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Script is not running as Admin. Restarting with elevated privileges..." -ForegroundColor Yellow
    
    # Build arguments for restart
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    
    if (-not [string]::IsNullOrWhiteSpace($ConfigString)) {
        $argList += " -ConfigString `"$ConfigString`""
    }
    
    # Note: Password is passed in plain text to the new process here
    if (-not [string]::IsNullOrWhiteSpace($Password)) {
        $argList += " -Password `"$Password`""
    }
    
    # Pass switch parameter
    if ($NoPause) {
        $argList += " -NoPause"
    }

    Start-Process PowerShell -Verb RunAs -ArgumentList $argList
    Exit
}

# ==============================================================================================
# SCRIPT START
# ==============================================================================================

$scriptPath = $PSScriptRoot

# ---------------------------------------------------------
# 1. Search and select installer
# ---------------------------------------------------------
$installers = Get-ChildItem -Path $scriptPath -Filter "rustdesk-*.exe" | Sort-Object Name -Descending

if (-not $installers) {
    Write-Host "Error: No RustDesk installation file (rustdesk-*.exe) found!" -ForegroundColor Red
    if (-not $NoPause) { Pause }
    Exit
}

$selectedInstaller = $null

# Interactive selection only if NOT in Silent Mode (NoPause)
if ($NoPause) {
    $selectedInstaller = $installers | Select-Object -First 1
    Write-Host "Silent Mode active: Automatically selecting the newest installer: $($selectedInstaller.Name)" -ForegroundColor Cyan
} else {
    # Interactive prompt
    foreach ($installer in $installers) {
        Write-Host "Found file: $($installer.Name)" -ForegroundColor Cyan
        
        Write-Host "Should this file be installed? (y/n): " -ForegroundColor Yellow -NoNewline
        $confirmation = Read-Host
        
        # Changed to 'y' for English 'Yes'
        if ($confirmation -eq "y") {
            $selectedInstaller = $installer
            break 
        }
        Write-Host "Searching for next file..." -ForegroundColor Gray
        Write-Host "-----------------------------"
    }
}

if (-not $selectedInstaller) {
    Write-Host "No file selected for installation. Aborting." -ForegroundColor Yellow
    if (-not $NoPause) { Pause }
    Exit
}

# ---------------------------------------------------------
# 2. Check parameters and prompt if necessary
# ---------------------------------------------------------

# Config String Logic
if ([string]::IsNullOrWhiteSpace($ConfigString)) {
    # If Silent Mode is active but no ConfigString is present -> Warning
    if ($NoPause) {
        Write-Host "Warning: No Config-String passed (Silent Mode)." -ForegroundColor Yellow
    } else {
        Write-Host "Please enter RustDesk Config-String: " -ForegroundColor Yellow -NoNewline
        $ConfigString = Read-Host
    }
} else {
    Write-Host "Using passed Config-String." -ForegroundColor Cyan
}

# Password Logic
if ([string]::IsNullOrWhiteSpace($Password)) {
    if ($NoPause) {
        Write-Host "Warning: No Password passed (Silent Mode)." -ForegroundColor Yellow
    } else {
        Write-Host "Please enter the permanent RustDesk password (input is masked): " -ForegroundColor Yellow -NoNewline
        $securePass = Read-Host -AsSecureString
        $Password = [System.Net.NetworkCredential]::new("", $securePass).Password
    }
} else {
    Write-Host "Using passed Password." -ForegroundColor Cyan
}

# ---------------------------------------------------------
# 3. Start Installation
# ---------------------------------------------------------
Write-Host "`nStarting installation of $($selectedInstaller.Name)..." -ForegroundColor Green

# Start without -Wait
Start-Process -FilePath $selectedInstaller.FullName -ArgumentList "--silent-install"

# ---------------------------------------------------------
# 4. Wait for Service
# ---------------------------------------------------------
Write-Host "Waiting for 'RustDesk' service to start..." -NoNewline

$serviceName = "RustDesk"
$serviceRunning = $false
$maxRetries = 60 
$retryCount = 0

while (-not $serviceRunning) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    
    if ($service -and $service.Status -eq 'Running') {
        $serviceRunning = $true
        Write-Host " OK (Service running)" -ForegroundColor Green
    } else {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
        $retryCount++
        
        if ($retryCount -ge $maxRetries) {
            Write-Host "`nError: Timeout. Service did not start." -ForegroundColor Red
            if (-not $NoPause) { Pause }
            Exit
        }
    }
}

# ---------------------------------------------------------
# 5. Apply Configuration
# ---------------------------------------------------------
$targetPath = "C:\Program Files\RustDesk\rustdesk.exe"

if (Test-Path $targetPath) {
    Write-Host "Applying configurations..."
    
    if (-not [string]::IsNullOrWhiteSpace($ConfigString)) {
        Write-Host " -> Setting Server Configuration..."
        Start-Process -FilePath $targetPath -ArgumentList "--config $ConfigString" -Wait -NoNewWindow
    }

    Start-Sleep -Seconds 1

    if (-not [string]::IsNullOrWhiteSpace($Password)) {
        Write-Host " -> Setting Password..."
        Start-Process -FilePath $targetPath -ArgumentList "--password $Password" -Wait -NoNewWindow
    }
    
    Write-Host "`nDone! RustDesk has been installed and configured." -ForegroundColor Green
} else {
    Write-Host "Error: The file $targetPath was not found despite running service." -ForegroundColor Red
}

# Pause only if -NoPause was NOT set
if (-not $NoPause) {
    Pause
}