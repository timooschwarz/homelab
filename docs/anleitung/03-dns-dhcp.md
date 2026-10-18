# 3 · DNS und DHCP

[← 2 · Domain Controller](02-domain-controller.md) · [Übersicht](../../README.md#anleitung) · weiter: [4 · AD-Struktur →](04-ad-struktur.md)

## Reverse-Lookupzone

Damit `nslookup 10.0.0.10` einen Namen liefert:

1. DNS-Manager → **Reverse-Lookupzonen** → Rechtsklick → **Neue Zone**
2. Primäre Zone, im AD speichern → *An alle DNS-Server in dieser Domäne*
3. IPv4 → Netzwerk-ID `10.0.0`
4. Nur sichere dynamische Updates → Fertig stellen

Für feste Server neue A-Einträge immer mit Haken **„Verknüpften PTR-Eintrag erstellen“** anlegen. Clients registrieren sich selbst, notfalls mit `ipconfig /registerdns`.

Prüfen: `nslookup 10.0.0.10` muss `dc01.lab.test` zurückgeben.

## DHCP

1. Server-Manager → Rollen hinzufügen → **DHCP-Server**
2. Danach das gelbe Fähnchen → **DHCP-Konfiguration abschließen** → Autorisieren mit dem Domänen-Admin
3. Tools → **DHCP** → `dc01.lab.test` → IPv4 → Rechtsklick → **Neuer Bereich**

| Einstellung | Wert |
|---|---|
| Name | `Lab` |
| Bereich | `10.0.0.100` – `10.0.0.200`, Maske `255.255.255.0` |
| Router (Gateway) | `10.0.0.1` |
| DNS-Server | `10.0.0.10`, Domäne `lab.test` |
| Bereich aktivieren | Ja |

Feste Adressen (Server) liegen unter `.100`, DHCP-Clients ab `.100`.

## AD-Standort und Subnetz

Active Directory-Standorte und -Dienste → **Subnets** → Rechtsklick → Neues Subnetz → `10.0.0.0/24` → Standort *Default-First-Site-Name*. Ohne Subnetz meckern später MECM und Clients bei der Standortsuche.
