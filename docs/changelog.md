# Changelog

## 2026-10-27
- Neues [Kapitel 19 · Lab-Netz als VLAN 10](anleitung/19-vlan-testclient.md): VLAN 10 „LAB“ auf dem TL-SG108E (Mini-PC und Arbeits-PC tagged), `vmbr1` auf pve01 über `nic0.10` am Switch, externer Hyper-V-Switch `Extern` auf dem Arbeits-PC
- Neuer Testclient CLIENT02 (Windows 11 Pro) in Hyper-V auf dem Arbeits-PC, bekommt seine IP per DHCP von DC01, in der Domäne und in *Lab/Computer*
- [Hardware](hardware.md): Mini-PC steckt seit dem Rack-Umbau in Switch-Port 5, Port-Tabelle und Prüfweg ergänzt
- Drei neue Fälle in der [Fehlerbehebung](fehlerbehebung.md#vlan-kapitel-19), darunter die Fehlersuche mit `pktmon`, `tcpdump` und `ip -s link` (RX 0 / TX hoch = falscher Switch-Port)

## 2026-10-25 (später Abend)
- Kapitel 18: RAID-Wächter für das Pi-NAS (ntfy bei *degraded*) und DNS-Monitor für Pi-hole
- 14 Screenshots in [Kapitel 17](anleitung/17-umzug-hyperv-proxmox.md) und [Kapitel 18](anleitung/18-betrieb.md) (Emergency Mode, dracut, Import, Netplan, VirtIO, Beszel, Uptime Kuma, Homepage, Pi-hole, Backups), persönliche Daten unkenntlich gemacht; Restore-Test als Anleitung in Kapitel 18
- CM01 auf VirtIO (SCSI-Platte und Netzwerk) und 6 Kerne umgestellt, Anleitung in [Kapitel 17](anleitung/17-umzug-hyperv-proxmox.md#windows-nachträglich-auf-virtio-umstellen), dazu ein neuer Fall in der [Fehlerbehebung](fehlerbehebung.md#systemplatte-nach-dem-umstellen-auf-virtio-verschwunden)

## 2026-10-25 (abends)
- Neues [Kapitel 18 · Betrieb](anleitung/18-betrieb.md): Alarme und Backup-Berichte per ntfy, zweites Uptime Kuma und Pi-hole auf dem Pi, Homepage mit Proxmox-Widget, Namen über den Proxy, Tailscale als Notzugang, Checkliste für Updates und Restore-Tests
- Neue Grafiken: [Netzwerk Stand 25.10.](diagramme/netzwerk-2026-10-25.png) und Startreihenfolge auf pve01
- [Aufbau](aufbau.md) auf den Stand nach dem Umzug gebracht (VM-IDs, Heimnetz-Geräte, CNAMEs, Dienste auf TOOLS01), vier neue Fälle in der [Fehlerbehebung](fehlerbehebung.md#betrieb-kapitel-18)

## 2026-10-25
- CM01 (MECM mit SQL) als VM 120 auf pve01 umgezogen, damit sind alle Server aus Hyper-V raus. Läuft nur bei Bedarf, Hinweise zum ersten Start in [Kapitel 17](anleitung/17-umzug-hyperv-proxmox.md#mecm-nach-dem-umzug)
- Backup-Benachrichtigungen von Proxmox per ntfy (Notification Target Webhook + Matcher auf `type = vzdump`)
- Beszel überwacht jetzt alle Lab-Server: TOOLS01 (Docker-Agent mit Container-Werten), LOG01 sowie DC01 und FS01 (Windows-Agent als Dienst): Hub mit zweiter Karte im Lab-Netz `vmbr1`, Anleitung in [Kapitel 15](anleitung/15-proxmox-host.md#vms-im-lab-netz-überwachen-nach-dem-umzug-kapitel-17)
- Beszel-Alarme global für alle Systeme (Status, RAM, Disk, CPU, Temperatur)
- Homepage (gethomepage.dev) als Startseite auf TOOLS01 (`http://10.0.0.50:3000`): Kacheln mit Ping-Status für alle Dienste, Proxmox-Widget mit Nur-Lese-API-Token (`homepage@pve`, Rolle PVEAuditor, Secret per `.env` statt in der YAML)
- Netdata und Warpgate auf TOOLS01 abgeschaltet: Beszel übernimmt die Systemwerte, Zugriff läuft direkt per RDP/SSH über die Route zu pve01 bzw. Tailscale
- Uptime Kuma aufgeräumt: Monitore für Netdata, Infisical und NETBOX01 entfernt, NetBox prüft jetzt den LXC unter `https://192.168.2.22` (TLS-Fehler ignorieren wegen selbstsigniertem Zertifikat), CLIENT01 und CM01 pausiert
- DC01 und FS01 von 2 auf 4 GB RAM (Ballooning, min. 2 GB), weil Beszel zeigte, dass 2 GB nicht reichen
- Temperaturen nach dem Umzug eingeordnet (CPU ca. 58 °C, VM-SSD-Controller ca. 66 °C)
- Pi-NAS: omv-extras und Compose-Plugin (Docker), Pi-hole als Container (Weboberfläche Port 8080, DNS nur an die LAN-IP gebunden, weil `systemd-resolved` auf `127.0.0.53:53` lauscht)
- Pi-NAS: zweites Uptime Kuma (Port 3001) als Wächter von außen für pve01, DC01 und TOOLS01. Damit der Pi das Lab erreicht, Route `10.0.0.0/24` über pve01 in eigener Netplan-Datei `/etc/netplan/90-lab-route.yaml` (OMV lässt sie in Ruhe)
- Beszel-Alarme kamen nie an: LXC-Container erbten Tailscale-DNS (`100.100.100.100`) vom Host. DNS bei beszel und netbox fest auf den Router gesetzt, neuer Fall in der [Fehlerbehebung](fehlerbehebung.md). Push per ntfy jetzt auch vom Uptime Kuma auf dem Pi
- Pi-NAS als zweiter Tailscale-Subnet-Router für `192.168.2.0/24` (`--accept-dns=false`, damit Pi-hole und Docker ihren DNS behalten). Fällt pve01 aus, bleibt das Heimnetz von unterwegs erreichbar
- Nginx Proxy Manager: neue Namen `home`, `netbox`, `beszel`, `wazuh`, `pve`, `pihole` (`.lab.test`), je ein CNAME auf `tools01.lab.test` in der DNS-Zone auf DC01. Homepage braucht den Namen zusätzlich in `HOMEPAGE_ALLOWED_HOSTS`, Proxmox und Beszel brauchen *Websockets Support*
- LOG01 (Wazuh) und der Testclient laufen nur noch bei Bedarf: pve01 sinkt von 80 % auf ca. 45 % RAM. Wazuh-Pakete per `apt-mark hold` von normalen Updates ausgenommen
- Homelable wird nicht mehr betrieben, die Behelfs-VM PVE01 in Hyper-V entfällt. [Kapitel 14](anleitung/14-homelable.md) bleibt als Anleitung
- Updates: pve01 (libbrotli1) und Pi-NAS (rpi-eeprom, Bootloader), RAID danach weiter clean

## 2026-10-24
- Neues [Kapitel 17 · Umzug von Hyper-V auf Proxmox](anleitung/17-umzug-hyperv-proxmox.md): DC01 (VM 110), FS01 (140), TOOLS01 (150), LOG01 (170) und CLIENT01 (900) laufen auf pve01 im Lab-Netz `vmbr1`, IPs und Domäne unverändert
- Linux-VMs: initramfs per dracut mit allen Treibern neu gebaut, Netplan auf die neue MAC umgestellt, QEMU Guest Agent überall
- Wazuh auf 6 GB RAM mit 3 GB Indexer-Heap, Agents melden wieder
- Arbeits-PC: vEthernet (LAB) aus, feste Route `10.0.0.0/24` über pve01
- NetBox: Cluster der umgezogenen VMs auf pve01, vCPUs nachgetragen
- Testclient aus den Backup-Jobs ausgenommen
- Zehn neue Fälle in der [Fehlerbehebung](fehlerbehebung.md#umzug-hyper-v--proxmox)

## 2026-10-22 (später Abend)
- pve01: zweite Bridge `vmbr1` mit `10.0.0.1/24` und NAT für das Lab-Netz, Tailscale gibt zusätzlich `10.0.0.0/24` frei
- Zweiter Backup-Job: täglich 01:30 lokal auf `backup` (3 Tage, 2 Wochen), 03:30 weiter aufs NAS
- NetBox neu als LXC 101 (`192.168.2.22`, Community-Script) statt NETBOX01 in Hyper-V, befüllt mit Standort, Netzen, Geräten, Clustern, VMs und IPs (CSV-Import)
- Pi-NAS: SMB-Freigabe mit eigenem Benutzer, Beszel-Alarme mit Push per ntfy
- Neuer Fall in der [Fehlerbehebung](fehlerbehebung.md): kaputte Prüfpunkt-Kette in Hyper-V (`0xC03A0019`)

## 2026-10-22 (abends)
- Neues [Kapitel 16 · NAS mit Raspberry Pi](anleitung/16-pi-nas.md): Pi 5 mit Penta SATA HAT zusammengebaut, Raspberry Pi OS Lite und OpenMediaVault 8 installiert, RAID 5 aus 4× 1 TB SSD, NFS-Freigabe, Proxmox-Storage `nas` und täglicher Backup-Job (03:30, 7/4/3)
- Zwei harte Fehler gelöst: Timeouts am JMB585 unter Kernel 6.18 (`dtoverlay=pcie-32bit-dma-pi5`) und extrem langsames Lesen alter Daten bei den Samsung 840 EVO (alle SSDs per `blkdiscard` getrimmt)
- Sechs neue Fälle in der [Fehlerbehebung](fehlerbehebung.md)
- [Hardware](hardware.md): NAS passt mit stehenden SSDs nicht in 2 HE, Umbauvorschlag ergänzt

## 2026-10-22
- Neues [Kapitel 15 · Proxmox auf eigener Hardware](anleitung/15-proxmox-host.md) mit Screenshots und zwei Grafiken (Überblick, Speicher): Aufrüsten, Installation, Paketquellen, Speicher, Beszel, Tailscale
- Die Proxmox-Abschnitte aus [Hardware](hardware.md) sind ins Kapitel umgezogen
- [Entscheidungen](entscheidungen.md): Proxmox statt Hyper-V auf dem Mini-PC, Speicheraufteilung, Beszel, Tailscale
- Netzwerkgrafik neu: Heimnetz mit pve01, beszel und Tailscale, Lab-Netz mit PVE01/Homelable, Infisical entfernt
- Grafiken RAM-Budget (jetzt mit Proxmox statt Windows-Host) und Roadmap (aktueller Status) neu, [Aufbau](aufbau.md) um pve01 und beszel ergänzt
- Erste Nacht im Dauerbetrieb: pve01 stabil, CPU im Leerlauf ca. 36 °C, Tailscale-Zugriff übers Handy getestet

## 2026-10-21
- HP EliteDesk 805 G6 Mini aufgerüstet: 32 GB DDR4, 2× NVMe und 1× SATA-SSD, im BIOS geprüft
- Proxmox VE 9.2 auf dem Mini-PC installiert (`pve01`, `192.168.2.20`), erreichbar über die Weboberfläche
- [Hardware](hardware.md): neue Abschnitte zum Aufrüsten des Mini-PCs und zur Proxmox-Installation per USB-Stick
- Tailscale als Subnet Router auf dem Proxmox-Host, Zugriff aufs Heimnetz vom Handy ohne Portfreigabe
- Beszel als LXC (`192.168.2.21`) mit Agent auf dem Proxmox-Host: CPU, RAM, Disk und Temperatur im Blick
- Neue Grafiken für Rack-Belegung und Verkabelung (Stand 21.10.)
- Mini-PC und Switch ins Rack eingebaut, Patchpanel nach oben versetzt, alle Geräte über das Patchpanel verkabelt (Port 1, 7, 8 mit Gigabit)
- Speicher `vmdata` (LVM-Thin) und `backup` (Verzeichnis) eingerichtet
- Proxmox auf No-Subscription-Repo umgestellt und aktualisiert, GRUB nach dem Update repariert
- Drei neue Fälle in der [Fehlerbehebung](fehlerbehebung.md) (Mini-PC startet nicht, GRUB-Konsole nach Update, Antennenabdeckung)

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
