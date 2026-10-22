# Kapitel 16 · NAS mit Raspberry Pi 5 und OpenMediaVault als Backup-Ziel

[← Kapitel 15](15-proxmox-host.md) · [Übersicht](../../README.md#inhaltsverzeichnis) · [Hardware und Rack](../hardware.md)

[![Proxmox](https://img.shields.io/badge/-Proxmox-E57000?style=flat-square)](../../README.md#thema-proxmox) [![Linux & Docker](https://img.shields.io/badge/-Linux%20%26%20Docker-E95420?style=flat-square)](../../README.md#thema-linux) [![Netzwerk](https://img.shields.io/badge/-Netzwerk-1D9E75?style=flat-square)](../../README.md#thema-netz)

> **Ziel:** Ein Raspberry Pi 5 mit vier SATA-SSDs läuft als NAS mit OpenMediaVault. Die SSDs bilden ein RAID 5, Proxmox auf pve01 sichert jede Nacht alle VMs und Container per NFS darauf. Damit liegt eine Kopie der Backups außerhalb des Proxmox-Hosts.
> **Dauer:** ca. 3 Stunden plus 2–3 Stunden Synchronisieren im Hintergrund · **Wo:** Pi (Zusammenbau), Arbeits-PC (Imager, SSH, Browser), pve01 (Weboberfläche)
> **Version:** Raspberry Pi OS Lite 64-bit (Trixie, Kernel 6.18), OpenMediaVault 8, Proxmox VE 9.2

| Was | Wert |
|---|---|
| Hardware | Raspberry Pi 5 (4 GB), Radxa Penta SATA HAT (JMB585), aktiver Kühler, 12-V-Netzteil |
| Datenträger | microSD 64 GB für das System, 4× Samsung 840 EVO 1 TB für die Daten |
| Hostname | `pi-nas`, erreichbar als `pi-nas.local` |
| IP | per DHCP, im Router fest an die MAC gebunden (bei mir `192.168.2.234`) |
| Speicher | RAID 5 aus 4 SSDs, EXT4, ca. 2,7 TB nutzbar |
| Freigaben | `backup-pve` per NFS nur für pve01, `daten` für SMB |

> [!NOTE]
> 4 GB RAM reichen für OMV und ein paar Docker-Container. ZFS wäre auf dem Pi mit 4 GB knapp und braucht Kernel-Module, deshalb hier klassisches Software-RAID mit `mdadm`.

## Schritt 1 · Zusammenbauen (Tisch, alles stromlos)

1. **Kühler** auf den Pi drücken, bis die Push-Pins einrasten, Lüfterkabel in den Stecker **FAN**.
2. **Abstandsbolzen** in die vier Löcher des Pi schrauben.
3. **Flachbandkabel (FPC):** Am Pi den kleinen Bügel am Anschluss **PCIe** hochklappen, Kabel bis zum Anschlag einschieben, Bügel herunterdrücken. Am HAT genauso. Ausrichtung wie im Bild von Radxa, Kabel nicht knicken.
4. **HAT** gerade auf die 40-Pin-Leiste drücken und verschrauben. Über diese Pins bekommt der Pi seinen Strom vom HAT.
5. **SSDs** einstecken und mit den beiliegenden Rahmen sichern. Das geht auch später, aber **nie im laufenden Betrieb**.
6. Strom **nur** über die 12-V-Buchse am HAT, **nicht** zusätzlich USB-C am Pi.

> [!WARNING]
> Mit HAT, Kühler und SSDs ist der Turm deutlich höher als 1 HE. Vor dem Einbau ins Rack nachmessen. In meinem Rack passt er unter dem Fachboden des Mini-PCs **nicht** in 2 HE, siehe [Hardware](../hardware.md).

## Schritt 2 · Raspberry Pi OS auf die microSD (Arbeits-PC)

1. **Raspberry Pi Imager** öffnen → Gerät **Raspberry Pi 5** → Betriebssystem **Raspberry Pi OS (other) → Raspberry Pi OS Lite (64-bit)**. *Lite* heißt nur „ohne Desktop“, für OMV ist das Pflicht.
2. Unter **Anpassung**: Hostname `pi-nas`, Zeitzone und Tastatur, eigener Benutzername (nicht `pi` oder `admin`), Kennwort aus dem Passwortmanager. **WLAN leer lassen**, bei **Fernzugriff** SSH mit Passwort aktivieren.
3. Nicht auf **Anpassung überspringen** klicken, sonst fehlt SSH.
4. **Schreiben**, die Überprüfung durchlaufen lassen.

## Schritt 3 · Erster Start und PCIe einschalten (SSH)

1. microSD in den Pi, LAN-Kabel, dann 12 V. Der Pi startet ohne Knopfdruck.
2. Im Windows-Terminal: `ssh benutzer@pi-nas.local`. Klappt der Name nicht, die IP im Router nachsehen.
3. Updates:
   ```
   sudo apt update && sudo apt full-upgrade -y
   ```
4. PCIe für den HAT einschalten: `sudo nano /boot/firmware/config.txt`, ganz unten **unter `[all]`** ergänzen:
   ```
   [all]
   dtparam=pciex1
   dtoverlay=pcie-32bit-dma-pi5
   ```
   Die zweite Zeile braucht der JMB585 seit Kernel 6.18 auf dem Pi 5, ohne sie gab es bei mir Timeouts und I/O-Fehler (siehe unten). Speichern mit **Strg+O**, **Enter**, **Strg+X**.

   > [!WARNING]
   > Die Zeilen müssen unter `[all]` stehen. Stehen sie unter `[cm4]` oder `[cm5]`, gelten sie für den Pi 5 nicht und die SSDs fehlen. Mir ist das passiert, weil beim Löschen mit **Strg+K** ein paar Zeilen zu viel verschwunden sind.

5. Neu starten mit `sudo reboot`, wieder anmelden und prüfen:
   ```
   lspci
   lsblk
   ```
   `lspci` muss **JMicron JMB58x AHCI SATA controller** zeigen, `lsblk` vier Platten `sda`–`sdd` mit je ca. 931,5G.
6. Zustand der SSDs prüfen, gerade bei gebrauchten:
   ```
   sudo apt install -y smartmontools
   for d in a b c d; do echo "== sd$d"; sudo smartctl -H -A /dev/sd$d | grep -Ei "result|Reallocated|Wear_Leveling|Power_On"; done
   ```
   Alle müssen **PASSED** zeigen, *Reallocated_Sector_Ct* sollte 0 sein.

> [!TIP]
> PCIe Gen 3 (`dtparam=pciex1_gen=3`) ist auf dem Pi 5 offiziell nicht unterstützt. Für ein NAS am Gigabit-LAN reicht Gen 2 (ca. 400 MB/s pro SSD gemessen) völlig, deshalb lasse ich es weg.

## Schritt 4 · OpenMediaVault installieren (SSH)

Das Install-Script stellt das Netzwerk um, die SSH-Verbindung bricht dabei ab. Deshalb in **tmux** starten, dann läuft es weiter:

```
sudo apt install -y tmux
tmux
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/preinstall | sudo bash
sudo reboot
```

Wieder anmelden, `tmux`, dann:

```
wget -O - https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/install | sudo bash
```

Dauert 15–30 Minuten, danach startet der Pi neu. Bricht SSH ab: neu verbinden, `tmux attach`. Bei „no sessions“ ist das Script fertig.

> [!NOTE]
> Nach der Installation hat der Pi oft eine **neue IP**, weil OMV das Netzwerk übernimmt und neu per DHCP fragt. `pi-nas.local` funktioniert weiter, oder auf dem Pi `hostname -I`.

1. Browser: `http://pi-nas.local`, Anmeldung `admin` / `openmediavault`.
2. Sofort oben rechts **Benutzer-Symbol → Change Password**.
3. Im Router eine feste Zuweisung (DHCP-Reservierung) für `pi-nas` anlegen. Sonst ändert sich die IP irgendwann und Proxmox findet das NAS nicht mehr.

> [!TIP]
> In OMV erscheint nach fast jeder Änderung oben ein **gelber Balken** *Pending configuration changes*. Erst mit dem **Häkchen** werden die Änderungen wirklich übernommen.

## Schritt 5 · RAID 5 anlegen (OMV)

1. **System → Plugins** → Suche `md` → **openmediavault-md** → **Install** (Download-Pfeil). Danach F5, unter **Storage** erscheint **Multiple Device**.
2. **Storage → Disks** → `sda` bis `sdd` nacheinander → **Wipe** → **Quick**. Nicht `mmcblk0`, das ist die microSD.
3. **Storage → Multiple Device → Create** → Level **RAID 5**, alle vier SSDs → **Save** → gelben Balken übernehmen.
4. Das RAID synchronisiert jetzt im Hintergrund. Fortschritt per SSH:
   ```
   cat /proc/mdstat
   ```
   Mit SSDs sollten dort **um 100.000K/sec** und ein paar Stunden Restzeit stehen.

> [!IMPORTANT]
> Steht dort nur ein paar hundert K/sec und eine Restzeit von Wochen, **nicht weitermachen**. Bei mir lag es an den alten 840 EVO, siehe [Häufige Fehler](#häufige-fehler). Die Lösung (komplett trimmen) ist schnell, solange noch keine Daten drauf sind.

Warum RAID 5: Eine SSD darf ausfallen, es bleiben ca. 2,7 von 4 TB nutzbar. Da das NAS die **zweite** Kopie der Backups ist, reicht das. RAID ersetzt kein Backup.

## Schritt 6 · Dateisystem und Ordner (OMV)

1. **Storage → File Systems → Create → EXT4** → Gerät `/dev/md0` → **Save**. Danach einhängen (**Mount**), gelben Balken übernehmen. Status muss **Available** sein.
2. **Storage → Shared Folders → Create**, zweimal:
   - `backup-pve` auf `/dev/md0`, für Proxmox
   - `daten` auf `/dev/md0`, allgemeine Ablage

## Schritt 7 · NFS-Freigabe für pve01 (OMV)

1. **Services → NFS → Settings** → **Enabled** anhaken → **Save** → übernehmen. Die Versionen (NFSv3 bis 4.2) so lassen.
2. **Services → NFS → Shares → Create**:
   - **Shared folder:** `backup-pve`
   - **Client:** `192.168.2.20/32`, also nur pve01
   - **Permission:** Read/Write
   - **Extra options:** `subtree_check,insecure,no_root_squash` (Proxmox schreibt als root)
3. **Save** → übernehmen. Die Freigabe heißt nach außen `/export/backup-pve`.

## Schritt 8 · In Proxmox einbinden und Backup-Job (pve01)

1. **Datacenter → Storage → Add → NFS**:
   - **ID:** `nas`
   - **Server:** IP des Pi
   - **Export:** `/export/backup-pve`. Bleibt das Dropdown leer, von Hand eintippen.
   - **Content:** nur **Backup**
2. **Datacenter → Backup → Add**:
   - Storage `nas`, **Schedule** `03:30` (das Feld ist frei beschreibbar, eine Uhrzeit heißt „jeden Tag“), **Selection mode** All, Mode Snapshot, ZSTD
   - Reiter **Retention:** Keep Daily `7`, Weekly `4`, Monthly `3`
3. Job markieren → **Run now** → unten unter **Tasks** muss **OK** stehen, unter **nas → Backups** liegt die Datei.

Mit *Selection mode All* werden auch VMs, die später dazukommen, automatisch mitgesichert.

## Prüfen

- [ ] `lspci` zeigt den JMicron-Controller, `lsblk` vier SSDs
- [ ] `sudo dmesg | grep -iE "error|timeout|reset"` zeigt keine SATA-Fehler
- [ ] OMV: **Multiple Device** zeigt `md0`, RAID 5, *clean* (nach dem Synchronisieren)
- [ ] OMV: Dateisystem auf `md0` **Available**, beide Shared Folders da
- [ ] Proxmox: Storage `nas` aktiv, Größe ca. 2,7 TB
- [ ] Backup-Job läuft mit **OK**, Datei liegt auf `nas`

## Häufige Fehler

| Problem | Ursache | Lösung |
|---|---|---|
| RAID-Sync mit wenigen hundert K/sec, im Log `failed command: READ FPDMA QUEUED`, `timeout`, `hard resetting link`, I/O-Fehler auf mehreren SSDs | JMB585 auf dem Pi 5 mit Kernel 6.18 | `dtoverlay=pcie-32bit-dma-pi5` unter `[all]` in der config.txt, Gen 3 weglassen, neu starten |
| Danach keine Fehler mehr im Log, Sync aber weiter ca. 1 MB/s, einzelne SSD liest beim `dd`-Test fast nichts | Bekannte Lese-Schwäche alter Daten bei Samsung 840 EVO mit alter Firmware | RAID stoppen, alle SSDs per TRIM leeren und RAID neu anlegen (siehe unten). Dauerhaft hilft ein Firmware-Update mit Samsung Magician |
| Nach Änderung der config.txt keine SSDs mehr, `lsblk` ohne `sda` | PCIe-Zeilen stehen unter `[cm4]`/`[cm5]` statt `[all]` | Abschnitte wiederherstellen, Zeilen unter `[all]` |
| `ssh pi-nas.local` nach dem OMV-Preinstall: *Host unbekannt* | Netzwerk wurde umgestellt, Namensdienst kurz weg | Direkt per IP verbinden |
| SSH auf die alte IP: *Connection timed out* | Neue IP nach der OMV-Installation | `pi-nas.local` oder IP im Router nachsehen, danach DHCP-Reservierung setzen |
| Zeichensalat wie `11;rgb:0c0c/…` in tmux | Windows Terminal antwortet auf eine Farbanfrage | Harmlos, **Strg+C** und weiter |
| *Multiple Device* fehlt in OMV | Plugin `openmediavault-md` fehlt | Unter **System → Plugins** installieren, F5 |
| *504 Gateway Time-out* beim RAID-Anlegen oder in der Liste | OMV wartet auf eine langsame Abfrage | Nicht nochmal klicken, warten, F5. Kommt es dauerhaft, hängen Zugriffe auf die SSDs |
| NFS-Share: *doesn't match the pattern* | Leerzeichen am Anfang der Extra options | Leerzeichen entfernen |
| Proxmox: *export: invalid format* | Leerzeichen im Feld Export | Pfad von Hand tippen |
| Proxmox: *storage 'nas' is not online* | NFS in OMV nicht eingeschaltet | **Services → NFS → Settings → Enabled** |
| `sudo reboot` hängt, Pi nicht mehr erreichbar | Beim Herunterfahren wartet Linux auf hängende SSD-Zugriffe | Stecker ziehen, 10 Sekunden warten. Unbedenklich, solange keine Daten drauf sind |

**Langsame SSD finden und alle neu trimmen.** Erst den Sync anhalten (`echo frozen | sudo tee /sys/block/md0/md/sync_action`), dann jede SSD einzeln lesen lassen:

```
for d in a b c d; do echo "== sd$d"; sudo dd if=/dev/sd$d of=/dev/null bs=1M count=1000 iflag=direct 2>&1 | tail -1; done
```

Normal sind 300–450 MB/s. Hängt eine SSD dabei und zeigt `sudo smartctl -l error /dev/sdX` trotzdem *No Errors Logged*, ist die Platte nicht defekt, sondern liest alte Daten extrem langsam. **Achtung, löscht alles auf den SSDs:**

```
sudo mdadm --stop /dev/md0
sudo mdadm --zero-superblock /dev/sda /dev/sdb /dev/sdc /dev/sdd
for d in a b c d; do sudo blkdiscard -f /dev/sd$d; done
```

Danach den `dd`-Test wiederholen (bei mir 440, 162, 440, 440 MB/s) und das RAID in OMV neu anlegen. Der Sync lief dann mit ca. 110 MB/s.

Wie es weitergeht: SMB-Freigabe `daten`, Beszel-Agent auf dem Pi, Benachrichtigungen in OMV, Uptime Kuma als Wächter für pve01. [Roadmap](../roadmap.md)
