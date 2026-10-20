# Changelog

## 2026-10-20
- PVE01 (10.0.0.90): Proxmox VE 9.2 als Generation-1-VM in Hyper-V, Installation per Terminal-Installer
- Homelable 3.6 als LXC-Container (10.0.0.91) per Community-Script, Canvas mit allen VMs und Live-Status, daraus [Kapitel 14](anleitung/14-homelable.md)
- `GPO-Computer-Ping` zusätzlich an Lab/Server und Domain Controllers, Ping auf dem Hyper-V-Host nur aus `10.0.0.0/24`
- Infisical von TOOLS01 entfernt, alle Kennwörter in KeePassXC
- Fünf neue Fälle in der [Fehlerbehebung](fehlerbehebung.md) (Proxmox-Installer unter Hyper-V, fehlende Server im Scan, Host antwortet nicht auf Ping)

## 2026-10-19
- 10-Zoll-Rack aufgebaut: Blindblenden in HE 1–3, Fachboden für den Mini-PC in HE 6
- Managed Switch TL-SG108E eingerichtet: feste IP im Heimnetz, Firmware geprüft, Uplink auf Port 8
- Neue Seite [Hardware](hardware.md) mit Rack-Belegung, Verkabelung über Patchpanel und Switch-Einrichtung
- Drei neue Fälle in der [Fehlerbehebung](fehlerbehebung.md) (100 Mbit statt Gigabit, Switch nicht erreichbar, Save Config)

## 2026-10-18
- LOG01 (10.0.0.70) mit Wazuh 4.14.9, Agents auf DC01, FS01, CLIENT01, daraus Kapitel 13
- MECM: erste Anwendung (7-Zip) verteilt, als Available im Softwarecenter und als Required ohne Klick, daraus Kapitel 12
- 114 zusätzliche Testbenutzer per [`New-LabBulkUsers.ps1`](../scripts/New-LabBulkUsers.ps1) in fünf Abteilungs-OUs, neue Gruppen GG-Personal und GG-Leitung
- FS01: Ordner Personal und Leitung, NTFS-Fehler bei einem bestehenden Abteilungsordner (*This folder only*) korrigiert
- Laufwerk S: für die neuen Abteilungen ergänzt und getestet

## 2026-10-17
- FS01: RDP aktiviert, Zeitzone korrigiert
- Devolutions Remote Desktop Manager als Connection Manager
- GPO für RDP-Freigabe auf Clients und Servern

## 2026-10-16
- DNS-CNAMEs für die Lab-Dienste, NRPT-Regel für `*.lab.test` auf dem Host
- Nginx Proxy Manager und Infisical auf TOOLS01

## 2026-10-13
- TOOLS01 mit Docker, Uptime Kuma und Netdata
- Warpgate als Jump Host
- Windows LAPS, AD-Papierkorb, Windows Server-Sicherung auf DC01
- Zeitsynchronisation per NTP-GPO
- Reverse-Lookupzone und DNS-Korrekturen
- GPO-Computer-Design (Hintergrund), `redircmp` auf Lab/Computer
- GPO-Aufräumen per Skript: Laufwerk S:, Ping, Kennwortrichtlinie
- MECM-Client auf CLIENT01 läuft
- RAM-Aufteilung aller VMs überarbeitet

## 2026-10-12
- FS01 mit Freigabe Abteilungen und NTFS-Rechten über GG-Gruppen
- GPO-Computer-RDP für die Abteilungsgruppen
- NETBOX01 mit NetBox, Lab in NetBox eingetragen

## 2026-10-11
- Hyper-V-Switch `LAB` mit NAT
- DC01: Domäne `lab.test`, DNS, DHCP
- OU-Struktur, Testbenutzer, Dienstkonten
- CLIENT01 der Domäne beigetreten
- CM01 mit MECM (Site `LAB`)
- GPO für lokale Admins (MECM-Push-Konto)
