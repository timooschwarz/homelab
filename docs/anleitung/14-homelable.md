# Kapitel 14 · Homelable: Netzwerkkarte mit Live-Status (Proxmox in Hyper-V)

[← Kapitel 13](13-wazuh.md) · [Übersicht](../../README.md#inhaltsverzeichnis) · [Kapitel 15 →](15-proxmox-host.md)

[![Proxmox](https://img.shields.io/badge/-Proxmox-E57000?style=flat-square)](../../README.md#thema-proxmox) [![Netzwerk](https://img.shields.io/badge/-Netzwerk-1D9E75?style=flat-square)](../../README.md#thema-netz) [![Linux & Docker](https://img.shields.io/badge/-Linux%20%26%20Docker-E95420?style=flat-square)](../../README.md#thema-linux) [![Hyper-V](https://img.shields.io/badge/-Hyper--V-5F5E5A?style=flat-square)](../../README.md#thema-hyperv) [![Gruppenrichtlinien](https://img.shields.io/badge/-Gruppenrichtlinien-7F77DD?style=flat-square)](../../README.md#thema-gpo)

> **Ziel:** Eine grafische Karte des Labs, auf der jede VM mit Live-Status (grün/rot) zu sehen ist. Dafür läuft Proxmox VE als VM in Hyper-V und darin [Homelable](https://homelable.net/) als LXC-Container.
> **Dauer:** ca. 1,5 Stunden · **Wo:** Host, PVE01 (Weboberfläche), DC01
> **Version:** Proxmox VE 9.2, Homelable 3.6

[Homelable](https://github.com/Pouzor/homelable) ist ein kostenloses Open-Source-Tool (MIT): Es scannt das Netz mit nmap, legt die gefundenen Geräte auf eine Zeichenfläche, prüft sie jede Minute per Ping, HTTP oder TCP und zeigt den Status farbig an. Es ersetzt **nicht** NetBox: NetBox bleibt die Quelle der Wahrheit für IP-Adressen, Homelable ist die schnelle Übersicht „läuft alles?“.

**Warum Proxmox in Hyper-V?** Homelable gibt es fertig als Proxmox-LXC über die [Community-Scripts](https://community-scripts.org/scripts/homelable). Läuft der Container später auf einem echten Proxmox-Host, lässt er sich per Backup und Wiederherstellen umziehen. Docker Desktop unter Windows ist keine gute Alternative: Dort liefert der Scan keine MAC-Adressen, Geräte tauchen nach einem DHCP-Wechsel doppelt auf.

| Was | Wert |
|---|---|
| PVE01 | Proxmox VE als Hyper-V-VM, `10.0.0.90`, Weboberfläche `https://10.0.0.90:8006` |
| HOMELABLE | LXC-Container 100 auf PVE01, `10.0.0.91`, Weboberfläche `http://10.0.0.91:3000` |
| Netz | Switch `LAB`, Gateway `10.0.0.1`, DNS `10.0.0.10`. **Kein externer Switch nötig** |

> [!NOTE]
> Weil PVE01 im selben Netz wie die anderen VMs hängt, findet der Scan alle Lab-VMs **mit MAC-Adresse**. Geräte im Heimnetz sind über das NAT nur für Status-Checks erreichbar, nicht für die automatische Erkennung.

## Schritt 1 · VM PVE01 anlegen (Host)

Hyper-V-Manager → **Neu → Virtueller Computer**:

| Einstellung | Wert |
|---|---|
| Name | `PVE01` |
| Generation | **1**, nicht 2 (siehe [Häufige Fehler](#häufige-fehler)) |
| Arbeitsspeicher | **4096 MB, dynamischer Arbeitsspeicher aus** |
| Netzwerk | `LAB` |
| Festplatte | 64 GB |
| Installation | Proxmox-VE-ISO von proxmox.com → Downloads |

Vor dem ersten Start **Einstellungen**:

1. **Prozessor** → 2 virtuelle Prozessoren
2. **Netzwerkkarte** → aufklappen → **Erweiterte Features** → Haken bei **MAC-Adressen-Spoofing aktivieren**
3. **Prüfpunkte** → automatische Prüfpunkte aus
4. **Automatische Startaktion** → mit Verzögerung **nach DC01**

> [!IMPORTANT]
> Ohne **MAC-Spoofing** kommt der Container später nicht ins Netz. Er hat eine eigene MAC-Adresse, und Hyper-V verwirft deren Pakete sonst.

## Schritt 2 · Proxmox installieren (PVE01)

VM starten → **Verbinden** → im Boot-Menü **Install Proxmox VE (Terminal UI)**. Der grafische Installer bricht unter Hyper-V ab.

Die Warnung *No support for hardware-accelerated KVM virtualization* mit **OK** bestätigen. KVM braucht man nur für VMs *in* Proxmox, LXC-Container laufen ohne.

| Installer-Seite | Eintrag |
|---|---|
| Land / Zeitzone / Tastatur | Germany · Europe/Berlin · German |
| Root-Passwort, E-Mail | Passwort in den Kennwortmanager. Bei Problemen mit `@` siehe [Häufige Fehler](#häufige-fehler) |
| Hostname (FQDN) | `pve01.lab.test` |
| IP (CIDR) | `10.0.0.90/24` (nicht die per DHCP vorgeschlagene, die liegt im DHCP-Bereich) |
| Gateway / DNS | `10.0.0.1` / `10.0.0.10` |

Auf der Zusammenfassung den Haken bei **Automatically reboot** entfernen → **Install**. Wenn *successful* erscheint: im Hyper-V-Fenster **Medien → DVD-Laufwerk → auswerfen**, dann **Reboot**. Generation-1-VMs starten sonst wieder vom DVD-Laufwerk.

Danach vom Host im Browser `https://10.0.0.90:8006` → Zertifikatswarnung bestätigen → Benutzer `root`, Realm **Linux PAM**. Den Hinweis *Keine gültige Subskription* mit OK wegklicken.

> [!TIP]
> Der rote Task *Paket-Datenbank aktualisieren* direkt nach der Installation ist normal: Proxmox versucht das Enterprise-Repo, das ohne Abo nicht geht. Das Skript **PVE Post Install** von community-scripts.org stellt auf das kostenlose Repo um.

## Schritt 3 · Homelable-Container anlegen (PVE01)

Links **pve01** → **>_ Shell** (Fenster vorher maximieren, die Dialoge passen sich nur beim Start an):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/homelable.sh)"
```

**Advanced Install** wählen. Wichtig sind nur diese Werte, den Rest mit dem Standard bestätigen:

| Frage | Eintrag |
|---|---|
| Container Type | Unprivileged |
| Hostname | `homelable` |
| Bridge | `vmbr0` |
| IPv4 | static `10.0.0.91/24`, Gateway `10.0.0.1` |
| IPv6 | none |
| DNS Search Domain / Server | `lab.test` / `10.0.0.10` |
| TUN/TAP, GPU, APT-Cacher, Proxy | No |
| Nesting | Yes (App-Standard) |
| Save as defaults | No (sonst bekommt ein zweiter Container dieselbe IP) |

Nach ein paar Minuten steht am Ende `http://10.0.0.91:3000`. Die Meldung *IPv6 Internet Not Connected* ist egal.

> [!WARNING]
> Homelable startet mit `admin` / `admin`. **Sofort ändern**, in der pve01-Shell:
> ```bash
> pct enter 100
> /root/change_password.sh
> exit
> ```

## Schritt 4 · Ping für die Windows-Server freigeben (DC01)

Der Scan erkennt Geräte vor allem per Ping. Windows-Server beantworten Ping nur, wenn die Firewall es erlaubt. Im Lab hängt die Ping-GPO bisher nur an `Lab/Computer`, deshalb fehlen DC01, CM01 und FS01 im Scan.

**Group Policy Management** → Rechtsklick auf **Lab → Server** → **Link an Existing GPO…** → `GPO-Computer-Ping` → OK. Dasselbe für **Domain Controllers**. Danach auf DC01, CM01 und FS01 `gpupdate /force`.

**Hyper-V-Host:** Der Host (`10.0.0.1`) ist nicht in der Domäne. Auf ihm `wf.msc` → **Eingehende Regeln** → **Datei- und Druckerfreigabe (restriktiv) (Echoanforderung – ICMPv4 eingehend)** doppelklicken:

- **Allgemein** → Haken bei **Aktiviert**
- **Bereich** → Remote-IP-Adresse → **Diese IP-Adressen** → `10.0.0.0/24`

So antwortet der Host nur Geräten im Lab auf Ping.

**Prüfen** in der pve01-Shell:

```bash
ping -c 2 10.0.0.1
pct exec 100 -- ping -c 2 10.0.0.10
```

## Schritt 5 · Scannen und Karte bauen (Browser)

1. `http://10.0.0.91:3000` → Der Demo-Canvas zeigt Beispielgeräte. Über das Canvas-Menü oben links einen neuen, leeren Canvas **LAB** (Diagram, Blank canvas) anlegen.
2. **Scan Network** → Bereich `192.168.1.0/24` durch **`10.0.0.0/24`** ersetzen → **Scan Now**. Vorher alle VMs starten, die auf die Karte sollen. Ausgeschaltete VMs findet der Scan nicht.
3. **Device Inventory** öffnen. Alles mit `192.168.1.x` sind Demo-Geräte: im **Select mode** auswählen → **Hide**. Die echten Geräte (`10.0.0.x`) auswählen → **Put in current Canvas**.
4. Geräte anklicken und umbenennen, Typ korrigieren. Windows-Server erkennt Homelable wegen SMB oft als *NAS*, das auf **Server** stellen.
5. Verbindungen ziehen, vom unteren Punkt zum oberen: Host → jede VM, **PVE01 → homelable**. Im Dialog *Line Style* **Dashed** (virtuell).
6. **Auto Layout** → **Save**.

Nach einer Minute laufen die Status-Checks, unten links steht dann z. B. *Online 10 · Offline 0*.

> [!TIP]
> Mit **Deep Scan** und **Enable HTTP probe** erkennt Homelable auch die Web-Dienste. Zusätzliche Ports im Lab: `81, 3000-3001, 8000, 8006, 8888, 10123, 19999`. *Verify TLS certificates* aus lassen, Proxmox und Warpgate haben selbst signierte Zertifikate.

## Schritt 6 · Sichern

Container **100 (homelable)** → **Backup → Jetzt sichern** → Storage `local`, Modus **Stop**. Die Datei landet unter `/var/lib/vz/dump/`. Auf einem neuen Proxmox-Host lässt sie sich unter **local → Backups → Wiederherstellen** einspielen, mit derselben IP und allen Daten.

## Prüfen

- [ ] `https://10.0.0.90:8006` und `http://10.0.0.91:3000` erreichbar
- [ ] Anmeldung bei Homelable nur noch mit dem neuen Passwort
- [ ] Alle laufenden VMs grün, ausgeschaltete rot
- [ ] DNS-Einträge `pve01` und `homelable` (A + PTR) auf DC01, Linux trägt sich nicht selbst ein

## Häufige Fehler

| Problem | Ursache | Lösung |
|---|---|---|
| Installer hängt bei *testing again in … seconds* | Generation-2-VM: der Installer findet das ISO am SCSI-DVD-Laufwerk nicht | VM als **Generation 1** neu anlegen |
| *Installation aborted – unable to continue* | Der grafische Installer kommt mit der Hyper-V-Grafik nicht klar | Im Boot-Menü **Terminal UI** wählen |
| `@` lässt sich im Installer nicht eingeben | Hyper-V-Konsole reicht AltGr nicht durch | Im Installer kurz die Tastatur **U.S. English** wählen, `@` = Shift + 2. Passwort dann nur aus Buchstaben ohne y/z und Ziffern |
| Container hat kein Netz | MAC-Spoofing an der Netzwerkkarte von PVE01 fehlt | VM aus → Netzwerkkarte → Erweiterte Features → MAC-Spoofing |
| Scan findet nur die Linux-VMs | Windows-Server antworten nicht auf Ping | Ping-GPO auch an Lab/Server und Domain Controllers, siehe Schritt 4 |
| Scan History meldet *0 found* | Die Zahl zählt nur **neue** Geräte | Im **Device Inventory** nachsehen. Ob der Scan wirklich lief: `pct exec 100 -- journalctl -u homelable -n 60 --no-pager` |
| Host bleibt rot | Windows-Firewall blockiert Ping | Regel aus Schritt 4 auf dem Host. Check auf **ping** ohne Port stellen |
| Ein Gerät heißt nach dem Scan wie ein Demo-Gerät | Demo-Eintrag hatte zufällig dieselbe IP (`10.0.0.1`) | Umbenennen, auch unter *Identity → Name* über **Edit** |

Wie es danach weitergeht: [Roadmap](../roadmap.md)

Weiter mit Proxmox auf echter Hardware: [Kapitel 15](15-proxmox-host.md)
