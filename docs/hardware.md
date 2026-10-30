# Hardware: Mini-PC im 10-Zoll-Rack

[Übersicht](../README.md#inhaltsverzeichnis) · [Roadmap](roadmap.md) · [Entscheidungen](entscheidungen.md)

[![Netzwerk](https://img.shields.io/badge/-Netzwerk-1D9E75?style=flat-square)](../README.md#thema-netz) [![Hyper-V](https://img.shields.io/badge/-Hyper--V-5F5E5A?style=flat-square)](../README.md#thema-hyperv)

> **Ziel:** Das Lab läuft dauerhaft auf einem eigenen, sparsamen Mini-PC statt auf dem großen PC. Mini-PC, Switch und NAS sitzen ordentlich verkabelt in einem kleinen 10-Zoll-Rack.
> **Stand:** 30.10.2026 · Alles im Rack. Von oben: **HE 1–2 Rack-Display** (7,84 Zoll, Dashboard vom Pi, [Kapitel 20](anleitung/20-rack-display.md)), **HE 3 Patchpanel**, **HE 4 Mini-PC** (pve01, in einer 3D-gedruckten Frontblende), **HE 5 Switch**, HE 6 Blindblende, HE 7 gelochte Blende, **HE 8 Pi-NAS auf dem Fachboden**. Auf dem Mini-PC läuft Proxmox VE ([Kapitel 15](anleitung/15-proxmox-host.md)), das NAS ist in [Kapitel 16](anleitung/16-pi-nas.md) beschrieben.

Die Anleitung (Kapitel 0–14) funktioniert weiterhin auf einem einzigen PC mit Hyper-V. Diese Seite beschreibt Rack, Verkabelung und Switch für den Umzug auf eigene Hardware. Es ist optional. Auf dem Mini-PC läuft **Proxmox VE** statt Hyper-V: Die Windows-Server laufen dort als KVM-VMs, Linux-Dienste können als schlanke LXC-Container laufen.

## Komponenten

| Teil | Aufgabe | Position (von oben) |
|---|---|---|
| DeskPi RackMate T1 Plus | 10-Zoll-Rack, 8 HE, 260 mm tief | – |
| Rack-Display 7,84 Zoll (GeeekPi) | Dashboard mit Strom, Servern und Diensten, hängt per HDMI und USB am Pi-NAS ([Kapitel 20](anleitung/20-rack-display.md)) | 1–2 |
| Keystone-Patchpanel, 12 Ports | Geräte hinten anstecken, vorne kurze Kabel zum Switch | 3 |
| HP EliteDesk 805 G6 Mini in 3D-gedruckter Frontblende | Proxmox-Host `pve01`: Ryzen 5 PRO 4650GE (6 Kerne, 12 Threads), 32 GB DDR4, 2× NVMe + 1× SATA-SSD. Links in der Blende ist Platz für einen JetKVM | 4 |
| TP-Link TL-SG108E (V2) | Managed Switch mit 802.1Q-VLANs, in einer 3D-gedruckten 10-Zoll-Halterung | 5 |
| Blindblende + gelochte Blende | Verdecken das NAS, die gelochte Blende lässt Luft durch | 6–7 |
| Raspberry Pi 5 + Radxa Penta SATA HAT auf dem Fachboden | NAS mit OpenMediaVault, 4× 1 TB SSD, Backup-Ziel | 8 |

> [!NOTE]
> Die kurzen Kabel laufen vom Patchpanel vor dem Mini-PC nach unten zum Switch. Die Patchpanel-Nummern sind um 2 versetzt: Patchpanel 3–10 gehen auf Switch 1–8.

![Rack-Belegung von vorne](diagramme/rack-belegung-2026-10-21.png)

*Planungsstand 21.10. Inzwischen sieht die Belegung anders aus, siehe Stand und Tabelle oben.*

Im Dauerbetrieb braucht alles zusammen etwa 30–40 W.

## Verkabelung

![Verkabelung im Rack](diagramme/verkabelung-2026-10-21.png)

**Prinzip:** Jedes Gerät wird **hinten** ins Patchpanel gesteckt. **Vorne** verbindet ein kurzes Kabel jeden Patchpanel-Port mit dem passenden Switch-Port. Vorne sieht man dann nur eine ordentliche Reihe, und zum Umstecken muss man hinten nichts anfassen.

| Switch-Port | Patchpanel | Gerät | Hinweis |
|---|---|---|---|
| 1–4, 6 | 3–6, 8 | NAS und weitere Geräte bzw. frei | Heimnetz (VLAN 1 untagged), freie Ports für VLAN-Übungen |
| 5 | 7 | Mini-PC (Proxmox-Host) | Trunk: VLAN 1 untagged, VLAN 10 (Lab) tagged ([Kapitel 19](anleitung/19-vlan-testclient.md)) |
| 7 | 9 | Arbeits-PC | Trunk: VLAN 1 untagged, VLAN 10 (Lab) tagged, für Testclients in Hyper-V |
| 8 | 10 | Uplink zur LAN-Dose | Immer untagged in VLAN 1, sonst ist die Verwaltung des Switches weg |

> [!IMPORTANT]
> Nach dem Rack-Umbau am 25.10. steckt der Mini-PC in **Port 5**, nicht mehr in Port 1 wie ursprünglich geplant. Vor jeder VLAN-Änderung prüfen, welches Gerät wirklich an welchem Port hängt: **Monitoring → Port Statistics → Clear**, auf dem Gerät Verkehr erzeugen (z. B. `ping -f -c 5000 192.168.2.1` auf pve01), **Refresh**.

**Keystones einsetzen:** Beim DeskPi-Panel werden die Keystone-Kupplungen **von hinten** eingesetzt, mit der **Federlasche nach oben**. Von vorne passen sie nicht durch, der vordere Rand dient als Anschlag. Erst unten einhaken, dann oben eindrücken, bis es klickt.

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

## Proxmox auf dem Mini-PC

Aufrüsten, Proxmox installieren, Speicher, Monitoring mit Beszel und Fernzugriff mit Tailscale stehen Schritt für Schritt in **[Kapitel 15 · Proxmox auf eigener Hardware](anleitung/15-proxmox-host.md)**.

## Montage-Tipps

- **3 Löcher an der Schiene = 1 HE**, von oben gezählt. Ein 1-HE-Gerät wird im 1. und 3. Loch seiner HE verschraubt.
- **Von unten nach oben** einbauen, dann stößt man beim Schrauben nirgends an.
- **Schrauben erst handfest** anziehen und am Ende festziehen. So lässt sich noch um ein Loch korrigieren.
- Das NAS ragt mit HAT, Kühler und SSDs über 1 HE hinaus. Deshalb liegt es ganz unten und die HE darüber bleibt frei bzw. bekommt eine Belüftungsblende.
- Das DeskPi SBC Shelf hat zwei Pi-Plätze mit kleinen Adapterplatinen (KL-P24), die USB-C und HDMI nach vorne führen. Fürs NAS werden sie nicht gebraucht: Der Pi bekommt Strom über das 12-V-Netzteil am Penta HAT. Dann **nicht zusätzlich** per USB-C einspeisen.
- Den Pi am besten auf dem Tisch aufs Shelf schrauben und das Shelf danach einbauen.
- **Frontblende für den Mini-PC:** Seit 30.10. sitzt der HP in einer 3D-gedruckten 10-Zoll-Blende statt auf dem Fachboden. Dafür wird die Bodenplatte des HP gegen die Platte der Blende getauscht. Vorher pve01 sauber herunterfahren (Proxmox: Knoten auswählen → **Bulk Actions → Bulk Shutdown**, dann **Shutdown**). Bei mir saßen die Löcher links nicht genau auf den Rack-Löchern und mussten nachgefeilt werden. Druckmodelle vorher an die Schiene halten. Den frei gewordenen Fachboden nutzt jetzt das NAS in HE 8.
- **Nachgemessen:** Mit HAT, Kühler und stehenden SSDs passt das NAS nicht in 1 HE. Bei mir steht es auf dem Fachboden in HE 8, davor sitzen in HE 6–7 eine Blindblende und eine gelochte Blende.

## Häufige Fehler

| Problem | Ursache | Lösung |
|---|---|---|
| Nur ca. 90 Mbit/s statt Gigabit | Port handelt nur 100 Mbit aus (*Speed Actual* `100MF`), fast immer wegen eines alten oder defekten Kabels | Kabel gegen Cat5e/Cat6 tauschen |
| Weboberfläche nicht erreichbar | PC und Switch in verschiedenen IP-Bereichen | Easy Smart Utility oder PC kurz auf `192.168.0.2` |
| Einstellungen nach Neustart weg | Nicht gespeichert | Nach jeder Änderung **Save Config** |
| Mini-PC zeigt nach Neustart kein Bild, Tastatur bleibt dunkel | Start hängt vor dem HP-Logo, vermutlich wegen eines angesteckten USB-Geräts | Nur Strom, Netzwerk und Monitor anstecken, Rest nach dem Start ([Details](fehlerbehebung.md#mini-pc-startet-nach-neustart-nicht-mehr)) |
| Nach VLAN-Änderung kein Zugriff mehr auf den Switch | Uplink- oder PC-Port aus VLAN 1 genommen | Reset-Knopf ca. 10 s halten, neu einrichten, Uplink in VLAN 1 lassen |
