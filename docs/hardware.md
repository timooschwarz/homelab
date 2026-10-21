# Hardware: Mini-PC im 10-Zoll-Rack

[Übersicht](../README.md#inhaltsverzeichnis) · [Roadmap](roadmap.md) · [Entscheidungen](entscheidungen.md)

[![Netzwerk](https://img.shields.io/badge/-Netzwerk-1D9E75?style=flat-square)](../README.md#thema-netz) [![Hyper-V](https://img.shields.io/badge/-Hyper--V-5F5E5A?style=flat-square)](../README.md#thema-hyperv)

> **Ziel:** Das Lab läuft dauerhaft auf einem eigenen, sparsamen Mini-PC statt auf dem großen PC. Mini-PC, Switch und NAS sitzen ordentlich verkabelt in einem kleinen 10-Zoll-Rack.
> **Stand:** 21.10.2026 · Rack aufgebaut, Switch eingerichtet, Patchpanel (HE 4) und SBC Shelf (HE 8) montiert. Mini-PC aufgerüstet, Proxmox VE installiert. Das NAS folgt.

Die Anleitung (Kapitel 0–13) funktioniert weiterhin auf einem einzigen PC mit Hyper-V. Dieses Kapitel beschreibt, wie ich das Lab danach auf eigene Hardware umziehe. Es ist optional. Auf dem Mini-PC läuft **Proxmox VE** statt Hyper-V: Die Windows-Server laufen dort als KVM-VMs, Linux-Dienste können als schlanke LXC-Container laufen.

## Komponenten

| Teil | Aufgabe | Höheneinheit |
|---|---|---|
| DeskPi RackMate T1 Plus | 10-Zoll-Rack, 8 HE, 260 mm tief | – |
| 3× Blindblende 1 HE | Platzhalter für ein späteres 7-Zoll-Display | HE 1–3 |
| Keystone-Patchpanel, 12 Ports | Geräte hinten anstecken, vorne kurze Kabel zum Switch | HE 4 |
| TP-Link TL-SG108E (V2) | Managed Switch mit 802.1Q-VLANs, in einer 3D-gedruckten 10-Zoll-Halterung | HE 5 |
| HP EliteDesk 805 G6 Mini auf Fachboden | Proxmox-Host `pve01`: Ryzen 5 PRO 4650GE (6 Kerne, 12 Threads), 32 GB DDR4, 2× NVMe + 1× SATA-SSD | HE 6 |
| Belüftungsblende 1 HE | Verdeckt das NAS von vorne, lässt Luft durch | HE 7 |
| Raspberry Pi 5 + Radxa Penta SATA HAT auf SBC Shelf | NAS mit OpenMediaVault, 4× 1 TB SSD, Backup-Ziel | HE 8 |

![Rack-Belegung von vorne](diagramme/rack-belegung-2026-10-19.png)

Im Dauerbetrieb braucht alles zusammen etwa 30–40 W.

## Verkabelung

![Verkabelung im Rack](diagramme/verkabelung-2026-10-19.png)

**Prinzip:** Jedes Gerät wird **hinten** ins Patchpanel gesteckt. **Vorne** verbindet ein kurzes Kabel (15–25 cm) jeden Patchpanel-Port mit dem Switch-Port **derselben Nummer**. Vorne sieht man dann nur eine ordentliche Reihe, und zum Umstecken muss man hinten nichts anfassen.

| Port | Gerät | Hinweis |
|---|---|---|
| 1 | Mini-PC (Proxmox-Host) | Später Trunk: Heimnetz untagged, Lab-VLANs tagged |
| 2 | NAS | Bleibt im Heimnetz |
| 3–6 | frei | Für VLAN-Übungen |
| 7 | Arbeits-PC | |
| 8 | Uplink zur LAN-Dose | Immer untagged in VLAN 1, sonst ist die Verwaltung des Switches weg |

Patchpanel und Switch müssen nicht gleich viele Ports haben. Die übrigen Keystone-Plätze bekommen Blindstopfen oder später HDMI/USB-Module.

## Switch einrichten (TL-SG108E)

> **Dauer:** ca. 15 Minuten · **Wo:** am Arbeits-PC, gearbeitet wird mit der Weboberfläche

Ab Werk hat der Switch die feste IP `192.168.0.1`. Liegt dein Heimnetz in einem anderen Bereich (z. B. `192.168.2.x`), erreichst du die Weboberfläche zunächst nicht. Es gibt zwei Wege:

**Weg A · Easy Smart Configuration Utility (ohne Internet-Unterbrechung)**

1. Utility von der TP-Link-Seite für deine Hardware-Version herunterladen (Version steht auf dem Aufkleber, z. B. „Ver: 2.0").
2. Switch zwischen LAN-Dose und PC hängen. Das Utility findet ihn per Broadcast, auch im falschen IP-Bereich.
3. **IP Setting:** DHCP aus, feste IP aus deinem Heimnetz außerhalb des DHCP-Bereichs (z. B. `192.168.2.10`), Maske `255.255.255.0`, Gateway = dein Router. Mit dem aktuellen Login bestätigen.

**Weg B · Manuell**

1. PC kurz auf die feste IP `192.168.0.2` / `255.255.255.0` stellen (*Einstellungen → Netzwerk und Internet → Ethernet → IP-Zuweisung → Bearbeiten*).
2. Im Browser `http://192.168.0.1` öffnen und unter **System → IP Setting** die neue IP eintragen.
3. PC zurück auf **Automatisch (DHCP)** stellen.

**Danach in der Weboberfläche:**

1. **System → System Info:** Firmware prüfen. Für V2 ist `20160526` die neueste.
2. **System → User Account:** Kennwort ändern (empfohlen).
3. **Monitoring → Loop Prevention:** einschalten.
4. Links **Save Config** klicken. Ohne das sind alle Änderungen nach einem Stromausfall weg.
5. **System → Backup and Restore:** Konfiguration sichern. Die Datei enthält die Zugangsdaten im Klartext, also nicht in ein öffentliches Repo legen.

**Prüfen:** Unter **Switching → Port Setting** muss bei jedem belegten Port in der Spalte *Speed Actual* `1000MF` stehen.

## Mini-PC aufrüsten (HP EliteDesk 805 G6 Mini)

> **Dauer:** ca. 20 Minuten · **Werkzeug:** Torx T15 (zur Not ein kleiner Schlitzschraubendreher)

1. **Gehäuse öffnen:** Hinten die Schraube neben dem Schloss-Symbol herausdrehen und den Deckel nach vorne schieben, dann abheben.
   > [!WARNING]
   > Das runde Teil oben rechts an der Rückseite ist **keine Schraube**, sondern eine Plastikabdeckung für einen optionalen externen WLAN-Antennenanschluss. Nicht mit dem Schraubendreher hineindrücken, sie bricht leicht ab.
2. **RAM:** Er sitzt unter dem Lüfter. Den Lüfter an seinem Scharnier hochklappen, darunter die Abdeckung anheben. Zwei SO-DIMM-Slots (DDR4), maximal 64 GB. Riegel schräg einsetzen und herunterdrücken, bis die Klammern einrasten.
3. **SSDs:** Der 2,5-Zoll-Käfig ist mit zwei Schrauben befestigt. Darunter liegen ein kleiner zweiter Lüfter und die beiden M.2-Slots (2280) mit Wärmeleitabdeckungen. Für M.2-2230-SSDs braucht man einen Adapter auf 2280.
4. **Prüfen:** Einschalten, **F10** drücken, *Main → Show Advanced System Information*. RAM-Größe und alle Laufwerke müssen dort stehen.

So ist der Mini-PC bestückt:

| Laufwerk | Anschluss | Aufgabe |
|---|---|---|
| Samsung 970 EVO Plus 500 GB | M.2 NVMe | Proxmox selbst und ISOs |
| Samsung 960 EVO 1 TB | M.2 NVMe | VMs und Container |
| Samsung 850 EVO 1 TB | SATA (2,5 Zoll) | Backups und Exporte aus Hyper-V |

## Proxmox VE installieren

> **Dauer:** ca. 30 Minuten · **Wo:** am Arbeits-PC (Stick) und am Mini-PC

**Warum Proxmox statt Windows mit Hyper-V:** Ein Windows-Host verbraucht selbst RAM und CPU, die den VMs fehlen. Proxmox ist ein schlanker Hypervisor, Windows Server läuft darunter genauso wie unter Hyper-V. Dazu kommen LXC-Container und die [Community-Scripts](https://community-scripts.org/).

**Bootstick erstellen**

1. Auf proxmox.com unter *Downloads* die ISO **Proxmox VE** laden (nicht Backup Server).
2. [Rufus](https://rufus.ie) starten, USB-Stick (mind. 8 GB, wird gelöscht) wählen, unter *Startart* die ISO auswählen, **Start**.
3. Bei der Frage nach dem Schreibmodus **Im DD-Abbild-Modus schreiben** wählen. Im ISO-Modus bootet der Stick oft nicht.
   > [!NOTE]
   > Danach meldet Windows eventuell, das Laufwerk müsse formatiert werden. **Abbrechen**, Windows kann das Linux-Dateisystem nur nicht lesen.

**Installation am Mini-PC**

1. **F10** → *Advanced → System Options*: Virtualisierung (AMD-V) muss aktiv sein.
2. Stick einstecken, beim Start **F9** (Boot-Menü), USB-Stick wählen, **Install Proxmox VE (Graphical)**.
3. **Target Harddisk:** die Systemplatte (hier die 970 EVO Plus), nach Name und Größe auswählen, nicht nach Reihenfolge. Dateisystem **ext4** (ZFS lohnt sich bei einer einzelnen Platte nicht). Die anderen Laufwerke bleiben unangetastet und werden später in der Weboberfläche eingebunden.
4. **Location:** Germany, Europe/Berlin, Tastatur German.
5. **Management Network:** feste IP im Heimnetz außerhalb des DHCP-Bereichs.

| Feld | Wert |
|---|---|
| Hostname (FQDN) | `pve01.lab.test` |
| IP-Adresse | `192.168.2.20/24` |
| Gateway | `192.168.2.1` |
| DNS | `192.168.2.1` |

6. **Install.** Internet braucht die Installation nicht. Nach der Erfolgsmeldung **erst den Stick abziehen**, dann *Reboot*.

**Prüfen:** Am Arbeits-PC `https://192.168.2.20:8006` öffnen, Zertifikatswarnung bestätigen, Anmeldung als `root` mit Realm *Linux PAM*.

Danach braucht der Mini-PC weder Monitor noch Tastatur: Verwaltet wird nur noch über die Weboberfläche.

## Montage-Tipps

- **3 Löcher an der Schiene = 1 HE**, von oben gezählt. Ein 1-HE-Gerät wird im 1. und 3. Loch seiner HE verschraubt.
- **Von unten nach oben** einbauen, dann stößt man beim Schrauben nirgends an.
- **Schrauben erst handfest** anziehen und am Ende festziehen. So lässt sich noch um ein Loch korrigieren.
- Das NAS ragt mit HAT, Kühler und SSDs über 1 HE hinaus. Deshalb liegt es ganz unten und die HE darüber bleibt frei bzw. bekommt eine Belüftungsblende.
- Das DeskPi SBC Shelf hat zwei Pi-Plätze mit kleinen Adapterplatinen (KL-P24), die USB-C und HDMI nach vorne führen. Fürs NAS werden sie nicht gebraucht: Der Pi bekommt Strom über das 12-V-Netzteil am Penta HAT. Dann **nicht zusätzlich** per USB-C einspeisen.
- Den Pi am besten auf dem Tisch aufs Shelf schrauben und das Shelf danach einbauen.

## Häufige Fehler

| Problem | Ursache | Lösung |
|---|---|---|
| Nur ca. 90 Mbit/s statt Gigabit | Port handelt nur 100 Mbit aus (*Speed Actual* `100MF`), fast immer wegen eines alten oder defekten Kabels | Kabel gegen Cat5e/Cat6 tauschen |
| Weboberfläche nicht erreichbar | PC und Switch in verschiedenen IP-Bereichen | Easy Smart Utility oder PC kurz auf `192.168.0.2` |
| Einstellungen nach Neustart weg | Nicht gespeichert | Nach jeder Änderung **Save Config** |
| Mini-PC zeigt nach Neustart kein Bild, Tastatur bleibt dunkel | Start hängt vor dem HP-Logo, vermutlich wegen eines angesteckten USB-Geräts | Nur Strom, Netzwerk und Monitor anstecken, Rest nach dem Start ([Details](fehlerbehebung.md#mini-pc-startet-nach-neustart-nicht-mehr)) |
| Nach VLAN-Änderung kein Zugriff mehr auf den Switch | Uplink- oder PC-Port aus VLAN 1 genommen | Reset-Knopf ca. 10 s halten, neu einrichten, Uplink in VLAN 1 lassen |
