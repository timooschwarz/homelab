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

### Proxmox startet nach dem Update nur bis `grub>`
- **Symptom:** Nach `apt full-upgrade` und Reboot kommt statt des Boot-Menüs nur die GRUB-Konsole `grub>`.
- **Sofort-Hilfe (von Hand starten):** In der Konsole gilt US-Tastatur (`=` auf ´, `-` auf ß, `/` auf -). Jede Zeile mit Enter, Dateinamen mit Tab ergänzen:
  ```
  set root=(lvm/pve-root)
  linux /boot/vmlinuz-<version>-pve root=/dev/mapper/pve-root ro quiet
  initrd /boot/initrd.img-<version>-pve
  boot
  ```
- **Dauerhafte Lösung:** In Proxmox GRUB neu auf die EFI-Partition schreiben:
  ```
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=proxmox
  update-grub
  ```
- **Gelernt:** Vorher mit `lsblk` und `efibootmgr -v` prüfen, von welcher Platte der Rechner startet. Alte Windows-Partitionen auf den anderen SSDs vor dem Einbinden mit **Wipe Disk** löschen.

### Proxmox bietet eine SSD nicht an („No Disks unused“)
- **Ursache:** Auf der Platte waren noch Partitionen eines alten Windows.
- **Lösung:** *pve01 → Disks* → Platte auswählen → **Wipe Disk**, danach taucht sie in LVM-Thin bzw. Directory auf.

### NVMe-Namen nach Neustart vertauscht
- **Symptom:** Die 1-TB-SSD hieß vor dem Neustart `/dev/nvme1n1`, danach `/dev/nvme0n1`.
- **Gelernt:** Linux nummeriert NVMe-Geräte beim Start in der Reihenfolge, in der sie sich melden. Platten immer an Seriennummer und Größe erkennen.

### Antennenabdeckung beim Öffnen abgebrochen
- **Ursache:** Das runde Teil oben rechts an der Rückseite des EliteDesk für eine Schraube gehalten. Es ist eine Plastikabdeckung für einen optionalen WLAN-Antennenanschluss.
- **Folge:** Rein kosmetisch. Die einzige Deckelschraube sitzt neben dem Schloss-Symbol.

## NAS (Raspberry Pi und OpenMediaVault)

### RAID-Sync kriecht, Timeouts am SATA-Controller
- **Symptom:** RAID 5 synchronisiert mit wenigen hundert K/sec. Im `dmesg` stehen `failed command: READ FPDMA QUEUED`, `timeout`, `hard resetting link` und I/O-Fehler auf mehreren SSDs.
- **Ursache:** Der JMB585 auf dem Penta HAT braucht seit Kernel 6.18 auf dem Pi 5 eine zusätzliche Einstellung.
- **Lösung:** In `/boot/firmware/config.txt` unter `[all]`: `dtoverlay=pcie-32bit-dma-pi5`, PCIe Gen 3 weglassen, neu starten.
- **Gelernt:** Fehler auf mehreren Platten gleichzeitig deuten auf Controller oder Verbindung, nicht auf die Platten.

### Keine Fehler mehr, Sync trotzdem bei 1 MB/s
- **Symptom:** Log sauber, SMART *PASSED* und *No Errors Logged*, aber eine SSD liest beim `dd`-Test 1 GB minutenlang nicht.
- **Ursache:** Samsung 840 EVO mit alter Firmware lesen lange liegende Daten extrem langsam. Der Resync liest alles, was noch von früher drauf ist.
- **Lösung:** RAID stoppen, Superblocks löschen, alle SSDs mit `blkdiscard` komplett trimmen, RAID neu anlegen. Danach ca. 110 MB/s. Dauerhaft: Firmware-Update mit Samsung Magician.
- **Gelernt:** Eine Platte einzeln mit `dd` lesen trennt „Platte langsam“ von „Controller kaputt“ in einer Minute.

### SSDs nach Änderung der config.txt verschwunden
- **Ursache:** Beim Löschen einer Zeile mit Strg+K in nano gingen die Abschnitte `[cm5]`, `[pi5]` und `[all]` mit. Die PCIe-Zeilen standen danach unter `[cm4]` und galten für den Pi 5 nicht.
- **Lösung:** Abschnitte wiederherstellen, PCIe-Zeilen unter `[all]`. Vor dem Neustart mit `tail -15 /boot/firmware/config.txt` prüfen.

### Pi nach der OMV-Installation nicht mehr erreichbar
- **Ursache:** OMV übernimmt das Netzwerk und holt per DHCP eine neue IP.
- **Lösung:** `ssh benutzer@pi-nas.local`, auf dem Pi `hostname -I`. Danach im Router eine DHCP-Reservierung setzen.

