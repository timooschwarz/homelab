# Changelog

## 2026-10-18
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
