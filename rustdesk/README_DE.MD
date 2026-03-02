# RustDesk Installations-Skript

Dieses PowerShell-Skript automatisiert den Download, die Installation und Konfiguration des RustDesk Remote-Desktop-Clients.

## Funktionen

- **Automatischer Download:** Lädt die aktuellste `rustdesk-*.exe` Version von GitHub herunter.
- **Automatische Erkennung:** Sucht im aktuellen Verzeichnis nach der neuesten `rustdesk-*.exe`.
- **Admin-Rechte:** Fordert automatisch Administratorrechte an (Elevation), falls diese nicht vorhanden sind.
- **Silent Install:** Unterstützt eine vollautomatische Installation ohne Benutzerinteraktion.
- **Konfiguration:** Setzt optional den ID/Relay-Server-String und ein permanentes Passwort.
- **Dienst-Überwachung:** Wartet intelligent auf den Start des RustDesk-Dienstes, bevor Konfigurationen angewendet werden.

## Verwendung

### Parameter

| Parameter | Typ | Beschreibung |
| :--- | :--- | :--- |
| `-ConfigString` | String | Der Base64-Konfigurations-String (zu finden unter Einstellungen > Netzwerk > ID/Relay Server). |
| `-Password` | String | Das permanente Passwort, das für den Zugriff gesetzt werden soll. |
| `-NoPause` | Switch | Verhindert die Pause am Ende und unterdrückt die interaktive Dateiauswahl (wählt automatisch die neuste). Ideal für Silent-Installationen. |

### Beispiele

**1. Interaktiver Modus**
Startet das Skript im interaktiven Modus. Fragt nach Bestätigung der Datei, sowie optional nach Config-String und Passwort.
```powershell
.\rustdesk-install_de.ps1
```

**2. Mit Parametern (Teilautomatisiert)**
Installiert mit den angegebenen Werten, wartet aber am Ende auf einen Tastendruck zur Kontrolle.
```powershell
.\rustdesk-install_de.ps1 -ConfigString "7KC...=" -Password "Geheim123!"
```

**3. Silent Mode (Vollautomatisch)**
Vollautomatische Installation ohne jegliche Benutzerinteraktion. Das Skript wählt automatisch die neueste Installer-Datei aus.
```powershell
.\rustdesk-install_de.ps1 -ConfigString "7KC...=" -Password "Geheim123!" -NoPause
```

## Voraussetzungen

- Windows PowerShell 5.1 oder höher
- Eine `rustdesk-*.exe` Installationsdatei im selben Verzeichnis wie das Skript.
