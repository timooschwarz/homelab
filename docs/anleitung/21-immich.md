# Kapitel 21 · Immich: eigene Foto-Cloud auf pve01

[← Kapitel 20](20-rack-display.md) · [Übersicht](../../README.md#inhaltsverzeichnis) · [Fehlerbehebung](../fehlerbehebung.md#immich-kapitel-21)

[![Linux & Docker](https://img.shields.io/badge/-Linux%20%26%20Docker-E95420?style=flat-square)](../../README.md#thema-linux) [![Proxmox](https://img.shields.io/badge/-Proxmox-E57000?style=flat-square)](../../README.md#thema-proxmox)

> **Ziel:** [Immich](https://immich.app) sichert die Fotos und Videos vom Handy automatisch ins eigene Netz, mit Zeitstrahl, Karte, Gesichtserkennung und Suche nach Bildinhalten. Immich läuft in einer eigenen VM auf pve01, die Fotos liegen auf dem RAID des Pi-NAS.
> **Dauer:** ca. 1,5 Stunden plus erste Sicherung vom Handy (je nach Menge Stunden bis über Nacht) · **Wo:** Proxmox (Browser), OMV (Browser), SSH auf die neue VM, NPM, DC01
> **Voraussetzung:** pve01 ([Kapitel 15](15-proxmox-host.md)), Pi-NAS mit NFS ([Kapitel 16](16-pi-nas.md)), Nginx Proxy Manager und Tailscale ([Kapitel 18](18-betrieb.md))

```text
Handy (Immich-App) ──WLAN / Tailscale──► VM immich 192.168.2.23:2283 (pve01)
                                            ├─ Postgres, Redis, Machine Learning (lokale VM-Platte)
                                            └─ /mnt/immich ──NFS──► pi-nas /export/immich (RAID 5)
Arbeits-PC ── immich.lab.test ──► NPM auf TOOLS01 ──► 192.168.2.23:2283
```

| Was | Wert |
|---|---|
| VM | ID `102`, Name `immich`, Ubuntu Server 26.04.1 LTS, 4 Kerne, 8 GB RAM, 40 GB auf `vmdata` |
| Netz | **Heimnetz** (`vmbr0`), feste IP `192.168.2.23` |
| Fotos | NFS-Freigabe `immich` vom Pi-NAS, eingehängt unter `/mnt/immich` |
| Datenbank | `~/immich/postgres` auf der VM-Platte |
| Adresse | App: `http://192.168.2.23:2283` · PC: `http://immich.lab.test` |

**Warum auf pve01 und nicht auf dem Pi?** Immich will mindestens 6 GB, besser 8 GB RAM. Mit 4 GB läuft es nur ohne Machine Learning, also ohne Gesichter und Bildsuche. Der Pi trägt außerdem schon OMV, Pi-hole, Uptime Kuma und den Kiosk.

**Warum im Heimnetz?** Immich ist ein Dienst fürs Handy, kein Testobjekt. Das Handy erreicht `192.168.2.23` zu Hause direkt und unterwegs über Tailscale (pve01 und der Pi geben das Heimnetz frei). Den Namen `immich.lab.test` kennt nur, wer über DC01 auflöst, also der Arbeits-PC.

**Warum die Datenbank nicht aufs NAS?** Die Immich-Doku verlangt für Postgres eine lokale Platte, ausdrücklich keine Netzwerkfreigabe. Die Datenbank ist nur wenige GB groß und wird mit dem nächtlichen Proxmox-Backup der VM gesichert.

## Schritt 1 · NFS-Freigabe (OMV)

1. **Storage → Shared Folders → Create**: Name `immich`, Dateisystem das RAID → **Save**.
2. **Services → NFS → Shares → Create**:
   - **Shared folder:** `immich`
   - **Client:** `192.168.2.23`
   - **Privilege:** Read/Write
   - **Extra options:** `subtree_check,insecure,no_root_squash` (die Container schreiben als root)
3. **Save**, oben die Änderungen übernehmen.

## Schritt 2 · VM anlegen (Proxmox)

1. **backup → ISO Images → Download from URL**: `https://releases.ubuntu.com/26.04.1/ubuntu-26.04.1-live-server-amd64.iso` → **Query URL** → **Download**. Ohne diesen Schritt bleibt im Assistenten das Feld *ISO image* leer.
2. **Create VM**:

   | Reiter | Einstellung |
   |---|---|
   | General | ID `102`, Name `immich` |
   | OS | Storage `backup`, die Ubuntu-ISO, Linux 7.x – 2.6 Kernel |
   | System | Machine **q35**, BIOS SeaBIOS, SCSI Controller VirtIO SCSI single, **Qemu Agent an** |
   | Disks | `vmdata`, **40 GB**, **Discard an** |
   | CPU | 4 Cores, Type **host** |
   | Memory | 8192 |
   | Network | Bridge **vmbr0**, VirtIO |

3. Danach **Options → Start at boot → Yes**. Bei *Start/Shutdown order* eine Startverzögerung lassen, damit das Pi-NAS schon da ist (z. B. Order `3`, Startup delay `30`).

## Schritt 3 · Ubuntu installieren (Konsole der VM)

- **Network:** bei der Karte **Edit IPv4 → Manual**: Subnet `192.168.2.0/24`, Address `192.168.2.23`, Gateway `192.168.2.1`, Name servers `192.168.2.1`
- **Storage:** *Use an entire disk*, aber das Häkchen bei **Set up this disk as an LVM group raus**. Mit LVM nutzt Ubuntu nur die halbe Platte. Auf der Übersicht muss `/` mit ca. 40 GB als ext4 stehen.
- **Profile:** Servername `immich`, eigener Benutzer, Passwort in den Passwortmanager
- **Ubuntu Pro:** Skip · **SSH:** *Install OpenSSH server* an · **Snaps:** keine

Nach dem Neustart per SSH auf `192.168.2.23`:

```bash
sudo timedatectl set-timezone Europe/Berlin
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y qemu-guest-agent nfs-common
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
sudo reboot
```

**Prüfen** (nach dem Neustart):

```bash
docker --version && systemctl is-active qemu-guest-agent && showmount -e 192.168.2.234
```

`/export/immich` muss mit `192.168.2.23` in der Liste stehen.

## Schritt 4 · NFS einhängen (VM)

```bash
sudo mkdir -p /mnt/immich
echo '192.168.2.234:/export/immich /mnt/immich nfs defaults,_netdev 0 0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a
sudo touch /mnt/immich/test && ls -l /mnt/immich && sudo rm /mnt/immich/test && df -h /mnt/immich
```

`df` zeigt die Größe des RAID auf dem Pi-NAS.

## Schritt 5 · Immich installieren (VM)

```bash
mkdir ~/immich && cd ~/immich
wget -qO docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml
wget -qO .env https://github.com/immich-app/immich/releases/latest/download/example.env
sed -i "s|^UPLOAD_LOCATION=.*|UPLOAD_LOCATION=/mnt/immich|; s|^DB_DATA_LOCATION=.*|DB_DATA_LOCATION=./postgres|; s|^# *TZ=.*|TZ=Europe/Berlin|; s|^DB_PASSWORD=.*|DB_PASSWORD=$(openssl rand -hex 20)|" .env
grep -vE '^#|^$' .env
```

Das zufällige `DB_PASSWORD` in den Passwortmanager übernehmen. Dann:

```bash
docker compose up -d
docker compose ps
```

Nach ein bis zwei Minuten stehen `immich_server`, `immich_machine_learning`, `immich_postgres` und `immich_redis` auf **healthy**. Nur der Server hat einen Port nach außen (`2283`).

## Schritt 6 · Einrichten (Browser)

`http://192.168.2.23:2283` → **Getting Started** → Admin-Konto anlegen. Im Assistenten:

| Seite | Empfehlung |
|---|---|
| Sprache | Deutsch |
| Privatsphäre auf dem Server | **Karte** und **Versionsprüfung** an lassen. Es werden nur Kartenkacheln bzw. eine Versionsabfrage geladen, keine Fotos |
| Speichervorlage | **YYYY/MM/DD**. Die Dateien liegen dann lesbar nach Datum auf dem NAS (`library/<benutzer>/2026/10/31/…`), auch ohne Immich nutzbar |
| Sicherungen | an lassen: tägliches Datenbank-Backup nach `/mnt/immich/backups`, also aufs NAS |

## Schritt 7 · Name über den Proxy (NPM, DC01)

1. **NPM → Proxy Hosts → Add Proxy Host**: Domain `immich.lab.test`, Scheme `http`, Forward `192.168.2.23`, Port `2283`, **Websockets Support** an.
2. Reiter **Advanced**, sonst brechen große Videos beim Hochladen ab:

   ```nginx
   client_max_body_size 50000M;
   proxy_read_timeout 600s;
   proxy_send_timeout 600s;
   send_timeout 600s;
   ```

3. **DC01 → DNS Manager → lab.test → New Alias (CNAME)**: `immich` → über **Browse…** `tools01.lab.test`.

## Schritt 8 · Handy

1. Immich-App installieren, Server-URL `http://192.168.2.23:2283` (mit `http://`, Port nicht vergessen), mit dem Admin-Konto anmelden.
2. Wolken-Symbol → **Alben auswählen**. *Zuletzt* enthält bereits alle Fotos, doppelt ausgewählte Alben sind kein Problem: Immich erkennt jedes Foto an seiner Prüfsumme. Alben, die nicht in Immich landen sollen (z. B. *Ausgeblendet*), auf **Ausschließen** setzen.
3. **Sicherung aktivieren.** Die App bereitet erst alle Fotos vor (Prüfsummen), dann lädt sie hoch.

> [!TIP]
> **Erste große Sicherung am iPhone:** App offen lassen, Handy am Ladekabel und im WLAN, automatische Sperre kurz auf *Nie*. Im Hintergrund lässt iOS die App nur in kurzen Schüben arbeiten. Liegen die Originale in iCloud (*iPhone-Speicher optimieren*), holt das iPhone jedes Foto erst aus iCloud, das dauert deutlich länger, braucht aber keinen zusätzlichen Platz. Danach reicht die Hintergrund-Sicherung (*Hintergrundaktualisierung* für Immich an, App nicht wegwischen).

Währenddessen erzeugt der Server Vorschaubilder, wandelt Videos um und erkennt Gesichter. Fortschritt: **Administration → Jobs**.

## Schritt 9 · Überwachung

- **Uptime Kuma** (TOOLS01): HTTP-Monitor auf `http://192.168.2.23:2283/api/server/ping`
- **Beszel:** Agent in der VM installieren wie bei TOOLS01 ([Kapitel 15](15-proxmox-host.md)), dann erscheint `immich` auch als Kachel auf dem [Rack-Display](20-rack-display.md) (Name in `SYSTEME` ergänzen)

## Sicherung: was ist wo?

| Daten | Wo | Gesichert durch |
|---|---|---|
| VM inkl. Datenbank | pve01, `vmdata` | nächtliches Proxmox-Backup |
| Datenbank-Dump | `/mnt/immich/backups` (NAS) | Immich selbst, täglich |
| Fotos und Videos | `/mnt/immich/library` (NAS, RAID 5) | **nur das RAID** |

> [!WARNING]
> Das Proxmox-Backup enthält die Fotos **nicht**, sie liegen auf dem NFS. RAID schützt vor einer defekten Platte, nicht vor Löschen, einem defekten Pi oder Ransomware. Fotos erst dann vom Handy löschen, wenn es eine zweite Kopie gibt (externe Platte oder Cloud).

## Prüfen

- [ ] `docker compose ps` zeigt vier Container *healthy*
- [ ] Nach einem Neustart der VM ist `/mnt/immich` eingehängt und Immich erreichbar
- [ ] Ein Testfoto vom Handy taucht im Browser auf und liegt auf dem NAS unter `library/…/JJJJ/MM/TT/`
- [ ] `http://immich.lab.test` öffnet am Arbeits-PC Immich, ein großes Video lässt sich hochladen
- [ ] Uptime Kuma zeigt Immich grün

## Häufige Fehler

| Problem | Ursache | Lösung |
|---|---|---|
| Feld *ISO image* im VM-Assistenten leer | ISO noch nicht in Proxmox | **backup → ISO Images → Download from URL** |
| `/` nur ca. 20 GB groß | Installer mit LVM legt nur die halbe Platte an | ohne LVM installieren, sonst `lvextend -r -l +100%FREE` |
| `mount -a`: *access denied by server* | Client-IP in der OMV-Freigabe falsch oder nicht übernommen | Freigabe prüfen, gelbe Leiste in OMV übernehmen |
| Immich startet nach Neustart nicht, Meldung zu fehlenden `.immich`-Dateien | NFS war beim Start noch nicht eingehängt | `sudo mount -a && docker compose up -d`, VM nach dem Pi starten |
| Große Videos brechen über `immich.lab.test` ab | NPM begrenzt die Upload-Größe | Advanced-Zeilen aus Schritt 7 |
| App findet den Server nicht | `.lab.test` am Handy nicht auflösbar oder `http://`/Port fehlt | `http://192.168.2.23:2283`, unterwegs Tailscale an |
| Sicherung am iPhone sehr langsam | Originale liegen in iCloud, App im Hintergrund | App offen lassen, über Nacht laufen lassen |

Weitere Fälle: [Fehlerbehebung](../fehlerbehebung.md#immich-kapitel-21)

Wie es weitergeht: [Roadmap](../roadmap.md)