### Proxmox: „storage 'nas' is not online“
- **Ursache:** Die NFS-Freigabe war angelegt, der NFS-Dienst in OMV aber nicht eingeschaltet.
- **Lösung:** **Services → NFS → Settings → Enabled**, übernehmen, dann in Proxmox erneut **Add**.

### Fehler wegen eines Leerzeichens
- **Symptom:** OMV meldet bei den NFS-Extra-Options *doesn't match the pattern*, Proxmox beim Export *invalid format*.
- **Ursache:** Ein Leerzeichen am Anfang, meist vom Kopieren.
- **Lösung:** Feld leeren und von Hand tippen.

## Hyper-V

### Linux-VMs: Out of memory bzw. Kernel Panic
- **Meldung:** `Out of memory: Killed process` bzw. `Kernel panic - not syncing: System is deadlocked on memory`
- **Ursache:** Dynamischer Arbeitsspeicher mit kleinem Minimum. Linux bekommt beim Start von Containern nicht schnell genug RAM nach.
- **Lösung:** Dynamischen Speicher aus, RAM fest zuweisen.

### Windows-Server-Setup bricht ab
- **Ursache:** Vermutlich zu wenig Arbeitsspeicher beim Setup (dynamisch, 2 GB Start).
- **Lösung:** 4 GB fest während der Installation.

### Prüfpunkt-Kette kaputt, VM startet nicht mehr (`0xC03A0019`)
- **Symptom:** Vor dem Umzug auf Proxmox soll die Platte von NETBOX01 zusammengeführt werden. *Datenträger bearbeiten* und `Convert-VHD` brechen ab mit „Fehler beim Öffnen einer in der Kette höhergestellten virtuellen Festplatte (0xC03A0019)“. Die VM startet auch in Hyper-V nicht mehr.
- **Ursache:** Die VM lief auf einer `.avhdx`, Hyper-V kannte aber keine Prüfpunkte mehr dazu. Die Prüfpunkte wurden irgendwann gelöscht, ohne dass die Zusammenführung sauber durchlief. Die Dateinamen der Kette passen noch, intern aber nicht mehr. `Test-VHD` meldet trotzdem `True`.
- **Lösung:** Nicht reparierbar mit vertretbarem Aufwand. NetBox frisch als LXC auf Proxmox aufgesetzt.
- **Gelernt:** Vor dem Umzug prüfen, ob jede VM, die auf einer `.avhdx` läuft, auch Prüfpunkte in Hyper-V hat (`Get-VMHardDiskDrive` und `Get-VMSnapshot` vergleichen). Prüfpunkte nur bei ausgeschalteter VM löschen und warten, bis die Spalte *Status* leer ist, bevor die VM wieder startet. Hyper-V-Befehle immer in der 64-Bit-PowerShell, nicht in *(x86)*.

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

## Betrieb (Kapitel 18)

### LXC-Container kann keine Namen auflösen, seit Tailscale auf dem Host läuft
- **Symptom:** Beszel meldet beim Test der ntfy-URL `Client.Timeout exceeded`, im Container `curl: (6) Could not resolve host`. Ping auf `192.168.2.1` geht.
- **Ursache:** Tailscale stellt den DNS des Proxmox-Hosts auf MagicDNS (`100.100.100.100`) um. Container mit *DNS server: use host settings* übernehmen diese Adresse, erreichen sie aber nicht. Die Alarme sind seitdem nie angekommen.
- **Lösung:** Im Container **DNS → DNS server** fest auf `192.168.2.1`, danach **Reboot** (orange heißt: noch nicht aktiv). Bei allen Containern prüfen: `pct exec <ID> -- cat /etc/resolv.conf`.
- **Gelernt:** Benachrichtigungen nach dem Einrichten immer mit **Test** prüfen.

### Pi-hole startet nicht: `address already in use` auf Port 53
- **Ursache:** Auf dem Pi (OpenMediaVault nutzt systemd-networkd/-resolved) lauscht `systemd-resolved` auf `127.0.0.53:53` und `127.0.0.54:53`. Ein Container mit `"53:53"` will auf allen Adressen lauschen.
- **Lösung:** Port nur an die LAN-Adresse binden: `"192.168.2.234:53:53/tcp"` und `/udp`. Dafür braucht der Pi eine feste IP im Router.

### Homepage: `Host validation failed`
- **Ursache:** Die Adresse, unter der die Seite aufgerufen wird (z. B. `home.lab.test` über den Proxy), fehlt in `HOMEPAGE_ALLOWED_HOSTS`.
- **Lösung:** Eintragen, `docker compose up -d`.

