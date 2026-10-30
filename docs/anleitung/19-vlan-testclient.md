# Kapitel 19 · Lab-Netz als VLAN 10: Testclient auf dem Arbeits-PC

[← Kapitel 18](18-betrieb.md) · [Übersicht](../../README.md#inhaltsverzeichnis) · [Hardware und Rack](../hardware.md) · [Fehlerbehebung](../fehlerbehebung.md#vlan-kapitel-19)

[![Netzwerk](https://img.shields.io/badge/-Netzwerk-1D9E75?style=flat-square)](../../README.md#thema-netz) [![Proxmox](https://img.shields.io/badge/-Proxmox-E57000?style=flat-square)](../../README.md#thema-proxmox)

> **Ziel:** Das Lab-Netz `10.0.0.0/24` lebt bisher nur innerhalb von pve01 (Bridge `vmbr1`). Jetzt läuft es als **VLAN 10** über den Switch bis zum Arbeits-PC. Ein Windows-11-Testclient in Hyper-V hängt damit direkt im Lab: IP per DHCP von DC01, DNS, GPOs und MECM wie bei den Servern.
> **Dauer:** ca. 1,5 Stunden plus Windows-Installation · **Wo:** Switch-Weboberfläche, Proxmox (Browser), Arbeits-PC (Hyper-V-Manager)
> **Voraussetzung:** [Kapitel 15](15-proxmox-host.md) und [17](17-umzug-hyperv-proxmox.md) (Lab-Netz `vmbr1` mit NAT auf pve01), Switch eingerichtet ([Hardware](../hardware.md#switch-einrichten-tl-sg108e))

**Warum?** Testclients sollen auf dem großen PC laufen, der Mini-PC trägt nur die Dienste. Ohne VLAN hätte der Client entweder kein Lab-Netz oder man bräuchte ein zweites Kabel. Mit VLAN teilen sich Heimnetz und Lab-Netz dasselbe Kabel: Heimnetz-Pakete laufen **untagged**, Lab-Pakete bekommen eine Markierung (Tag) mit der Nummer 10.

```text
DC01, FS01, TOOLS01 … ── vmbr1 (10.0.0.1) ── nic0.10 ─┐
                                                       │ Switch-Port 5: VLAN 1 untagged + VLAN 10 tagged
                                                 TL-SG108E
                                                       │ Switch-Port 7: VLAN 1 untagged + VLAN 10 tagged
Arbeits-PC (Heimnetz, untagged) ── Hyper-V-Switch „Extern“ ── CLIENT02 (VLAN-ID 10)
```

| Was | Wert |
|---|---|
| VLAN | ID `10`, Name `LAB` |
| Switch-Port Mini-PC | **5** (Trunk: VLAN 1 untagged, VLAN 10 tagged) |
| Switch-Port Arbeits-PC | **7** (Trunk: VLAN 1 untagged, VLAN 10 tagged) |
| pve01 | VLAN-Interface `nic0.10` als Bridge-Port von `vmbr1` |
| Arbeits-PC | Externer Hyper-V-Switch `Extern`, der PC selbst bleibt untagged im Heimnetz |
| Testclient | CLIENT02, Windows 11 Pro, VLAN-ID 10, IP per DHCP von DC01 |

> [!IMPORTANT]
> **Erst prüfen, welches Gerät an welchem Switch-Port hängt.** Bei mir stand im Plan „Port 1 = Mini-PC“, nach einem Rack-Umbau steckte er aber in Port 5. Das VLAN war damit auf dem falschen Port und es hat einen ganzen Abend Fehlersuche gekostet. Wie man das in einer Minute prüft, steht in Teil 0.

## Teil 0 · Vorab prüfen (ändert nichts)

1. **Netzwerkkarte von pve01:** Proxmox → **pve01 → System → Network**. Bei **vmbr0** steht unter *Ports/Slaves* die echte Karte. Proxmox 9 nennt sie `nic0` (der alte Name wie `enp4s0f1` steht unter *Alternative Names*). Das VLAN-Interface heißt dann `nic0.10`.
2. **Welcher Switch-Port ist pve01?** Switch-Weboberfläche → **Monitoring → Port Statistics → Clear**. Dann in **pve01 → Shell**:
   ```bash
   ping -f -c 5000 192.168.2.1
   ```
   Danach **Refresh**: Der Port, dessen Zähler um rund 5000 springt, ist pve01. Für den Arbeits-PC genauso, oder einfach ein Video laufen lassen und schauen, welcher Port am meisten zählt. Alternativ am Rack nachsehen, welches Kabel wohin geht.
3. **Netzwerkkarte des Arbeits-PCs:** Geräte-Manager → **Netzwerkadapter** → die LAN-Karte → **Eigenschaften → Erweitert**. Bei Intel (z. B. I226-V) steht *Paketpriorität und VLAN* meist schon auf **aktiviert**. Bei Realtek muss *Priority & VLAN* auf **Priority & VLAN Enabled** stehen.
4. **Sichern:** Switch → **System → Backup and Restore → Backup Config**. In der pve01-Shell:
   ```bash
   cp /etc/network/interfaces /root/interfaces.vor-vlan10
   ```

## Teil 1 · Switch: VLAN 10 anlegen (Switch-Weboberfläche)

**VLAN → 802.1Q VLAN**

1. **802.1Q VLAN Configuration: Enable** → **Apply**. Die Warnung, dass andere VLAN-Modi abgeschaltet werden, bestätigen. VLAN 1 mit allen Ports untagged bleibt bestehen.
   > [!NOTE]
   > Nicht verwechseln mit **MTU VLAN** direkt darüber. Das bleibt auf *Disable*.
2. Oben im Formular: **VLAN ID** `10`, **VLAN Name** `LAB`
3. Port **5** (pve01) → **Tagged**, Port **7** (Arbeits-PC) → **Tagged**, alle anderen → **Not Member** → **Add/Modify**
4. In der Tabelle unten muss jetzt stehen: VLAN 10, *Member Ports* `5,7`, *Tagged Ports* `5,7`. Das Formular oben ist nur die Eingabe, **gültig ist die Tabelle**.
5. **802.1Q PVID Setting:** nichts ändern, alle Ports bleiben auf PVID **1**.
6. Links **Save Config → Save**, sonst ist alles nach einem Stromausfall weg.

**Prüfen:** Internet, Proxmox-Oberfläche und NAS laufen weiter. Es ist nur etwas dazugekommen.

**Rückweg:** VLAN 10 in der Tabelle anhaken → **Delete** → Save Config.

## Teil 2 · pve01: `vmbr1` an VLAN 10 hängen (Browser)

**pve01 → System → Network**

1. **Create → Linux VLAN**
   - **Name:** `nic0.10`. Proxmox füllt *VLAN raw device* (`nic0`) und *VLAN Tag* (`10`) aus dem Namen.
   - IPv4 und Gateway leer, **Autostart** an → **Create**
2. **vmbr1** markieren → **Edit** → **Bridge ports:** `nic0.10`. IPv4 `10.0.0.1/24` bleibt, kein Gateway → **OK**
3. Unten erscheint **Pending changes**: Neu ist nur `iface nic0.10`, bei vmbr1 wird aus `bridge-ports none` `bridge-ports nic0.10`. Bei **vmbr0 darf sich nichts ändern.**
4. **Apply Configuration**

> [!NOTE]
> Die NAT-Zeilen (`post-up … MASQUERADE`) bei vmbr1 zeigt die Oberfläche nicht an, schreibt sie aber mit zurück. Zur Sicherheit prüfen:
> ```bash
> grep -A10 "iface vmbr1" /etc/network/interfaces
> bridge link
> ```
> Die `post-up`/`post-down`-Zeilen müssen noch da sein, und `nic0.10` muss mit `master vmbr1` auftauchen.

**Prüfen:** DC01, FS01 und TOOLS01 sind weiter erreichbar, auf DC01 geht `ping 1.1.1.1`.

**Rückweg:** In **Network** die Änderung bei vmbr1 zurücknehmen, `nic0.10` löschen → Apply. Falls die Oberfläche nicht mehr erreichbar ist: Bildschirm und Tastatur an den Mini-PC, `cp /root/interfaces.vor-vlan10 /etc/network/interfaces && ifreload -a`.

## Teil 3 · Arbeits-PC: externer Hyper-V-Switch (Hyper-V-Manager)

> [!WARNING]
> Beim Anlegen ist der PC **ein paar Sekunden offline**. VPN-Programme (z. B. NordVPN) vorher trennen.

1. Hyper-V-Manager → rechts **Manager für virtuelle Switches…**
2. Links **Neuer virtueller Netzwerkswitch** → rechts **Extern** → **Virtuellen Switch erstellen**
3. **Name:** `Extern`
4. **Externes Netzwerk:** die kabelgebundene Netzwerkkarte
5. **„Gemeinsames Verwenden dieses Netzwerkadapters für das Verwaltungsbetriebssystem zulassen“ → an.** Ohne den Haken hat der PC selbst kein Netz mehr.
6. **„VLAN-Identifikation für das Verwaltungsbetriebssystem aktivieren“ → aus.** Der PC bleibt untagged im Heimnetz.
7. **OK** → Warnung mit **Ja** bestätigen

**Prüfen:** `Win + R` → `ncpa.cpl`. **vEthernet (Extern)** ist aktiv und hat die gewohnte Heimnetz-Adresse. Die Karte **Ethernet** darunter zeigt kein eigenes Netz mehr (sie gehört jetzt dem Switch). Falls du eine feste DNS-Einstellung hattest, auf **vEthernet (Extern)** neu eintragen. Danach prüfen, ob das Lab vom PC aus noch erreichbar ist (RDP auf DC01). Eine feste Route `10.0.0.0/24` über pve01 ([Kapitel 17](17-umzug-hyperv-proxmox.md)) muss eventuell neu gesetzt werden.

**Rückweg:** Switch im Manager markieren → **Entfernen**. Der PC hat sofort wieder die normale Karte.

## Teil 4 · Testclient anlegen (Hyper-V-Manager)

**VM anlegen:** rechts **Neu → Virtueller Computer…**

| Seite | Eintrag |
|---|---|
| Name | `CLIENT02` |
| Generation | **Generation 2** |
| Arbeitsspeicher | 4096 MB, dynamisch darf an bleiben |
| Netzwerk | `Extern` |
| Festplatte | 64 GB (Minimum für Windows 11) |
| Installationsoptionen | Startbare Image-Datei → Windows-11-ISO |

**Noch nicht starten**, erst **Einstellungen**:

- **Sicherheit:** Sicherer Start an (Vorlage *Microsoft Windows*), **Trusted Platform Module aktivieren**
- **Prozessor:** 2–4 virtuelle Prozessoren
- **Netzwerkkarte:** **„Identifizierung virtueller LANs aktivieren“** an, **VLAN-ID** `10`
- **Prüfpunkte:** *Automatische Prüfpunkte verwenden* aus

**Installieren:** VM starten, **Verbinden**, sofort eine Taste drücken (*Press any key to boot from CD*), Windows 11 **Pro** installieren. Für ein lokales Konto statt Microsoft-Konto beim Einrichten **Shift+F10** → `start ms-cxh:localonly`. Als Namen etwas Neutrales wie `localadmin`, das Kennwort in den Kennwortmanager.

**Prüfen in der VM:** Eingabeaufforderung → `ipconfig`

- **IPv4** `10.0.0.1xx`, **Gateway** `10.0.0.1`, **DNS-Suffix** `lab.test` → VLAN funktioniert
- **169.254.x.x** → der Tag kommt nicht an, siehe [Fehlersuche](#fehlersuche-wenn-der-client-keine-10001xx-bekommt)
- **192.168.2.x** → die VLAN-ID an der VM fehlt, der Client ist im Heimnetz gelandet

> [!TIP]
> Bleibt nach einer Korrektur die Meldung *„Der im Netzwerkkontrollblock (NCB) angegebene Name ist auf einem Remoteadapter in Verwendung“*, hängt Windows noch an der alten Adresse. `ipconfig /release` (Eingabeaufforderung **als Administrator**) und `ipconfig /renew`, oder die VM einmal neu starten.

## Teil 5 · Domäne und Computername (in der VM, DC01)

1. **Computername:** Windows vergibt einen Zufallsnamen wie `DESKTOP-XXXXXXX`. Der Name der VM in Hyper-V ändert daran nichts. `Win + R` → `sysdm.cpl` → **Computername → Ändern…** → `CLIENT02`
2. Im selben Fenster **Domäne:** `lab.test` → Anmeldung mit einem Domänen-Admin → **Neustart**
   (Man kann auch erst beitreten und danach umbenennen, das Computerkonto in AD wird mit umbenannt.)
3. Auf DC01: **Active Directory Users and Computers** → das Konto landet in **Computers**. Nach **Lab → Computer** verschieben, damit die GPOs aus [Kapitel 8](08-gruppenrichtlinien.md) greifen. Nach **F5** steht dort `CLIENT02`.

**Prüfen:** Nach dem Neustart als Testbenutzer anmelden, `gpresult /r` zeigt die GPOs aus *Lab/Computer*, Laufwerk **S:** ist da.

## Fehlersuche: wenn der Client keine 10.0.0.1xx bekommt

So habe ich das Problem eingegrenzt, von der VM bis zu pve01:

**1. Kommt die VM ohne VLAN überhaupt raus?** VLAN-Haken an der VM kurz raus, in der VM `ipconfig /renew`. Gibt es eine Heimnetz-Adresse, funktioniert der Hyper-V-Switch, und das Problem liegt beim Tag.

**2. Zählt pve01 Pakete aus VLAN 10?** In der pve01-Shell:

```bash
ip -s link show nic0.10
```

Unter **RX** stehen die empfangenen, unter **TX** die gesendeten Pakete.

| RX | TX | Bedeutung |
|---|---|---|
| 0 | hoch | pve01 schickt getaggte Pakete raus, bekommt aber nie welche zurück. **Fast immer: VLAN auf dem falschen Switch-Port** (siehe Teil 0) |
| steigt | steigt | VLAN läuft, Problem eher bei DHCP auf DC01 |

**3. Mitschneiden auf pve01:** Kommen DHCP-Anfragen des Clients an? Die MAC-Adresse der VM steht in Hyper-V unter **Netzwerkkarte → Erweiterte Features**.

```bash
tcpdump -eni nic0 vlan 10 and port 67
tcpdump -eni nic0 ether host 00:15:5d:xx:xx:xx
```

Mit **Strg+C** beenden. Läuft der Test, während der PC selbst offline ist, im Hintergrund in eine Datei schneiden und danach lesen:

```bash
timeout 300 tcpdump -eni nic0 -w /root/vlantest.pcap ether host 00:15:5d:xx:xx:xx &
tcpdump -enr /root/vlantest.pcap
```

**4. Mitschneiden auf dem Arbeits-PC:** Windows hat mit `pktmon` einen eingebauten Mitschnitt (Eingabeaufforderung als Administrator):

```bat
pktmon filter add -p 67
pktmon start --capture --comp nics -f C:\vlan.etl
:: in der VM ipconfig /renew, dann
pktmon stop
pktmon format C:\vlan.etl -o C:\vlan.txt
```

In der Textdatei sieht man, ob das Paket bis zum Treiber der Netzwerkkarte kommt. `DropReason Filtered VLAN` am Port `Extern` ist normal: Hyper-V gibt Pakete aus VLAN 10 nicht an den PC selbst weiter.

> [!NOTE]
> Den eigentlichen VLAN-Tag setzt die Netzwerkkarte in Hardware, das zeigt `pktmon` nicht mehr. Ob er am Switch ankommt, sieht man nur auf der anderen Seite (Schritt 2 und 3).

## Häufige Fehler

| Problem | Ursache | Lösung |
|---|---|---|
| Client bekommt 169.254.x.x, `nic0.10` zeigt RX 0 | VLAN 10 auf dem falschen Switch-Port, der Mini-PC hängt woanders | Port per *Port Statistics* prüfen, VLAN 10 auf dem richtigen Port tagged, Save Config |
| Client bekommt 192.168.2.x | VLAN-ID an der VM fehlt | VLAN-ID 10 setzen |
| PC nach Teil 3 offline | Haken *Gemeinsames Verwenden* fehlte | Switch löschen bzw. Haken setzen |
| Nach PC-Neustart: VM „Medium getrennt“, vEthernet (Extern) „Netzwerkkabel wurde entfernt“ | Hyper-V-Switch hat sich nach Treiber-Änderung von der Karte gelöst | Switch `Extern` entfernen und neu anlegen, VM wieder anhängen |
| PC ohne Netz nach Umstellen von *Paketpriorität und VLAN* | Intel-Treiber hängt mit externem Hyper-V-Switch | Einstellung zurück, PC neu starten |
| DC01 verteilt IPs im Heimnetz | VLAN 10 versehentlich untagged bzw. PVID 10 auf einem Heimnetz-Port | Nur Mini-PC und Arbeits-PC **tagged**, PVID überall 1 |
| Switch-Einstellungen nach Stromausfall weg | Kein *Save Config* | Nach jeder Änderung Save Config |

Weitere Fälle: [Fehlerbehebung](../fehlerbehebung.md#vlan-kapitel-19)

Wie es weitergeht: Das Clientnetz soll später ein eigenes VLAN hinter einer Firewall (OPNsense) bekommen, siehe [Roadmap](../roadmap.md). Dieses Kapitel ist die Grundlage dafür.

Weiter: [Kapitel 20 · Rack-Display](20-rack-display.md)
