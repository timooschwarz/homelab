# Kapitel 23 · Proxmox-MCP: Claude bekommt eingeschränkten Zugriff auf pve01

[← Kapitel 22](22-vaultwarden.md) · [Übersicht](../../README.md#inhaltsverzeichnis) · [Fehlerbehebung](../fehlerbehebung.md#proxmox-mcp-kapitel-23)

[![Proxmox](https://img.shields.io/badge/-Proxmox-E57000?style=flat-square)](../../README.md#thema-proxmox) [![Sicherheit](https://img.shields.io/badge/-Sicherheit-EF9F27?style=flat-square)](../../README.md#thema-sec)

> **Ziel:** Ein KI-Assistent (hier Claude in der Desktop-App) soll pve01 direkt abfragen und einfache Aufgaben erledigen können: VMs und Container auflisten, starten und stoppen, Snapshots vor Änderungen anlegen. Dafür läuft auf dem Arbeits-PC ein kleiner MCP-Server, der über die Proxmox-API mit einem **eigenen Benutzer und eingeschränkten Rechten** spricht.
> **Dauer:** ca. 45 Minuten · **Wo:** Proxmox (Browser), Arbeits-PC (PowerShell, Claude Desktop)
> **Voraussetzung:** pve01 ([Kapitel 15](15-proxmox-host.md)), Claude Desktop auf dem Arbeits-PC

```text
Claude Desktop (Arbeits-PC)
   │ startet lokal per stdio
   ▼
ProxmoxMCP-Plus (uvx, Python 3.12) ──HTTPS :8006, API-Token──► pve01
                                                                 │ Rechte nur über Rolle ClaudeOps
```

| Was | Wert |
|---|---|
| MCP-Server | [ProxmoxMCP-Plus](https://github.com/RekklesNA/ProxmoxMCP-Plus), Paket `proxmox-mcp-plus`, Start per `uvx` |
| Läuft auf | Arbeits-PC, wird von Claude Desktop selbst gestartet (kein Dienst, kein offener Port) |
| Proxmox-Benutzer | `claude@pve` (Realm *Proxmox VE authentication server*) |
| API-Token | `claude@pve!mcp`, **Privilege Separation aus** |
| Rechte | erst `PVEAuditor` (nur lesen), danach eigene Rolle `ClaudeOps` auf `/` |
| Konfiguration | `claude_desktop_config.json` im Claude-Ordner unter `%APPDATA%` |

**Warum ProxmoxMCP-Plus?** Es baut auf dem bekannteren [canvrno/ProxmoxMCP](https://github.com/canvrno/ProxmoxMCP) auf. Das Original kann fast nur lesen. Plus kann zusätzlich VMs und Container starten und stoppen, Snapshots und Backups anlegen und Logs lesen. Und es lässt sich ohne Klonen direkt per `uvx` starten.

**Warum ein eigener Benutzer statt root?** Das Projekt sagt selbst, dass es kein Ersatz für die Rechteverwaltung von Proxmox ist. Was der Assistent darf, entscheidet allein die Rolle des Tokens. Mit `root@pam` könnte er alles löschen.

## Schritt 1 · Benutzer anlegen (Proxmox, Browser)

**Datacenter → Permissions → Users → Add**

| Feld | Wert |
|---|---|
| User name | `claude` |
| Realm | **Proxmox VE authentication server** (nicht *Linux PAM*, sonst bräuchte es einen Linux-Benutzer auf pve01) |
| Password | langes Zufallspasswort, in KeePassXC. Wird nie gebraucht, der Zugriff läuft nur über den Token |
| Group, Expire, E-Mail | leer / `never` / leer |
| Comment | z. B. `Claude MCP (nur API-Token)` |

## Schritt 2 · API-Token anlegen (Proxmox, Browser)

**Datacenter → Permissions → API Tokens → Add**

| Feld | Wert |
|---|---|
| User | `claude@pve` |
| Token ID | `mcp` |
| Privilege Separation | **Haken raus** |

**Secret sofort in KeePassXC speichern.** Proxmox zeigt es nur dieses eine Mal.

Ohne Privilege Separation hat der Token genau die Rechte des Benutzers. Mit Haken bräuchte der Token zusätzlich eigene Rechte, und wirksam wäre nur die Schnittmenge. So pflegst du die Rechte an einer Stelle.

## Schritt 3 · Rechte vergeben, erst nur lesen (Proxmox, Browser)

**Datacenter → Permissions → Add → User Permission**

| Feld | Wert |
|---|---|
| Path | `/` |
| User | `claude@pve` |
| Role | **PVEAuditor** |
| Propagate | Haken drin |

Damit sieht der Assistent alles, kann aber nichts ändern. Erst wenn alles läuft, gibt es mehr Rechte (Schritt 7).

## Schritt 4 · uv und Python installieren (Arbeits-PC, PowerShell)

[uv](https://docs.astral.sh/uv/) startet den MCP-Server in einer eigenen Python-Umgebung, ohne dass du Python selbst installieren musst:

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

PowerShell schließen, neu öffnen, dann Python 3.12 einmal vorab holen:

```powershell
uv python install 3.12
```

> [!IMPORTANT]
> Ohne festgelegte Version nimmt `uvx` die neueste Python-Version und lädt sie beim ersten Start herunter. Claude Desktop startet den Server dabei mehrmals gleichzeitig, die Downloads stören sich gegenseitig und der Start bricht ab. Deshalb wird 3.12 vorab installiert und in der Konfiguration fest vorgegeben.

## Schritt 5 · Ordner für die Job-Datenbank (Arbeits-PC)

ProxmoxMCP-Plus merkt sich laufende Proxmox-Aufgaben (Snapshots, Starts) in einer kleinen SQLite-Datei. Ohne Pfad legt es die Datei im Startordner von Claude Desktop an, und dort darf es nicht schreiben.

Im Explorer unter `%USERPROFILE%` einen Ordner `proxmox-mcp` anlegen.

## Schritt 6 · In Claude Desktop eintragen

**Einstellungen → Entwickler → Konfiguration bearbeiten** öffnet den Ordner mit `claude_desktop_config.json`. Vorher eine Kopie der Datei anlegen. Dann **ganz oben**, direkt hinter die erste `{`, den Block `mcpServers` einfügen. Alles, was schon in der Datei steht, bleibt dahinter unverändert:

```json
{
  "mcpServers": {
    "proxmox": {
      "command": "uvx",
      "args": ["--python", "3.12", "proxmox-mcp-plus"],
      "env": {
        "PROXMOX_HOST": "192.168.2.20",
        "PROXMOX_PORT": "8006",
        "PROXMOX_USER": "claude@pve",
        "PROXMOX_TOKEN_NAME": "mcp",
        "PROXMOX_TOKEN_VALUE": "<Secret aus KeePassXC>",
        "PROXMOX_VERIFY_SSL": "false",
        "PROXMOX_DEV_MODE": "true",
        "PROXMOX_JOBS_SQLITE_PATH": "C:\\Users\\<dein Benutzer>\\proxmox-mcp\\jobs.sqlite3"
      }
    }
  },
  "…": "ab hier der bisherige Inhalt der Datei"
}
```

- Jede Zeile im `env`-Block endet mit Komma, nur die letzte nicht.
- Im Pfad doppelte Backslashes.
- `PROXMOX_VERIFY_SSL` steht auf `false`, weil pve01 ein selbstsigniertes Zertifikat hat. Das allein reicht dem Server nicht, er verlangt zusätzlich `PROXMOX_DEV_MODE`. Für eine Verbindung, die nur im eigenen Heimnetz läuft, ist das vertretbar.

Speichern, Claude über das Symbol im Infobereich **komplett beenden** (nicht nur das Fenster schließen) und neu starten.

**Prüfen:** **Einstellungen → Entwickler** zeigt `proxmox` mit **Läuft**. Dann in einem Chat fragen: *„Zeig mir alle VMs und LXCs auf pve01 mit Status.“* Es kommt eine Liste mit allen Gästen, Kernen und RAM.

## Schritt 7 · Eigene Rolle für einfache Aufgaben (Proxmox, Browser)

Wenn das Lesen klappt, bekommt der Benutzer eine eigene Rolle statt Admin-Rechten.

**Datacenter → Permissions → Roles → Create**

| Feld | Wert |
|---|---|
| Name | `ClaudeOps` |
| Privileges | `VM.Audit`, `VM.PowerMgmt`, `VM.Snapshot`, `VM.Backup`, `Datastore.Audit`, `Datastore.AllocateSpace`, `Sys.Audit` |

Dann **Datacenter → Permissions → Add → User Permission**: Path `/`, User `claude@pve`, Role `ClaudeOps`.

| Darf | Darf nicht |
|---|---|
| Gäste anzeigen, starten, stoppen, neu starten | VMs oder Container anlegen oder löschen |
| Snapshots anlegen und zurückrollen | Hardware oder Konfiguration einer VM ändern |
| Backups anstoßen | Benutzer, Rechte, Netzwerk oder Speicher ändern |
| Node-Status und Logs lesen | Befehle in den Gästen ausführen |

**Prüfen:** Den Assistenten einen Snapshot einer VM anlegen lassen, z. B. `vor-test`. Er erscheint unter **VM → Snapshots**, als Ersteller steht in den Tasks unten `claude@pve!mcp`. Den Snapshot danach selbst wieder löschen.

> [!WARNING]
> Sobald es zwei Domain Controller gibt, **nie einen Snapshot eines DCs zurückspielen** (USN-Rollback, die Replikation bricht). Das gilt auch, wenn ein Assistent das Zurückrollen anbietet.

## Was ein Assistent damit nicht kann

Der MCP-Server spricht nur mit der Proxmox-API. In die VMs kommt er nicht: keine Shell, kein Windows, kein AD. Befehle in Gästen gingen nur mit dem QEMU Guest Agent **und** zusätzlichen Rechten, die hier bewusst fehlen. Für Lernthemen wie GPOs oder MECM ist das ohnehin richtig so.

## Prüfen

- [ ] `proxmox` steht in Claude Desktop unter **Entwickler** auf **Läuft**
- [ ] Die Frage nach allen Gästen liefert die komplette Liste
- [ ] Nur mit `PVEAuditor`: ein Start-Befehl wird von Proxmox abgelehnt
- [ ] Mit `ClaudeOps`: ein Testsnapshot lässt sich anlegen, in den Tasks steht `claude@pve!mcp`
- [ ] Das Token-Secret steht nur in KeePassXC und in der lokalen Konfiguration, nirgends sonst

## Häufige Fehler

| Problem | Ursache | Lösung |
|---|---|---|
| `Missing expected target directory for Python minor version link` | `uvx` lädt die neueste Python-Version, mehrere Starts gleichzeitig | 3.12 vorab installieren, `"--python", "3.12"` in `args`, kaputten Ordner unter `%APPDATA%\uv\python` löschen |
| `Insecure TLS configuration blocked` | `verify_ssl=false` ist nur im Dev-Mode erlaubt | `"PROXMOX_DEV_MODE": "true"` ergänzen |
| `sqlite3.OperationalError: unable to open database file` | Job-Datenbank soll im schreibgeschützten Startordner liegen | Ordner anlegen, `PROXMOX_JOBS_SQLITE_PATH` setzen |
| *App-Einstellungen konnten nicht geladen werden* | Komma fehlt oder steht zu viel in der JSON-Datei | Kopie zurückspielen oder Zeile aus der Meldung prüfen |
| Server läuft, aber ein Befehl wird abgelehnt | Rolle hat das Recht nicht | gewollt, Rolle nur gezielt erweitern |

Weitere Fälle: [Fehlerbehebung](../fehlerbehebung.md#proxmox-mcp-kapitel-23)

Wie es weitergeht: [Roadmap](../roadmap.md)
