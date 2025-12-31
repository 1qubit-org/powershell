# RustDesk Installation Script

This PowerShell script automates the installation and configuration of the RustDesk remote desktop client.

## Features

- **Automatic Detection:** Searches the current directory for the latest `rustdesk-*.exe`.
- **Auto-Elevation:** Automatically requests administrative privileges if not already running as admin.
- **Silent Install:** Supports fully automated installation without user interaction.
- **Configuration:** Optionally sets the ID/Relay server string and a permanent password.
- **Service Monitoring:** Intelligently waits for the RustDesk service to start before applying configurations.

## Usage

### Parameters

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `-ConfigString` | String | The Base64 configuration string (found under Settings > Network > ID/Relay Server). |
| `-Password` | String | The permanent password to be set for access. |
| `-NoPause` | Switch | Prevents the pause at the end and suppresses the interactive file selection (automatically selects the latest file). Ideal for silent installations. |

### Examples

**1. Interactive Mode**
Starts the script in interactive mode. Asks for file confirmation, config string, and password.
```powershell
.\rustdesk-install_en.ps1
```

**2. With Parameters (Semi-Automated)**
Installs with the specified values but waits for a key press at the end for verification.
```powershell
.\rustdesk-install_en.ps1 -ConfigString "9JC...=" -Password "Secret123!"
```

**3. Silent Mode (Fully Automated)**
Fully automatic installation without any user interaction. The script automatically selects the latest installer file.
```powershell
.\rustdesk-install_en.ps1 -ConfigString "9JC...=" -Password "Secret123!" -NoPause
```

## Requirements

- Windows PowerShell 5.1 or higher
- A `rustdesk-*.exe` installation file in the same directory as the script.
