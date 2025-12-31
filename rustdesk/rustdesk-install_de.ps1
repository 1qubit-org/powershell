<#
.SYNOPSIS
    Automatisiert die Installation und Konfiguration von RustDesk.

.DESCRIPTION
    Dieses Script sucht im aktuellen Verzeichnis nach der neuesten "rustdesk-*.exe",
    installiert diese und konfiguriert anschließend Server-Einstellungen und das permanente Passwort.
    Es erzwingt automatisch Administratorrechte (Elevation).

.PARAMETER ConfigString
    Der Konfigurations-String (Base64), zu finden im RustDesk Client unter Einstellungen > Netzwerk > ID/Relay Server.
    Kann hier als Default-Wert eingetragen oder beim Aufruf übergeben werden.

.PARAMETER Password
    Das permanente Passwort, das für den Zugriff gesetzt werden soll.

.PARAMETER NoPause
    (Switch) Verhindert die Pause am Ende des Scripts und unterdrückt die Frage nach der Dateiauswahl 
    (wählt automatisch die neuste Datei). Ideal für Softwareverteilung/Silent-Install.

.EXAMPLE
    .\Install-RustDesk.ps1
    Startet den interaktiven Modus. Fragt nach Datei-Bestätigung, Config und Passwort.

.EXAMPLE
    .\Install-RustDesk.ps1 -ConfigString "7KC...=" -Password "Geheim123!"
    Installiert mit den angegebenen Werten, wartet am Ende aber auf Tastendruck (zur Kontrolle).

.EXAMPLE
    .\Install-RustDesk.ps1 -ConfigString "7KC...=" -Password "Geheim123!" -NoPause
    Vollautomatische Installation ohne jegliche Benutzerinteraktion (Silent Mode).
#>

# ==============================================================================================
# PARAMETER (Hier können Default-Werte zwischen die Anführungszeichen eingetragen werden)
# ==============================================================================================
param(
    [string]$ConfigString = "",   
    [string]$Password = "",       
    [switch]$NoPause              
)

# ==============================================================================================
# AUTO-ELEVATION (ADMIN RECHTE PRÜFEN & PARAMETER WEITERREICHEN)
# ==============================================================================================

# Prüfen, ob das Script als Administrator läuft
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Script läuft nicht als Admin. Starte neu mit erhöhten Rechten..." -ForegroundColor Yellow
    
    # Argumente für den Neustart zusammenbauen
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    
    if (-not [string]::IsNullOrWhiteSpace($ConfigString)) {
        $argList += " -ConfigString `"$ConfigString`""
    }
    
    # Hinweis: Passwort wird hier im Klartext an den neuen Prozess übergeben
    if (-not [string]::IsNullOrWhiteSpace($Password)) {
        $argList += " -Password `"$Password`""
    }
    
    # Switch-Parameter weiterreichen
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
# 1. Installer suchen und auswählen
# ---------------------------------------------------------
$installers = Get-ChildItem -Path $scriptPath -Filter "rustdesk-*.exe" | Sort-Object Name -Descending

if (-not $installers) {
    Write-Host "Fehler: Keine RustDesk-Installationsdatei (rustdesk-*.exe) gefunden!" -ForegroundColor Red
    if (-not $NoPause) { Pause }
    Exit
}

$selectedInstaller = $null

# Interaktive Auswahl nur, wenn wir NICHT im Silent-Mode (NoPause) sind
if ($NoPause) {
    $selectedInstaller = $installers | Select-Object -First 1
    Write-Host "Silent-Modus aktiv: Wähle automatisch den neuesten Installer: $($selectedInstaller.Name)" -ForegroundColor Cyan
} else {
    # Interaktive Abfrage
    foreach ($installer in $installers) {
        Write-Host "Gefundene Datei: $($installer.Name)" -ForegroundColor Cyan
        
        Write-Host "Soll diese Datei installiert werden? (j/n): " -ForegroundColor Yellow -NoNewline
        $confirmation = Read-Host
        
        if ($confirmation -eq "j") {
            $selectedInstaller = $installer
            break 
        }
        Write-Host "Suche nach nächster Datei..." -ForegroundColor Gray
        Write-Host "-----------------------------"
    }
}

