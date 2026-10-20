# Homelab `lab.test`: Windows-Firmennetz in Hyper-V

**Eine Schritt-für-Schritt-Anleitung zum Nachbauen.** Active Directory, DNS, DHCP, Dateiserver mit Abteilungsrechten, Gruppenrichtlinien, Windows LAPS und MECM, alles auf einem einzigen PC mit Hyper-V.

![Windows Server 2025](https://img.shields.io/badge/Windows%20Server-2025-0078D4?logo=windows&logoColor=white)
![Windows 11](https://img.shields.io/badge/Client-Windows%2011-0078D4?logo=windows11&logoColor=white)
![Hyper-V](https://img.shields.io/badge/Hyper--V-Lab-5C2D91)
![MECM](https://img.shields.io/badge/MECM-Current%20Branch-107C10)
![Ubuntu](https://img.shields.io/badge/Ubuntu-Docker-E95420?logo=ubuntu&logoColor=white)

![Netzwerk des Labs](docs/diagramme/netzwerk-2026-10-18.png)

---

## Inhaltsverzeichnis

1. [Einführung](#einführung)
2. [Teil 1 · Vorbereitung](#teil-1--vorbereitung)
3. [Teil 2 · Active Directory](#teil-2--active-directory)
4. [Teil 3 · Client, Dateiserver und Gruppenrichtlinien](#teil-3--client-dateiserver-und-gruppenrichtlinien)
5. [Teil 4 · Testen](#teil-4--testen)
6. [Teil 5 · Optional: Linux-Dienste, MECM und Wazuh](#teil-5--optional-linux-dienste-mecm-und-wazuh)
7. [Nach Thema](#nach-thema)
8. [Betrieb: Starten und Stoppen](#betrieb-starten-und-stoppen)
9. [Fehler, aus denen ich am meisten gelernt habe](#fehler-aus-denen-ich-am-meisten-gelernt-habe)
10. [Was ich dabei gelernt habe](#was-ich-dabei-gelernt-habe)
11. [Wie es weitergeht](#wie-es-weitergeht)
12. [Aufbau des Repos](#aufbau-des-repos)

---

## Einführung

Ich habe dieses Lab als Junior Admin aufgebaut, um Alltagsaufgaben aus der Firma gefahrlos zu üben: Benutzer anlegen, Rechte vergeben, Laufwerke verteilen, Software ausrollen. Diese Anleitung beschreibt jeden Schritt so, dass du ihn nachklicken kannst, **inklusive der Fehler, die mir dabei passiert sind**, und wie man sie findet.

**Für wen:** Azubis und Einsteiger in der Systemintegration und alle, die sich auf ein Vorstellungsgespräch als Windows-Admin vorbereiten.

**Was am Ende läuft:**

- Domäne `lab.test` mit sauberer OU-Struktur unter `Lab/`
- Rund 120 Testbenutzer in 5 Abteilungen, per [Skript](scripts/New-LabBulkUsers.ps1) aus einer CSV angelegt
- Freigabe `\\fs01\Abteilungen`, in der jeder nur seinen Abteilungsordner sieht
- Laufwerk **S:** automatisch je nach Abteilung
- RDP nur für bestimmte Abteilungen, lokale Admin-Kennwörter per Windows LAPS
- MECM mit Client-Push und Softwareverteilung auf den Windows-11-Client
- Sicherheitsüberwachung mit Wazuh: Fehlanmeldungen und neue Konten werden gemeldet
- Optional: Uptime Kuma, Netdata, Nginx Proxy Manager, NetBox, Warpgate und eine Netzwerkkarte mit Live-Status (Homelable auf Proxmox)

**So sind die Kapitel aufgebaut:** Ziel und Dauer · nummerierte Schritte mit Angabe, auf welchem Rechner du gerade bist · Prüfen · häufige Fehler. Über 50 Screenshots stammen direkt aus dem Lab. Gearbeitet wird überwiegend mit der Oberfläche, PowerShell nur dort, wo es deutlich schneller ist.

> [!TIP]
> Die Server laufen auf Englisch. Klickwege stehen deshalb so da: **English name** (deutscher Name).

**Zeitbedarf:** Teil 1–4 etwa ein Tag. Teil 5 ist optional, MECM allein braucht einen halben Tag.

**Getestet mit** (Stand Oktober 2026):

| Komponente | Version |
|---|---|
| Hyper-V-Host | Windows 11 mit Hyper-V (ab Pro), 64 GB RAM |
| Server | Windows Server 2025 Evaluation, englische Oberfläche |
| Client | Windows 11, deutsche Oberfläche |
| MECM | Configuration Manager Current Branch, Build 9141 |
| Datenbank | SQL Server 2022 Evaluation |
| Linux | Ubuntu Server 26.04 LTS mit Docker |
| NetBox | v4.7.2 |
| Proxmox VE · Homelable | 9.2 · 3.6 |

---

## Teil 1 · Vorbereitung

Bevor die erste VM läuft: Hardware prüfen, Hyper-V einschalten und ein eigenes Netz für das Lab bauen.

| Kapitel | Was du machst |
|---|---|
| [0 · Voraussetzungen](docs/anleitung/00-voraussetzungen.md) | Hardware, ISOs herunterladen, Hyper-V aktivieren, VM-Assistent |
| [1 · Netzwerk](docs/anleitung/01-netzwerk.md) | Interner Switch `LAB` mit NAT, damit die VMs ins Internet kommen |

<p align="center">
  <img src="docs/bilder/hyperv-neue-vm-generation.png" width="49%" alt="Hyper-V: neue VM">
  <img src="docs/bilder/hyperv-vm-netzwerkkarte.png" width="49%" alt="VM am Switch LAB">
</p>

**[→ Los geht's mit Kapitel 0](docs/anleitung/00-voraussetzungen.md)**

---

## Teil 2 · Active Directory

Das Herz des Labs: DC01 wird Domain Controller für `lab.test`, bekommt DNS und DHCP, und du legst die Struktur an, an die später alle Richtlinien gehängt werden.

| Kapitel | Was du machst |
|---|---|
| [2 · Domain Controller](docs/anleitung/02-domain-controller.md) | Windows Server installieren, AD DS, neue Gesamtstruktur `lab.test` |
| [3 · DNS und DHCP](docs/anleitung/03-dns-dhcp.md) | Reverse-Zone, A- und PTR-Einträge, DHCP-Bereich, AD-Subnetz |
| [4 · AD-Struktur](docs/anleitung/04-ad-struktur.md) | OUs, Abteilungsgruppen, getrennte Admin-Konten, AD-Papierkorb |
| [5 · Benutzer per Skript](docs/anleitung/05-benutzer-per-skript.md) | Über 100 Testbenutzer aus einer CSV, mit Probelauf |

![AD-Struktur mit OUs, GPOs und Gruppen](docs/diagramme/ad-struktur.png)

<sub>Stand des fertigen Labs. Einige GPOs (Systemsteuerung sperren, Ping, Design, Firewall für MECM) gehen über die Anleitung hinaus und sind in der [Aufbau-Referenz](docs/aufbau.md#gruppenrichtlinien) beschrieben.</sub>

**[→ Weiter mit Kapitel 2](docs/anleitung/02-domain-controller.md)**

---

## Teil 3 · Client, Dateiserver und Gruppenrichtlinien

Jetzt wird es ein echtes Firmennetz: ein Windows-11-Client tritt der Domäne bei, FS01 stellt Abteilungsordner bereit, und Gruppenrichtlinien verteilen Laufwerke und Rechte.

| Kapitel | Was du machst |
|---|---|
| [6 · Client](docs/anleitung/06-client.md) | Windows 11 installieren und der Domäne beitreten |
| [7 · Dateiserver](docs/anleitung/07-dateiserver.md) | Zweite Platte, Freigabe, NTFS-Rechte pro Abteilung, zugriffsbasierte Aufzählung |
| [8 · Gruppenrichtlinien](docs/anleitung/08-gruppenrichtlinien.md) | Laufwerk S:, RDP für bestimmte Abteilungen, Windows LAPS, Zeitquelle |

<p align="center">
  <img src="docs/bilder/gpo-laufwerk-s.png" width="49%" alt="GPO mit Laufwerkszuordnungen">
  <img src="docs/bilder/laufwerk-s-client.png" width="49%" alt="Laufwerk S: auf dem Client">
</p>

**[→ Weiter mit Kapitel 6](docs/anleitung/06-client.md)**

---

## Teil 4 · Testen

Mit einem Benutzer **jeder** Abteilung prüfen, ob Laufwerk, Ordner und RDP so funktionieren wie geplant. Hier findest du die Fehler, die beim Einrichten nicht auffallen.

| Kapitel | Was du machst |
|---|---|
| [9 · Testen](docs/anleitung/09-testen.md) | Testplan pro Abteilung, `gpresult`, was tun, wenn S: fehlt |

**[→ Weiter mit Kapitel 9](docs/anleitung/09-testen.md)**

---

## Teil 5 · Optional: Linux-Dienste, MECM und Wazuh

Für alle, die mehr wollen: eine Ubuntu-VM mit Docker für Überwachung und Verwaltung, ein Configuration Manager, wie er in vielen Firmen läuft, und eine Karte des ganzen Labs mit Live-Status.

| Kapitel | Was du machst |
|---|---|
| [10 · Linux-Dienste](docs/anleitung/10-linux-dienste.md) | Ubuntu, Docker, Uptime Kuma, Nginx Proxy Manager, NetBox |
| [11 · MECM](docs/anleitung/11-mecm.md) | SQL Server, Configuration Manager, Enhanced HTTP, Client-Push |
| [12 · Software verteilen](docs/anleitung/12-softwareverteilung.md) | 7-Zip als Anwendung, Softwarecenter, Pflicht-Installation |
| [13 · Wazuh](docs/anleitung/13-wazuh.md) | SIEM auf LOG01, Agents auf allen Windows-Rechnern, Fehlanmeldungen erkennen |
| [14 · Homelable](docs/anleitung/14-homelable.md) | Proxmox als VM in Hyper-V, Netzwerkkarte des Labs mit Live-Status, Ping für Server freigeben |

<p align="center">
  <img src="docs/bilder/uptime-kuma-dashboard.png" width="49%" alt="Uptime Kuma">
  <img src="docs/bilder/mecm-konsole-geraete.png" width="49%" alt="MECM-Konsole">
</p>

**[→ Weiter mit Kapitel 10](docs/anleitung/10-linux-dienste.md)**

---

## Nach Thema

Jedes Kapitel hat oben Tags. Ein Klick auf einen Tag führt hierher, zu allen Kapiteln mit diesem Thema.

| Thema | Kapitel |
|---|---|
| <a id="thema-ad"></a>![Active Directory](https://img.shields.io/badge/-Active%20Directory-378ADD?style=flat-square) | [2 · Domain Controller](docs/anleitung/02-domain-controller.md) · [3 · DNS und DHCP](docs/anleitung/03-dns-dhcp.md) · [4 · AD-Struktur](docs/anleitung/04-ad-struktur.md) · [5 · Benutzer per Skript](docs/anleitung/05-benutzer-per-skript.md) · [6 · Client](docs/anleitung/06-client.md) · [11 · MECM](docs/anleitung/11-mecm.md) |
| <a id="thema-dns"></a>![DNS](https://img.shields.io/badge/-DNS-1D9E75?style=flat-square) | [2 · Domain Controller](docs/anleitung/02-domain-controller.md) · [3 · DNS und DHCP](docs/anleitung/03-dns-dhcp.md) · [10 · Linux-Dienste](docs/anleitung/10-linux-dienste.md) |
| <a id="thema-dhcp"></a>![DHCP](https://img.shields.io/badge/-DHCP-1D9E75?style=flat-square) | [3 · DNS und DHCP](docs/anleitung/03-dns-dhcp.md) |
| <a id="thema-netz"></a>![Netzwerk](https://img.shields.io/badge/-Netzwerk-1D9E75?style=flat-square) | [1 · Netzwerk](docs/anleitung/01-netzwerk.md) · [10 · Linux-Dienste](docs/anleitung/10-linux-dienste.md) · [14 · Homelable](docs/anleitung/14-homelable.md) · [Hardware](docs/hardware.md) |
| <a id="thema-gpo"></a>![Gruppenrichtlinien](https://img.shields.io/badge/-Gruppenrichtlinien-7F77DD?style=flat-square) | [8 · Gruppenrichtlinien](docs/anleitung/08-gruppenrichtlinien.md) · [9 · Testen](docs/anleitung/09-testen.md) · [11 · MECM](docs/anleitung/11-mecm.md) · [14 · Homelable](docs/anleitung/14-homelable.md) |
| <a id="thema-file"></a>![Dateiserver](https://img.shields.io/badge/-Dateiserver-0F766E?style=flat-square) | [7 · Dateiserver](docs/anleitung/07-dateiserver.md) · [8 · Gruppenrichtlinien](docs/anleitung/08-gruppenrichtlinien.md) · [9 · Testen](docs/anleitung/09-testen.md) |
| <a id="thema-sec"></a>![Sicherheit](https://img.shields.io/badge/-Sicherheit-EF9F27?style=flat-square) | [4 · AD-Struktur](docs/anleitung/04-ad-struktur.md) · [7 · Dateiserver](docs/anleitung/07-dateiserver.md) · [8 · Gruppenrichtlinien](docs/anleitung/08-gruppenrichtlinien.md) · [13 · Wazuh](docs/anleitung/13-wazuh.md) |
| <a id="thema-client"></a>![Windows 11](https://img.shields.io/badge/-Windows%2011-0078D4?style=flat-square) | [6 · Client](docs/anleitung/06-client.md) · [12 · Software verteilen](docs/anleitung/12-softwareverteilung.md) |
| <a id="thema-ps"></a>![PowerShell](https://img.shields.io/badge/-PowerShell-5391FE?style=flat-square) | [1 · Netzwerk](docs/anleitung/01-netzwerk.md) · [5 · Benutzer per Skript](docs/anleitung/05-benutzer-per-skript.md) |
| <a id="thema-hyperv"></a>![Hyper-V](https://img.shields.io/badge/-Hyper--V-5F5E5A?style=flat-square) | [0 · Voraussetzungen](docs/anleitung/00-voraussetzungen.md) · [1 · Netzwerk](docs/anleitung/01-netzwerk.md) · [14 · Homelable](docs/anleitung/14-homelable.md) |
| <a id="thema-test"></a>![Testen](https://img.shields.io/badge/-Testen-D4537E?style=flat-square) | [9 · Testen](docs/anleitung/09-testen.md) · [12 · Software verteilen](docs/anleitung/12-softwareverteilung.md) · [13 · Wazuh](docs/anleitung/13-wazuh.md) |
| <a id="thema-linux"></a>![Linux & Docker](https://img.shields.io/badge/-Linux%20%26%20Docker-E95420?style=flat-square) | [10 · Linux-Dienste](docs/anleitung/10-linux-dienste.md) · [13 · Wazuh](docs/anleitung/13-wazuh.md) · [14 · Homelable](docs/anleitung/14-homelable.md) |
| <a id="thema-mecm"></a>![MECM](https://img.shields.io/badge/-MECM-107C10?style=flat-square) | [11 · MECM](docs/anleitung/11-mecm.md) · [12 · Software verteilen](docs/anleitung/12-softwareverteilung.md) |

---

## Betrieb: Starten und Stoppen

DC01 startet immer zuerst und fährt zuletzt herunter. Ohne DC01 gibt es kein DNS, und die anderen VMs laufen in Fehler.

![Startreihenfolge der VMs](docs/diagramme/startreihenfolge.png)

Alle Server, GPOs und Rechte im fertigen Lab: [Aufbau](docs/aufbau.md)

---

## Fehler, aus denen ich am meisten gelernt habe

| Problem | Ursache | Lösung |
|---|---|---|
| Laufwerk S: fehlt, ohne Fehlermeldung | NTFS-Rechte von zwei Ordnern beim Anlegen vertauscht | Rechte korrigiert. Fehlt der Zugriff aufs Ziel, scheitert die Zuordnung still |
| Kollegen können Dateien der eigenen Abteilung nicht öffnen | NTFS-Recht galt nur für *This folder only* | *This folder, subfolders and files* |
| GPO macht Dienstkonto nicht zum lokalen Admin, es entsteht eine Gruppe „ad“ | Gruppenname von Hand eingetippt | Eingebaute Gruppe per Dropdown wählen |
| MECM-Client: `CCM_E_NO_CLIENT_PKI_CERT` | Site auf HTTPS only, keine PKI | Enhanced HTTP |
| Linux-VMs stürzen ab (OOM, Kernel Panic) | Dynamischer Arbeitsspeicher | Fester RAM für Linux und SQL Server |

Alle 31 Fälle: [Fehlerbehebung](docs/fehlerbehebung.md)

---

## Was ich dabei gelernt habe

- **Mit einem Benutzer jeder Abteilung testen.** Ein Testkonto pro Abteilung hat zwei vertauschte Ordnerrechte und ein falsches NTFS-Recht lange versteckt. Erst der Test mit Kollegen aus derselben Abteilung hat sie gezeigt.
- **Fehler ohne Meldung systematisch eingrenzen.** Wenn S: einfach fehlt, die Kette Benutzer → Gruppe → GPO → Freigabe → NTFS von vorne prüfen, mit `gpresult /r` und `whoami /groups`, statt zu raten.
- **Rechte über Gruppen, Freigabe großzügig, NTFS streng.** So gibt es nur eine Stelle, an der Zugriffe gesteuert werden.
- **DNS zuerst.** Domänenbeitritt, Anmeldung, MECM und Reverse Proxy hängen davon ab. Ein falscher PTR-Eintrag ist lange nicht aufgefallen.
- **Getrennte Konten und LAPS.** Verwaltet wird mit dem Admin-Konto, gearbeitet mit dem normalen Konto, und jeder Rechner hat ein eigenes lokales Admin-Kennwort.
- **Vor jedem Umbau sichern.** Prüfpunkt der VM und GPO-Sicherung kosten eine Minute und haben mehrmals eine Neuinstallation erspart.
- **Abhängigkeiten früh klären.** MECM braucht die richtige SQL-Sortierung und ohne eigene PKI Enhanced HTTP. Beides fällt erst spät auf, wenn man es nicht vorher weiß.
- **Dokumentieren, während man baut.** Jede Änderung steht im [Changelog](docs/changelog.md), IP-Adressen und VMs stehen in NetBox.

---

## Wie es weitergeht

![Roadmap: Ausbaustufen](docs/diagramme/roadmap.png)

Details: [Roadmap](docs/roadmap.md) · Eigene Hardware im 10-Zoll-Rack: [Hardware](docs/hardware.md) · Warum etwas so gebaut ist: [Entscheidungen](docs/entscheidungen.md) · Was wann dazukam: [Changelog](docs/changelog.md)

---

## Aufbau des Repos

```
docs/
  anleitung/          Schritt-für-Schritt-Anleitung, Kapitel 0–14
  bilder/             Screenshots aus dem Lab
  diagramme/          Übersichtsgrafiken
  aufbau.md           Referenz des fertigen Labs
  hardware.md         Mini-PC, Switch und NAS im 10-Zoll-Rack
  fehlerbehebung.md   Gelöste Fehler mit Ursache und Lösung
  entscheidungen.md   Begründungen
  roadmap.md          Nächste Ausbaustufen
  changelog.md        Was wann dazukam
scripts/
  New-LabBulkUsers.ps1   Testbenutzer per CSV anlegen
  benutzer.example.csv   Beispiel-CSV
```

---

Alle Namen, Benutzer und Adressen sind Testdaten. Kennwörter stehen nicht in diesem Repo. Nutzung auf eigene Gefahr, bitte nur in einer eigenen Testumgebung.

Lizenz: Anleitung, Screenshots und Grafiken unter [CC BY 4.0](LICENSE-docs.md), Skripte unter [MIT](LICENSE).
