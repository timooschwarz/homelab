# Fehlerbehebung

Fehler, die beim Aufbau aufgetreten sind, jeweils mit Ursache und Lösung.

## Active Directory und Gruppenrichtlinien

### Laufwerk S: fehlt bei einer neuen Abteilung
- **Symptom:** Ein Benutzer der neuen Abteilung Personal bekommt kein S:. In `\\fs01\Abteilungen` sieht er nur den Ordner einer *anderen* Abteilung.
- **Ursache:** Beim Anlegen der Ordner Personal und Leitung waren die NTFS-Rechte vertauscht. `gpresult /r` zeigte, dass GPO und Gruppenmitgliedschaft stimmten.
- **Lösung:** GG-Gruppen an den Ordnern getauscht, ab- und wieder angemeldet.
- **Gelernt:** Hat der Benutzer keinen Zugriff aufs Ziel, scheitert die Laufwerkszuordnung ohne Fehlermeldung. Mit zugriffsbasierter Aufzählung sieht man an den sichtbaren Ordnern sofort, worauf jemand Rechte hat.

### Laufwerk S: zeigt die falsche Abteilung
- **Ursache:** 1) FS01 war aus. 2) Der Benutzer war zusätzlich in einer zweiten Abteilungsgruppe. 3) Die Aktion stand auf *Aktualisieren*, dadurch blieb die alte Zuordnung bestehen.
- **Lösung:** FS01 starten, falsche Mitgliedschaft entfernen, `net use S: /delete`, Aktion auf *Ersetzen*, `gpupdate /force`, neu anmelden.

### GPO trifft die falsche Gruppe („ad“ statt Administrators)
- **Symptom:** Das Dienstkonto fehlt bei den lokalen Administratoren, stattdessen entsteht eine lokale Gruppe `ad`.
- **Ursache:** Im Eintrag *Lokale Benutzer und Gruppen* wurde der Gruppenname von Hand eingetippt.
- **Lösung:** *Administrators (built-in)* per Dropdown wählen, falsche lokale Gruppe löschen.

### Remoteanmeldung an CLIENT01 verweigert
- **Meldung:** „Für die Remoteanmeldung müssen Sie dazu berechtigt sein …“
- **Ursache:** Normale Domänenbenutzer sind nicht in *Remotedesktopbenutzer*. Der erweiterte Sitzungsmodus von Hyper-V ist intern auch RDP.
- **Lösung:** GPO-Computer-RDP trägt die berechtigten Abteilungsgruppen ein. Für andere Abteilungen ist das Absicht, die melden sich über die Hyper-V-Konsole an.

### RDP-Verbindung hängt bei „Verbindung wird aufgebaut“
- **Ursache:** Die RDP-GPO füllt nur die Gruppe *Remote Desktop Users*, schaltet RDP aber nicht ein. Auf Servern ist RDP standardmäßig aus.
- **Lösung:** Eigene GPO, die RDP erlaubt und die Firewall-Ausnahme auf `10.0.0.0/24` beschränkt.

### GPO-Hintergrundbild bleibt schwarz
- **Ursache:** Die Datei in NETLOGON hieß in Wirklichkeit `wallpaper.jpg.png` (Endung ausgeblendet). Die Files-Preference fand `wallpaper.jpg` nicht. Außerdem fehlte der Zielordner.
- **Lösung:** Dateiendungen einblenden, Bild als echtes JPEG speichern, Ziel in einen bestehenden Ordner legen.

### LAPS: „Ihr Konto wurde deaktiviert“
- **Ursache:** Das eingebaute Administratorkonto ist unter Windows 11 standardmäßig deaktiviert. LAPS setzt nur das Kennwort.
- **Lösung:** In der LAPS-GPO zusätzlich *Konten: Administratorkontostatus = Aktiviert*.

### DC01: Uhrzeit 9 Stunden falsch
- **Ursache:** Zeitzone stand auf Pacific Time (Standard bei englischer Installation), die Hyper-V-Zeitsynchronisierung überschrieb NTP.
- **Lösung:** Zeitzone Berlin, Hyper-V-Zeitsync für DC01 aus, GPO mit NTP-Quelle. Prüfen mit `w32tm /query /status`.

## Dateiserver

### Kollegen können Dateien der eigenen Abteilung nicht öffnen
- **Ursache:** Das NTFS-Recht *Ändern* für die Abteilungsgruppe galt nur für *This folder only*. Wer eine Datei anlegte, hatte über CREATOR OWNER Zugriff, alle anderen nicht.
- **Lösung:** *This folder, subfolders and files*.
- **Gelernt:** Mit nur einem Testbenutzer pro Abteilung fiel das nicht auf. Erst mit vielen Testbenutzern (Bulk-Import) wurde es sichtbar.