if (-not $selectedInstaller) {
    Write-Host "Keine Datei zur Installation ausgewählt. Abbruch." -ForegroundColor Yellow
    if (-not $NoPause) { Pause }
    Exit
}

# ---------------------------------------------------------
# 2. Parameter prüfen und ggf. abfragen
# ---------------------------------------------------------

# Config String Logik
if ([string]::IsNullOrWhiteSpace($ConfigString)) {
    # Wenn Silent Mode aktiv ist, aber kein ConfigString da ist -> Warnung
    if ($NoPause) {
        Write-Host "Warnung: Kein Config-String übergeben (Silent Mode)." -ForegroundColor Yellow
    } else {
        Write-Host "Bitte RustDesk Config-String eingeben: " -ForegroundColor Yellow -NoNewline
        $ConfigString = Read-Host
    }
} else {
    Write-Host "Verwende übergebenen Config-String." -ForegroundColor Cyan
}

# Passwort Logik
if ([string]::IsNullOrWhiteSpace($Password)) {
    if ($NoPause) {
        Write-Host "Warnung: Kein Passwort übergeben (Silent Mode)." -ForegroundColor Yellow
    } else {
        Write-Host "Bitte das permanente RustDesk Passwort eingeben (Eingabe wird maskiert): " -ForegroundColor Yellow -NoNewline
        $securePass = Read-Host -AsSecureString
        $Password = [System.Net.NetworkCredential]::new("", $securePass).Password
    }
} else {
    Write-Host "Verwende übergebenes Passwort." -ForegroundColor Cyan
}

# ---------------------------------------------------------
# 3. Installation starten
# ---------------------------------------------------------
Write-Host "`nStarte Installation von $($selectedInstaller.Name)..." -ForegroundColor Green

# Start ohne -Wait
Start-Process -FilePath $selectedInstaller.FullName -ArgumentList "--silent-install"

# ---------------------------------------------------------
# 4. Auf Dienst warten
# ---------------------------------------------------------
Write-Host "Warte auf Start des 'RustDesk' Dienstes..." -NoNewline

$serviceName = "RustDesk"
$serviceRunning = $false
$maxRetries = 60 
$retryCount = 0

while (-not $serviceRunning) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    
    if ($service -and $service.Status -eq 'Running') {
        $serviceRunning = $true
        Write-Host " OK (Dienst läuft)" -ForegroundColor Green
    } else {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
        $retryCount++
        
        if ($retryCount -ge $maxRetries) {
            Write-Host "`nFehler: Zeitüberschreitung. Dienst nicht gestartet." -ForegroundColor Red
            if (-not $NoPause) { Pause }
            Exit
        }
    }
}

# ---------------------------------------------------------
# 5. Konfiguration setzen
# ---------------------------------------------------------
$targetPath = "C:\Program Files\RustDesk\rustdesk.exe"

if (Test-Path $targetPath) {
    Write-Host "Wende Konfigurationen an..."
    
    if (-not [string]::IsNullOrWhiteSpace($ConfigString)) {
        Write-Host " -> Setze Server-Konfiguration..."
        Start-Process -FilePath $targetPath -ArgumentList "--config $ConfigString" -Wait -NoNewWindow
    }

    Start-Sleep -Seconds 1

    if (-not [string]::IsNullOrWhiteSpace($Password)) {
        Write-Host " -> Setze Passwort..."
        Start-Process -FilePath $targetPath -ArgumentList "--password $Password" -Wait -NoNewWindow
    }
    
    Write-Host "`nFertig! RustDesk wurde installiert und konfiguriert." -ForegroundColor Green
} else {
    Write-Host "Fehler: Die Datei $targetPath wurde trotz laufendem Dienst nicht gefunden." -ForegroundColor Red
}

# Pause nur wenn NICHT -NoPause gesetzt wurde
if (-not $NoPause) {
    Pause
}