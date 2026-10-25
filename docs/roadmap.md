# Roadmap

![Roadmap](diagramme/roadmap.png)

Jede Stufe baut auf der vorherigen auf: Vorlagen vor neuen Servern, Backup vor riskanten Umbauten, Logging vor der Firewall (damit man sieht, was geblockt wird).

| # | Ausbaustufe | Neue VM | Status |
|---|---|---|---|
| 0 | Umzug auf Mini-PC im 10-Zoll-Rack | – | Rack, Switch und Proxmox auf dem Mini-PC ✅ ([Kapitel 15](anleitung/15-proxmox-host.md)), Pi-NAS ✅ ([Kapitel 16](anleitung/16-pi-nas.md)), VM-Umzug ✅ ([Kapitel 17](anleitung/17-umzug-hyperv-proxmox.md)), MECM folgt |
| 1 | Monitoring (Uptime Kuma, Beszel, Alarme per Push) | – | ✅ ([Kapitel 18](anleitung/18-betrieb.md)) |
| 2 | Reverse Proxy und DNS-Namen | – | ✅ |
| 3 | Infisical für Kennwörter | – | wieder entfernt, KeePassXC reicht |
| 4 | Quick Wins (AD-Papierkorb, Lizenzdaten, Monitore) | – | teilweise |
| 5 | VM-Vorlagen | – | geplant |
| 6 | Backup und Restore | BKP01 | Proxmox-Backups jede Nacht aufs Pi-NAS ✅ ([Kapitel 16](anleitung/16-pi-nas.md)), Veeam für Windows-Restores geplant |
| 7 | Patch-Management über MECM | – | geplant |
| 8 | Eigene CA und HTTPS (auch für MECM) | CA01 | geplant |
| 9 | Gitea und Mailpit | – | geplant |
| 10 | Logging / SIEM (Wazuh) | LOG01 | ✅ |
| 11 | Firewall (OPNsense) und getrenntes Clientnetz | FW01 | geplant |
| 12 | Drucken (virtuelle Drucker, Point and Print) | – | geplant |
| 13 | Ticketsystem und Inventar (GLPI) | – | geplant |
| 14 | Entra ID und Intune, Co-Management | CLIENT02 | geplant |
| 15 | Zweiter Domain Controller (Replikation, FSMO) | DC02 | Idee |
| – | Netzwerkkarte mit Live-Status ([Kapitel 14](anleitung/14-homelable.md)) | PVE01 | ✅, seit 25.10. nicht mehr in Betrieb |

## Hardware

Das Lab zieht auf einen eigenen Mini-PC in einem 10-Zoll-Rack um. Rack und Switch stehen seit dem 19.10.2026, auf dem Mini-PC läuft seit dem 21.10.2026 Proxmox VE. Seit dem 25.10.2026 laufen alle Server dort, Hyper-V bleibt nur für Testclients. Belegung, Verkabelung und Switch-Einrichtung: [Hardware](hardware.md). So reicht der Arbeitsspeicher auf dem Mini-PC, wenn die VMs umgezogen sind:

![RAM-Budget](diagramme/ram-budget.png)

## Weitere Ideen

- Helpdesk-Delegation: eigene Gruppe darf nur Kennwörter zurücksetzen und Konten entsperren
- Joiner / Mover / Leaver als Prozess und Skript
- MECM: Betriebssystem per Tasksequenz ausrollen (Anwendungen verteilen ✅, Kapitel 12)
- NTLM-Nutzung im Lab auswerten (Vorbereitung auf NTLM-Abschaltung)
- AD-Sicherheitscheck mit PingCastle, Angriffspfade mit BloodHound CE
- Monatlicher Notfall-Tag: etwas absichtlich kaputt machen und wiederherstellen