### Monitore auf dem Pi für das Lab-Netz bleiben rot
- **Ursache:** Der Pi schickt `10.0.0.x` an den Router, der das Lab-Netz hinter pve01 nicht kennt.
- **Lösung:** Statische Route in eigener Netplan-Datei `/etc/netplan/90-lab-route.yaml` (`to: 10.0.0.0/24`, `via: 192.168.2.20`), `netplan apply`.

### Ein `.lab.test`-Name geht nicht, alle anderen schon
- **Symptom:** *Server Not Found*. `nslookup name 10.0.0.10` liefert nur `Name:` ohne Adresse.
- **Ursache:** Der CNAME existiert, sein Ziel ist vertippt.
- **Lösung:** CNAME löschen, neu anlegen und das Ziel per **Browse…** auswählen. Am Arbeits-PC `ipconfig /flushdns`.


## Umzug Hyper-V → Proxmox

### Linux-VM bleibt beim Start hängen, danach Emergency Mode
- **Meldung:** `A start job is running for /dev/disk/by-uuid/… (no limit)`, später `dracut-initqueue timeout`, `… does not exist`, `Entering emergency mode`
- **Ursache:** Ubuntu baut das initramfs mit `hostonly`, also nur mit den Treibern der Hyper-V-Hardware. Unter Proxmox fehlt der Treiber für den SATA-/VirtIO-Controller, die Root-Platte wird nicht gefunden.
- **Lösung:** VM in Hyper-V starten, `/etc/dracut.conf.d/90-proxmox.conf` mit `hostonly="no"` und `add_drivers+=" ahci sd_mod virtio_pci virtio_scsi virtio_blk virtio_net "` anlegen, `sudo dracut -f /boot/initrd.img-$(uname -r) $(uname -r)`, Prüfpunkt löschen, Platte neu hochladen und importieren ([Kapitel 17](anleitung/17-umzug-hyperv-proxmox.md#schritt-3--nur-linux-treiber-für-proxmox-nachrüsten-hyper-v-konsole)).
- **Gelernt:** Bei Linux-VMs die Treiber **vor** dem Kopieren nachrüsten. Windows bringt Treiber für SATA und E1000E selbst mit.

### `dracut --regenerate-all` bricht ab
- **Meldung:** `Can't write to /boot/efi/…/7.0.0-30-generic: Directory … does not exist`, `image generation failed`
- **Ursache:** Ein älterer Kernel ist noch registriert, sein Verzeichnis auf der EFI-Partition fehlt.
- **Lösung:** Nur das Image für den laufenden Kernel bauen: `sudo dracut -f /boot/initrd.img-$(uname -r) $(uname -r)`.

### Änderungen landen nicht in der kopierten `.vhdx`
- **Symptom:** Nach dem Treiber-Fix in Hyper-V bootet die VM auf Proxmox trotzdem nicht.
- **Ursache:** Beim Start hat Hyper-V einen **automatischen Prüfpunkt** angelegt, die Änderungen stecken in einer `.avhdx`.
- **Lösung:** Prüfpunkt löschen, warten bis zusammengeführt, dann kopieren. Unter **Einstellungen → Prüfpunkte** „Automatische Prüfpunkte verwenden“ abschalten.

### Linux-VM hat nach dem Umzug die falsche IP
- **Symptom:** Die Karte heißt `ens18` und hat eine DHCP-Adresse statt der festen IP.
- **Ursache:** Die Netplan-Datei des Ubuntu-Installers spricht die Karte über `match: macaddress` an. Proxmox vergibt eine neue MAC.
- **Lösung:** In `/etc/netplan/00-installer-config.yaml` nur `macaddress:` auf die neue MAC ändern (steht unter **Hardware → Network Device**), `sudo netplan apply`. Durch `set-name: eth0` heißt die Karte wieder `eth0`.

### Windows-Server nach dem Umzug nicht per RDP erreichbar, Ping zum DC geht
- **Symptom:** In der VM klappt `ping dc01.lab.test`, vom Arbeits-PC aus `Test-NetConnection … -Port 3389` aber nicht.
- **Ursache:** Beim Eintragen der festen IP an der neuen Karte wurde das **Standardgateway** vergessen. Die VM erreicht das Lab-Netz, kann aber nicht ins Heimnetz antworten.
- **Lösung:** Gateway `10.0.0.1` nachtragen.
- **Gelernt:** Passierte bei FS01 und CM01 gleich. Nach dem Speichern der festen IP (vor allem nach der Frage, ob die alte Konfiguration des verschwundenen Adapters entfernt werden soll) das Gateway in `ipconfig` kontrollieren. Schneller Test: Ping von pve01 geht, vom Arbeits-PC nicht.

### Name zeigt auf die alte IP
- **Symptom:** `ping client01.lab.test` vom Arbeits-PC geht an die alte Adresse, pve01 antwortet *Zielhost nicht erreichbar*.
- **Ursache:** Der DNS-Cache des Arbeits-PCs. DC01 kennt die neue Adresse schon (`nslookup client01.lab.test 10.0.0.10`).
- **Lösung:** `ipconfig /flushdns` am Arbeits-PC.
- **Gelernt:** `nslookup` ohne Server fragt immer den Router und ignoriert die NRPT-Regel für `lab.test`. Zum Testen `ping` oder `nslookup <name> 10.0.0.10`.

### SSH zur Hyper-V-VM geht nicht mehr
- **Ursache:** Die Route `10.0.0.0/24` über pve01 hat Vorrang vor dem wieder eingeschalteten Adapter vEthernet (LAB).
- **Lösung:** Für die letzten Arbeiten in Hyper-V die Konsole nehmen, nicht zwischen den Netzen hin- und herschalten.

### Paket-Download in der umgezogenen VM: `404 Not Found`
- **Ursache:** Die Paketliste ist veraltet, die Version liegt nicht mehr auf dem Spiegel.
- **Lösung:** Erst `sudo apt update`, dann installieren.

### Einfügen ins Terminal beginnt mit `^[[200~`
- **Ursache:** „Bracketed Paste“: Beim Einfügen mehrerer Zeilen schickt das Terminal Steuerzeichen mit, der erste Befehl wird zu `^[[200~sudo`.
- **Lösung:** Befehle einzeln einfügen oder die Zeichen vor Enter löschen.

### Strg+W schließt die Proxmox-Konsole
- **Ursache:** Die Konsole läuft im Browser, Strg+W schließt den Tab, statt in nano zu suchen.
- **Lösung:** „Auf Seite bleiben“, mit den Pfeiltasten navigieren. Strg+O und Strg+X funktionieren.

### Systemplatte nach dem Umstellen auf VirtIO verschwunden
- **Ursache:** Die Platte wurde bei laufender VM abgehängt. Proxmox merkt sich das nur als „pending“ (orange durchgestrichen); beim anschließenden Hin und Her wurde das Volume gelöscht. `lvs | grep vm-120` zeigte nur noch EFI- und Hilfsplatte, `qm rescan --vmid 120` fand nichts.
- **Lösung:** Die Original-`.vhdx` neu importieren (`qm disk import 120 /mnt/pve/backup/import/CM01.vhdx vmdata`), erst als SATA starten, Treiber prüfen, dann umstellen wie in [Kapitel 17](anleitung/17-umzug-hyperv-proxmox.md#windows-nachträglich-auf-virtio-umstellen). Merke: Import-Dateien erst löschen, wenn ein Proxmox-Backup existiert, und Hardware nur bei ausgeschalteter VM umbauen.

## VLAN (Kapitel 19)

### Testclient bekommt mit VLAN-ID 10 nur 169.254.x.x
- **Symptom:** CLIENT02 in Hyper-V mit VLAN-ID 10 bekommt keine Adresse von DC01. Ohne VLAN-ID gibt es sofort eine Heimnetz-Adresse.
- **Fehlersuche:** `pktmon` am Arbeits-PC zeigte, dass die DHCP-Anfrage bis zum Treiber der Netzwerkkarte kommt. `tcpdump -eni nic0 vlan 10 and port 67` auf pve01 sah nichts. Ein Treiber-Update der Intel I226-V und Abschalten von `rx-vlan-offload` auf pve01 änderten nichts. Entscheidend war `ip -s link show nic0.10`: **TX** über 6000 Pakete, **RX 0**.
- **Ursache:** VLAN 10 war auf Switch-Port 1 und 7 eingerichtet. Der Mini-PC steckt nach dem Rack-Umbau aber in **Port 5**. Seine getaggten Pakete warf der Switch weg, die des Clients gingen ans falsche Gerät.
- **Lösung:** VLAN 10 mit Port 5 und 7 tagged neu gespeichert. Sofort danach zählte RX hoch und der Client bekam `10.0.0.108`.
- **Gelernt:** Port-Belegung vor VLAN-Arbeit mit *Monitoring → Port Statistics* bestätigen, nicht aus dem Plan übernehmen. **RX 0 / TX hoch** am VLAN-Interface heißt: Es kommt nichts zurück, zuerst Switch-Ports prüfen.

### Nach PC-Neustart: Hyper-V-Switch „Netzwerkkabel wurde entfernt“
- **Symptom:** Nach einem Neustart hat der PC zwar Internet, aber direkt über **Ethernet**. **vEthernet (Extern)** und die VM melden *Medium getrennt*.
- **Ursache:** Nach einer Änderung an den erweiterten Treibereinstellungen (*Paketpriorität und VLAN*) hat sich der externe Hyper-V-Switch von der Karte gelöst.
- **Lösung:** Switch `Extern` im Manager für virtuelle Switches entfernen, neu anlegen (*Gemeinsames Verwenden* an), VM wieder anhängen und VLAN-ID prüfen.

### PC ohne Netz nach Umstellen von „Paketpriorität und VLAN“
- **Ursache:** Der Intel-Treiber kam mit dem externen Hyper-V-Switch nach dem Umstellen nicht mehr klar.
- **Lösung:** Einstellung zurück auf *aktiviert*, PC neu starten. Bei der I226-V muss man daran nichts ändern.

### Arbeits-PC hängt am Switch nur mit 100 Mbit (I226-V)
**Ursache:** Die Intel I226-V handelt mit *Energieeffizientes Ethernet* an manchen Switches nur 100 Mbit aus. Im Switch steht bei dem Port **100Full** und es tauchen ein paar RxBadPkt auf, der Kabeltest meldet trotzdem *Normal*.
**Lösung:** `ncpa.cpl` → Ethernet → **Eigenschaften → Konfigurieren → Erweitert**: *Energieeffizientes Ethernet* **Aus** (falls vorhanden auch *Verbindungsgeschwindigkeit bei Leerlauf reduzieren*), *Geschwindigkeit und Duplex* auf **Automatische Aushandlung**. Danach zeigt der Port **1000Full**. Erst wenn das nicht hilft, Kabel tauschen.

## Rack-Display (Kapitel 20)

### Watt-Anzeige bleibt bei „– W“
**Ursache:** Die Seite war als `file://` geöffnet. Chromium blockt dann Abfragen an den Shelly im Netz (CORS).
**Lösung:** Seite über den lokalen kiosk-server laden (`http://127.0.0.1:8099/…`), der holt die Daten selbst ab.

### Display nach `ddcutil setvcp d6 4` nicht mehr ansprechbar
**Ursache:** Der Befehl schaltet das Display hart aus (DPMS-Off). Danach antwortet es nicht mehr per DDC, `ddcutil` meldet *Display not found*.
**Lösung:** Display kurz vom Strom trennen. Für den Nachtbetrieb stattdessen den USB-Strom per `uhubctl` schalten.

### Nachtmodus per Cron schaltet nicht, von Hand schon
**Ursache:** Cron startet mit minimalem `PATH`, `uhubctl` liegt in `/usr/sbin` und wird nicht gefunden. Die Fehlermeldung verschwindet in `/dev/null`.
**Lösung:** `PATH=…` als zweite Zeile ins Skript, testen mit `sudo env -i /usr/local/bin/display-zeitplan`.

### `uhubctl`: *No compatible devices detected* am Mini-PC
**Ursache:** Die USB-Controller des HP können den Strom einzelner Ports nicht schalten.
**Lösung:** Display an den Pi 5 hängen, dort schaltet `uhubctl` die Hubs 1–4 (nur gemeinsam).

### Mauszeiger steht mitten im Kiosk-Bild
**Ursache:** cage zeigt den Zeiger, solange er nicht bewegt wird. Ein leeres Cursor-Theme hilft nicht.
**Lösung:** `cursor:none` auf der Seite und `wlrctl pointer move 5000 5000` nach dem Start, auf dem Pi zweimal (nach 15 und 45 Sekunden).

## Immich (Kapitel 21)

### Immich startet nach einem Neustart nicht
**Ursache:** Die VM war schneller oben als das Pi-NAS, `/mnt/immich` war leer. Immich prüft Markierungsdateien im Upload-Ordner und verweigert dann den Start, statt ins Leere zu schreiben.
**Lösung:** `sudo mount -a && cd ~/immich && docker compose up -d`. Dauerhaft: in Proxmox bei der VM eine Startverzögerung setzen.

### iPhone-Sicherung kommt kaum voran
**Ursache:** Mit *iPhone-Speicher optimieren* liegen die Originale in iCloud. Die App muss jedes Foto einzeln holen, und iOS bremst Apps im Hintergrund.
**Lösung:** App im Vordergrund offen lassen, Ladekabel, WLAN, automatische Sperre kurz auf *Nie*. *Originale laden und behalten* nur, wenn das iPhone genug Platz für alle Fotos hat.

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