### Schreiben verweigert trotz Lesezugriff
- **Ursache:** Das NTFS-Recht *Ändern* fehlte bzw. galt nicht für Unterordner und Dateien. Das Freigaberecht war korrekt.
- **Lösung:** Recht am Ordner korrekt setzen. Freigabe- und NTFS-Rechte immer getrennt prüfen.

## MECM

### Client-Installation scheitert mit `CCM_E_NO_CLIENT_PKI_CERT`
- **Meldung:** `CcmSetup failed with error code 0x87d00454`
- **Ursache:** Der Client will CM01 per HTTPS erreichen und hat kein Clientzertifikat. Im Lab gibt es noch keine PKI.
- **Lösung:** Communication Security der Site auf *Enhanced HTTP*, Client neu installiert.

## Netzwerk und DNS

### VM hat nur 169.254.x.x und kein Gateway
- **Meldung:** `PING: transmit failed. General failure.`
- **Ursache:** Die feste IP war weg, weil sich der Interface-Index geändert hatte.
- **Lösung:** Feste IP, Gateway und DNS neu setzen, Neustart.

### Ubuntu-Installer: „Temporary failure resolving“
- **Ursache:** DC01 (DNS) war nicht gestartet.
- **Lösung:** DC01 zuerst starten und auf automatischen Start stellen.

### DNS: PTR für DC01 zeigt auf den falschen Server
- **Ursache:** PTR-Eintrag falsch angelegt, außerdem fehlte ein A-Eintrag.
- **Lösung:** PTR in der Reverse-Zone korrigieren, A-Eintrag mit Haken „PTR erstellen“ anlegen, `ipconfig /registerdns`.

### Windows-Server fehlen im Netzwerkscan
- **Symptom:** Homelable findet nur die Linux-VMs, DC01, CM01 und FS01 fehlen.
- **Ursache:** Die Ping-GPO hing nur an `Lab/Computer`. Server und DC blockieren ICMP in der Windows-Firewall.
- **Lösung:** `GPO-Computer-Ping` zusätzlich mit `Lab/Server` und `Domain Controllers` verknüpfen, `gpupdate /force`.

### Hyper-V-Host bleibt im Monitoring rot
- **Ursache:** Der Host ist nicht in der Domäne, die GPO greift dort nicht. Windows blockiert Ping im LAB-Netz.
- **Lösung:** Regel *Datei- und Druckerfreigabe (restriktiv) (Echoanforderung – ICMPv4 eingehend)* aktivieren, Remote-IP auf `10.0.0.0/24` beschränken.

## Netzwerk-Hardware

### Nur 90 Mbit/s statt Gigabit
- **Symptom:** Speedtest zeigt nach dem Einbau des Switches nur rund 90 Mbit/s statt der gewohnten Bandbreite.
- **Ursache:** Der Port handelte nur 100 Mbit aus, zu sehen unter *Switching → Port Setting → Speed Actual* (`100MF`). Schuld war das Patchkabel.
- **Lösung:** Kabel gegen ein Cat6-Kabel getauscht, danach `1000MF`.
- **Gelernt:** Knapp unter 100 Mbit/s ist fast immer eine 100-Mbit-Verbindung. Zuerst *Speed Actual* am Switch und die Verbindungsgeschwindigkeit am PC ansehen, dann das Kabel tauschen.

### Weboberfläche des neuen Switches nicht erreichbar
- **Ursache:** Der Switch hat ab Werk `192.168.0.1`, das Heimnetz lag in einem anderen Bereich.
- **Lösung:** Mit dem Easy Smart Configuration Utility eine feste IP im Heimnetz gesetzt. Das Tool findet den Switch per Broadcast auch im falschen Bereich.

### Switch-Einstellungen nach Neustart weg
- **Ursache:** Beim TL-SG108E landen Änderungen erst mit **Save Config** dauerhaft im Speicher.
- **Lösung:** Nach jeder Änderung Save Config klicken und danach ein Konfigurations-Backup ziehen.

