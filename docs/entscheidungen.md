# Entscheidungen

Warum ich etwas so gebaut habe, wie es ist. Kurz gehalten, im Stil von Architecture Decision Records.

| Thema | Entscheidung | Begründung |
|---|---|---|
| Arbeitsspeicher | Linux-VMs und SQL Server bekommen festen RAM, Windows-VMs dynamischen | Dynamischer RAM führte bei Linux zu Out-of-Memory und Kernel Panic. SQL Server gibt Speicher ungern zurück |
| Laufwerk S: | Eine GPO, ein Eintrag pro Abteilung mit Zielgruppenadressierung, Aktion *Ersetzen* | Alles an einer Stelle. *Ersetzen* räumt alte Zuordnungen auf |
| Lokale Admin-Kennwörter | Windows LAPS (eingebaut), nicht Legacy LAPS | Kein zusätzliches MSI, Kennwörter im AD, offiziell der Weg ab Server 2025 |
| Zeit | DC01 (PDC-Emulator) holt die Zeit per NTP, alle anderen von DC01. Hyper-V-Zeitsync für DC01 aus | Sonst überschreibt der Host die Domänenzeit, Kerberos verträgt keine großen Abweichungen |
| Sicherung DC01 | Windows Server-Sicherung (Systemstatus) auf eigene virtuelle Platte | Prüfpunkte sind keine Sicherung. Später Veeam |
| MECM-Kommunikation | Enhanced HTTP mit selbstsigniertem Zertifikat, vorerst | Noch keine PKI. Umstellung auf HTTPS mit eigener CA geplant |
| Netz-Doku | NetBox für IP-Adressen und VMs, Notion für Betrieb und Anleitungen | NetBox ist die Quelle der Wahrheit fürs Netz, Notion für alles Textliche |
| Überwachung | ~~Netdata nur für Linux~~ (bis 25.10.2026), seitdem Beszel für alle Server inkl. Windows, Uptime Kuma für Dienste | Beszel hat einen kostenlosen Windows-Agent und ersetzt Netdata komplett, ein Werkzeug weniger |
| Reverse Proxy | Nginx Proxy Manager | Weboberfläche, schnell eingerichtet, reicht fürs Lab |
| Jump Host | ~~Warpgate für RDP und SSH~~, am 25.10.2026 abgeschaltet | Wurde nach dem Umzug nicht mehr genutzt, RDP/SSH laufen direkt aus Remote Desktop Manager. Kapitel bleibt als Anleitung |
| Fernzugriff aufs Lab-Netz | ~~NetBird mit TOOLS01 als Routing Peer~~, seit dem Umzug Tailscale auf pve01, das `10.0.0.0/24` zusätzlich freigibt | Ein Werkzeug für Heimnetz und Lab-Netz, RDP steht nie direkt im Internet |
| Kennwörter | Alle Lab-Kennwörter lokal in KeePassXC. Infisical wieder entfernt | Infisical lief, wurde aber nie genutzt. Als reine Passwortablage bringt es nichts gegenüber KeePassXC, kostet RAM auf TOOLS01 und liegt selbst im Lab: Ist TOOLS01 kaputt, fehlen die Kennwörter zum Reparieren. Sinnvoll erst, wenn Dienste ihre Secrets automatisch abrufen sollen |
| Connection Manager | Devolutions Remote Desktop Manager Free | RDP, SSH und Hyper-V-Konsole an einer Stelle |
| Hardware | Umzug auf einen Mini-PC (Ryzen 5 PRO, 32 GB) im 10-Zoll-Rack | Lab soll dauerhaft laufen, ohne den großen PC anzulassen. Ca. 15–25 W |
| Hypervisor auf dem Mini-PC | Proxmox VE statt Windows mit Hyper-V (geändert am 21.10.2026, vorher Hyper-V geplant) | Ein Windows-Host braucht selbst RAM und CPU, die bei 32 GB den VMs fehlen. Proxmox kann Windows Server genauso als VM betreiben, dazu LXC-Container und Community-Scripts. Hyper-V übe ich weiter auf dem großen PC. Details: [Kapitel 15](anleitung/15-proxmox-host.md) |
| Speicher auf pve01 | Drei SSDs mit getrennten Aufgaben: System (ext4), `vmdata` (LVM-Thin), `backup` (Verzeichnis) | VMs und Backups liegen nie auf derselben Platte, LVM-Thin belegt Platz erst bei Nutzung und kann Snapshots |
| Host-Monitoring | Beszel (Hub als LXC, Agent auf dem Host) | Schlank, zeigt Temperaturen und Verlauf. Hat Netdata am 25.10.2026 ersetzt. Uptime Kuma bleibt für „ist der Dienst erreichbar?“ |
| Fernzugriff aufs Heimnetz | Tailscale auf pve01 als Subnet Router | Keine Portfreigabe im Router, Handy erreicht alles im Heimnetz. Der Host selbst statt eines Containers, weil ein Subnet Router im LXC zusätzliche TUN-Rechte braucht |
| Switch | TP-Link TL-SG108E (managed, gebraucht) | Kann 802.1Q-VLANs für die spätere Netztrennung, Metallgehäuse, sehr günstig. Nachteil: nur 1 Gbit und keine Rackwinkel, deshalb 3D-gedruckte Halterung |
| Verkabelung im Rack | Patchpanel oben mit Abstand zum Switch: Geräte hinten, vorne kurze farbige Kabel (Patchpanel = Switch-Port + 2) | Vorne ordentlich, Umstecken für VLAN-Tests ohne an die Geräte zu müssen. Der Abstand sieht mit den Kabelbögen sauberer aus als Patchpanel direkt über dem Switch |
| Lab-Netz als VLAN | VLAN 10 nur für das Lab, Heimnetz und Router bleiben unverändert (VLAN 1 untagged). Nur die Ports von Mini-PC und Arbeits-PC tragen VLAN 10 tagged | Übung mit echten VLANs, ohne das Netz der restlichen Familie anzufassen. Testclients brauchen kein zweites Kabel. Details: [Kapitel 19](anleitung/19-vlan-testclient.md) |
| Switch-Verwaltung | Feste IP im Heimnetz, Uplink immer untagged in VLAN 1 | Erreichbar vom Arbeits-PC, und man sperrt sich bei VLAN-Übungen nicht aus |
| Netzwerkkarte | ~~Homelable~~, am 25.10.2026 aufgegeben (vorher als LXC in einer Proxmox-VM in Hyper-V) | Schneller Überblick „läuft alles?“, ergänzt NetBox statt es zu ersetzen. Im LXC liefert der Scan MAC-Adressen (unter Docker Desktop nicht), und der Container lässt sich per Backup auf einen echten Proxmox-Host umziehen |
| Dokumentation | Notion | Datenbanken für Aufgaben, Änderungen und Runbooks mit Verknüpfungen |
| NetBox | Als LXC auf pve01 im Heimnetz (`192.168.2.22`) statt als VM im Lab-Netz | Weniger RAM, startet in Sekunden, wird mit gesichert. Verwaltungswerkzeuge wie Beszel und NetBox gehören ins Verwaltungsnetz, nicht in das Netz, das sie dokumentieren |
| Backups | Zwei Jobs: 01:30 lokal auf pve01, 03:30 auf das Pi-NAS | Lokal geht der Restore schnell, das NAS hilft, wenn pve01 selbst ausfällt. Verschiedene Geräte, aber noch keine Kopie außer Haus |
| Bedarfs-VMs | CM01 und LOG01 laufen nur zum Üben, *Start at boot: No*, nicht in den nächtlichen Backups, nach Änderungen manuell gesichert | Beide zusammen 14 GB RAM, SQL und Wazuh erzeugen auch im Leerlauf Last. Ins Wazuh-Dashboard habe ich im Alltag nie geschaut |
| Testclients | In Hyper-V auf dem Arbeits-PC statt auf pve01 | Clients laufen nur, wenn ich am PC sitze. pve01 bleibt für Dienste frei |
| Alarme | Alle Quellen (Beszel, beide Uptime Kumas, Proxmox-Backups) per ntfy aufs Handy, jede mit *Test* geprüft | Eine App für alles. Ungetestete Alarme sind schlimmer als keine: Beszel hat tagelang still nichts gesendet |
| Wächter von außen | Zweites Uptime Kuma und zweiter Tailscale-Subnet-Router auf dem Pi | Fällt pve01 aus, meldet sich sonst niemand, und man kommt von unterwegs nicht mehr ins Heimnetz |
| Werbeblocker | Pi-hole auf dem Pi, erst nur für einzelne Geräte | Für das ganze Haus müsste der Router-DHCP abgeschaltet werden, und das Internet aller hinge am Pi. Erst Testphase, dann Absprache |
| Kopie außer Haus | Bewusst keine (Stand 25.10.2026) | Das Lab ist eine Übungsumgebung, der Aufbau steht in diesem Repo. Neu prüfen, sobald unersetzliche Daten auf dem NAS liegen |
