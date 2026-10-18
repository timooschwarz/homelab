# Kapitel 3 · DNS und DHCP

[← Kapitel 2](02-domain-controller.md) · [Übersicht](../../README.md#anleitung) · weiter: [Kapitel 4 · AD-Struktur →](04-ad-struktur.md)

> **Ziel:** Saubere Namensauflösung in beide Richtungen und automatische IP-Adressen für Clients.
> **Dauer:** ca. 20 Minuten · **Wo:** DC01

## Schritt 1 · Reverse-Lookupzone anlegen

Damit `nslookup 10.0.0.10` einen Namen liefert und nicht *„Non-existent domain“*:

1. Server-Manager → **Tools → DNS**
2. Rechtsklick auf **Reverse-Lookupzonen** → **Neue Zone**
3. **Primäre Zone**, Haken bei *Zone in Active Directory speichern*
4. Replikation: *An alle DNS-Server in dieser Domäne*
5. **IPv4-Reverse-Lookupzone** → Netzwerk-ID `10.0.0`
6. **Nur sichere dynamische Updates zulassen** → Fertig stellen

## Schritt 2 · Einträge für feste Server

Feste Server (FS01, TOOLS01 …) bekommen von Hand einen Eintrag: Forward-Lookupzonen → `lab.test` → Rechtsklick → **Neuer Host (A oder AAAA)** → Name und IP → Haken bei **„Verknüpften PTR-Eintrag erstellen“**.

<p align="center">
  <img src="../bilder/dns-a-eintrag-ptr.png" width="36%" alt="A-Eintrag mit PTR">
  <img src="../bilder/dns-forward-zone.png" width="62%" alt="Forward-Zone lab.test">
</p>

Windows-Rechner in der Domäne tragen sich selbst ein. Notfalls auf dem Rechner `ipconfig /registerdns`.

> [!WARNING]
> Ein falscher PTR-Eintrag fällt lange nicht auf. Im Lab zeigte `10.0.0.10` einmal auf `tools01` statt auf `dc01`. Deshalb nach jedem neuen Server einmal `nslookup <IP>` testen.

## Schritt 3 · DHCP installieren

1. Server-Manager → Rollen hinzufügen → **DHCP-Server** → Installieren
2. Gelbes Fähnchen → **DHCP-Konfiguration abschließen** → *Commit* mit dem Domänen-Admin. Das **autorisiert** den DHCP-Server im AD, ohne Autorisierung verteilt er nichts.

## Schritt 4 · Bereich anlegen

**Tools → DHCP** → `dc01.lab.test` → Rechtsklick auf **IPv4** → **Neuer Bereich**:

| Seite | Einstellung |
|---|---|
| Name | `Lab` |
| IP-Adressbereich | `10.0.0.100` bis `10.0.0.200`, Länge 24 |
| Ausschlüsse | keine |
| Leasedauer | 8 Tage (Standard) |
| Router (Standardgateway) | `10.0.0.1` → Hinzufügen |
| Domänenname und DNS-Server | `lab.test`, `10.0.0.10` |
| WINS | überspringen |
| Bereich aktivieren | Ja |

Server bekommen feste Adressen **unterhalb** von `.100`, Clients alles ab `.100`.

## Schritt 5 · AD-Subnetz eintragen

**Tools → Active Directory-Standorte und -Dienste** → *Sites* → Rechtsklick auf **Subnets** → Neues Subnetz → `10.0.0.0/24` → Standort *Default-First-Site-Name*.

Ohne Subnetz finden Clients und später MECM ihren AD-Standort nicht.

## Prüfen

| Test (auf DC01) | Erwartet |
|---|---|
| `nslookup 10.0.0.10` | `dc01.lab.test` |
| `nslookup dc01.lab.test` | `10.0.0.10` |
| DHCP-Konsole → IPv4 | grüner Haken, Bereich *aktiv* |
