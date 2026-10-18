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
| Überwachung | Netdata nur für Linux, Windows-Server per Ping, Port und DNS in Uptime Kuma | Das lokale Netdata-Dashboard für Windows-Agenten ist im kostenlosen Tarif gesperrt |
| Reverse Proxy | Nginx Proxy Manager | Weboberfläche, schnell eingerichtet, reicht fürs Lab |
| Jump Host | Warpgate für RDP und SSH | Lernprojekt. Echter Schutz erst, wenn der Zugriff nur noch darüber erlaubt ist |
| Fernzugriff | NetBird (kostenloser Tarif) mit TOOLS01 als Routing Peer | Kein eigener Server nötig, RDP steht nie direkt im Internet |
| Kennwörter | Hauptzugänge lokal in KeePassXC, alle übrigen Lab-Kennwörter in Infisical | Wer Infisical aufschließt, braucht einen Zugang, der nicht in Infisical liegt |
| Connection Manager | Devolutions Remote Desktop Manager Free | RDP, SSH und Hyper-V-Konsole an einer Stelle |
| Hardware | Umzug auf einen Mini-PC (Ryzen 5 PRO, 32 GB) im 10-Zoll-Rack | Lab soll dauerhaft laufen, ohne den großen PC anzulassen. Ca. 15–25 W |
| Dokumentation | Notion | Datenbanken für Aufgaben, Änderungen und Runbooks mit Verknüpfungen |
