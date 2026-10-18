# 2 · Domain Controller DC01

[← 1 · Netzwerk](01-netzwerk.md) · [Übersicht](../../README.md#anleitung) · weiter: [3 · DNS und DHCP →](03-dns-dhcp.md)

## VM anlegen

Hyper-V-Manager → **Neu → Virtueller Computer**:

| Einstellung | Wert |
|---|---|
| Name | `DC01` |
| Generation | **2** |
| Arbeitsspeicher | **4096 MB, dynamisch aus** (nur für die Installation) |
| Netzwerk | `LAB` |
| Festplatte | 60 GB |
| Installation | Windows-Server-ISO |

> [!WARNING]
> Mit dynamischem RAM und 2 GB Startwert bricht das Setup gern mit *„Windows Server installation has failed“* ab. Nach der Installation kannst du wieder auf dynamisch (z. B. 2 GB Start, max. 4 GB) umstellen.

Beim ersten Start sofort eine Taste drücken („Press any key to boot from CD or DVD“), sonst landet die VM im PXE-Boot.

Bei der Installation **Windows Server 2025 Standard (Desktop Experience)** wählen.

## Grundeinstellungen

Im **Server-Manager → Lokaler Server**:

1. **Computername** → `DC01` → Neustart
2. **Zeitzone** → *(UTC+01:00) Amsterdam, Berlin …*
   Bei englischer Installation steht hier Pacific Time. Merkt man sonst erst, wenn die Uhr 9 Stunden falsch geht.
3. **Ethernet** → Eigenschaften → IPv4:

| | |
|---|---|
| IP-Adresse | `10.0.0.10` |
| Subnetzmaske | `255.255.255.0` |
| Gateway | `10.0.0.1` |
| Bevorzugter DNS | `127.0.0.1` |

Test: `ping 10.0.0.1` und `ping 8.8.8.8` müssen gehen.

## Active Directory installieren

1. Server-Manager → **Verwalten → Rollen und Features hinzufügen**
2. Rollenbasierte Installation → DC01 → Haken bei **Active Directory-Domänendienste** → Features hinzufügen → Installieren
3. Danach oben das gelbe Fähnchen → **Server zu einem Domänencontroller heraufstufen**
4. **Neue Gesamtstruktur hinzufügen** → Stammdomäne `lab.test`
5. DSRM-Kennwort vergeben und **sicher aufheben** (brauchst du für Wiederherstellungen)
6. NetBIOS-Name `LAB` übernehmen → durchklicken → Installieren, Server startet neu

Ab jetzt meldest du dich mit `LAB\Administrator` an.

## DNS-Weiterleitung

DNS-Manager (Server-Manager → Tools → DNS) → Rechtsklick auf **DC01** → Eigenschaften → **Weiterleitungen** → `8.8.8.8` (oder deinen Router) eintragen. Damit lösen die VMs auch Internet-Namen auf.

## Zeit richtig einstellen

Der Domain Controller ist die Zeitquelle der ganzen Domäne. Damit der Hyper-V-Host nicht dazwischenfunkt:

1. Hyper-V-Manager → DC01 → Einstellungen → **Integrationsdienste** → Haken bei **Zeitsynchronisierung** entfernen
2. Die NTP-Quelle stellst du per GPO ein, siehe [Kapitel 8](08-gruppenrichtlinien.md#zeit-für-die-domäne)

## DC01 automatisch starten

Hyper-V-Manager → DC01 → Einstellungen → **Automatische Startaktion** → *Immer automatisch starten*.

> [!IMPORTANT]
> DC01 muss immer **als Erstes** laufen. Ohne ihn gibt es kein DNS und keine Anmeldung, und alle anderen VMs laufen in Fehler. Beim Herunterfahren DC01 als Letztes.