### Mini-PC startet nach Neustart nicht mehr
- **Symptom:** Nach dem ersten Neustart nach der Proxmox-Installation (hart ausgeschaltet) leuchtet die Power-LED dauerhaft weiß, aber kein HP-Logo, kein Bild, Tastatur und Maus bleiben dunkel. Keine Blinkcodes, kein Piepen. Komplett stromlos machen half nicht.
- **Lösung:** Alles abgesteckt bis auf Strom und HDMI. Damit startete er sofort mit HP-Logo und Proxmox.
- **Ursache:** Nicht eindeutig geklärt, sehr wahrscheinlich hat ein angestecktes USB-Gerät den Start blockiert. Die Hardware war in Ordnung.
- **Gelernt:** Erst auf das Minimum abstecken, bevor man das Gehäuse öffnet. Und: Ohne Netzwerkkabel bringt ein Ping-Test nichts.

### Antennenabdeckung beim Öffnen abgebrochen
- **Ursache:** Das runde Teil oben rechts an der Rückseite des EliteDesk für eine Schraube gehalten. Es ist eine Plastikabdeckung für einen optionalen WLAN-Antennenanschluss.
- **Folge:** Rein kosmetisch. Die einzige Deckelschraube sitzt neben dem Schloss-Symbol.

## Hyper-V

### Linux-VMs: Out of memory bzw. Kernel Panic
- **Meldung:** `Out of memory: Killed process` bzw. `Kernel panic - not syncing: System is deadlocked on memory`
- **Ursache:** Dynamischer Arbeitsspeicher mit kleinem Minimum. Linux bekommt beim Start von Containern nicht schnell genug RAM nach.
- **Lösung:** Dynamischen Speicher aus, RAM fest zuweisen.

### Windows-Server-Setup bricht ab
- **Ursache:** Vermutlich zu wenig Arbeitsspeicher beim Setup (dynamisch, 2 GB Start).
- **Lösung:** 4 GB fest während der Installation.

### Secure Boot blockiert den Ubuntu-Installer
- **Meldung:** `The signed image's hash is not allowed (DB)`
- **Lösung:** Secure-Boot-Vorlage *Microsoft UEFI Certificate Authority* wählen.

### VM bootet nicht von der ISO (PXE-Start)
- **Ursache:** Beim Hinweis „Press any key to boot from CD or DVD“ keine Taste gedrückt.
- **Lösung:** VM zurücksetzen und sofort mehrmals die Leertaste drücken.

### Maximaler RAM lässt sich nicht senken
- **Ursache:** Bei laufender VM kann der Maximalwert nur erhöht werden.
- **Lösung:** VM herunterfahren, Wert ändern.

### Proxmox-Installer findet die ISO nicht
- **Meldung:** `searching for block device containing the ISO`, danach endlos `testing again in … seconds`
- **Ursache:** Generation-2-VM. Der Proxmox-Installer erkennt das DVD-Laufwerk am SCSI-Controller nicht.
- **Lösung:** PVE01 als **Generation 1** neu anlegen, dort hängt das DVD-Laufwerk am IDE-Controller.

### Grafischer Proxmox-Installer bricht ab
- **Meldung:** `Installation aborted - unable to continue`
- **Ursache:** Der grafische Installer kommt mit der Hyper-V-Grafik nicht klar. Netz und ISO waren in Ordnung (DHCP-Adresse von DC01 im Log).
- **Lösung:** Im Boot-Menü **Install Proxmox VE (Terminal UI)**.

### `@` lässt sich in der Hyper-V-Konsole nicht tippen
- **Ursache:** AltGr wird im Konsolenfenster nicht durchgereicht, *Zwischenablage → Text eingeben* half auch nicht.
- **Lösung:** Im Proxmox-Installer kurz das Tastaturlayout **U.S. English** wählen (`@` = Shift + 2). Kennwort nur aus Buchstaben ohne y/z und Ziffern, dann ist das Layout egal. Später im Webinterface ändern.

## Linux und Docker

### NetBox nach Neustart offline
- **Ursache:** Container ohne Neustart-Richtlinie.
- **Lösung:** `restart: unless-stopped` in der `docker-compose.override.yml`.

### Ubuntu: LVM nutzt nur die halbe Platte
- **Ursache:** Der Installer legt das logische Volume nur mit einem Teil der Volume Group an.
- **Lösung:** `sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv`

### Warpgate-Setup: `Permission denied (os error 13)`
- **Ursache:** Der Container läuft mit UID 1000, der Datenordner gehörte root.
- **Lösung:** `sudo chown -R 1000:1000 data`

### Warpgate: RDP `TCP connect timed out`
- **Ursache:** RDP war auf dem Zielserver nicht aktiviert.
- **Lösung:** RDP im Server-Manager aktivieren (Firewallregel wird mit freigegeben).
