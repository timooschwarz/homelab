# Kapitel 2 · Domain Controller DC01

[← Kapitel 1](01-netzwerk.md) · [Übersicht](../../README.md#anleitung) · weiter: [Kapitel 3 · DNS und DHCP →](03-dns-dhcp.md)

> **Ziel:** Ein Windows Server 2025 als Domain Controller für die neue Domäne `lab.test`.
> **Dauer:** ca. 45 Minuten · **Wo:** Host (VM anlegen), danach in DC01

## Voraussetzungen

- Switch `LAB` aus Kapitel 1
- Windows-Server-2025-ISO

## Schritt 1 · VM anlegen (Host)

Mit dem Assistenten aus [Kapitel 0](00-voraussetzungen.md#schritt-2--so-legst-du-in-diesem-lab-jede-vm-an):

| Einstellung | Wert |
|---|---|
| Name | `DC01` |
| Generation | 2 |
| Arbeitsspeicher | 4096 MB, **dynamisch aus** (nur für die Installation) |
| Netzwerk | `LAB` |
| Festplatte | 60 GB |
| Installation | Windows-Server-ISO |

## Schritt 2 · Windows installieren (DC01)

1. VM starten, Leertaste drücken, sobald *„Press any key to boot from CD or DVD“* erscheint
2. Sprache und Tastatur wählen → **Jetzt installieren**
3. Image: **Windows Server 2025 Standard Evaluation (Desktop Experience)**
   Ohne *Desktop Experience* gibt es keine Oberfläche, nur eine Kommandozeile.
4. **Benutzerdefiniert** → die 60-GB-Platte → Weiter
5. Nach dem Neustart **keine** Taste drücken, sonst startet das Setup von vorn
6. Kennwort für den lokalen Administrator vergeben

## Schritt 3 · Grundeinstellungen (DC01)

Alles im **Server-Manager → Lokaler Server**:

1. **Computername** → `DC01` → Neustart
2. **Zeitzone** → *(UTC+01:00) Amsterdam, Berlin, Bern …*
   Bei englischer Installation steht hier *Pacific Time*. Das merkt man sonst erst, wenn die Uhr 9 Stunden falsch geht.
3. **Ethernet** (oder Startmenü → `ncpa.cpl`) → Rechtsklick → Eigenschaften → **Internetprotokoll Version 4** → Eigenschaften:

| | |
|---|---|
| IP-Adresse | `10.0.0.10` |
| Subnetzmaske | `255.255.255.0` |
| Standardgateway | `10.0.0.1` |
| Bevorzugter DNS-Server | `127.0.0.1` |

Test in der Eingabeaufforderung: `ping 10.0.0.1` und `ping 8.8.8.8`.

> [!WARNING]
> Bekommt DC01 trotz fester IP plötzlich eine `169.254.x.x`-Adresse (*„PING: transmit failed. General failure.“*), hat sich die Netzwerkkarte geändert und die Einstellungen sind weg. IP, Gateway und DNS einfach erneut eintragen.

## Schritt 4 · Active Directory installieren (DC01)

1. Server-Manager → **Verwalten → Rollen und Features hinzufügen**
2. *Rollenbasierte Installation* → `DC01` → Haken bei **Active Directory-Domänendienste** → *Features hinzufügen* → durchklicken → **Installieren**
3. Danach oben rechts das **gelbe Fähnchen** → **Server zu einem Domänencontroller heraufstufen**
4. **Neue Gesamtstruktur hinzufügen** → Name der Stammdomäne: `lab.test`
5. **DSRM-Kennwort** vergeben und sicher aufheben. Das brauchst du für Wiederherstellungen.
6. NetBIOS-Name `LAB` übernehmen → durchklicken → **Installieren**. Der Server startet neu.

Ab jetzt meldest du dich mit `LAB\Administrator` an.

## Schritt 5 · DNS-Weiterleitung (DC01)

Server-Manager → **Tools → DNS** → Rechtsklick auf **DC01** → Eigenschaften → Registerkarte **Weiterleitungen** → **Bearbeiten** → `8.8.8.8` (oder deinen Router) eintragen. Damit lösen die VMs auch Internet-Namen auf.

## Schritt 6 · Zeit und Autostart (Host)

1. Hyper-V-Manager → DC01 → **Einstellungen → Integrationsdienste** → Haken bei **Zeitsynchronisierung** entfernen.
   Der DC ist die Zeitquelle der Domäne und holt die Zeit später per NTP ([Kapitel 8](08-gruppenrichtlinien.md#schritt-5--zeitquelle-für-die-domäne)). Sonst überschreibt der Host die Domänenzeit.
2. **Automatische Startaktion** → *Immer automatisch starten*.

> [!IMPORTANT]
> DC01 muss immer **als Erstes** laufen. Ohne ihn gibt es kein DNS und keine Anmeldung, und alle anderen VMs laufen in Fehler. Beim Herunterfahren DC01 als Letztes.

## Prüfen

| Test | Erwartet |
|---|---|
| Server-Manager → Lokaler Server | Domäne `lab.test` |
| `nslookup lab.test` | antwortet mit `10.0.0.10` |
| `nslookup google.com` | antwortet (Weiterleitung klappt) |
| Tools → Active Directory-Benutzer und -Computer | Domäne `lab.test` ist zu sehen |

Jetzt einen **Prüfpunkt** setzen: *„DC01 Domäne fertig“*.

## Häufige Fehler

| Symptom | Ursache | Lösung |
|---|---|---|
| *„Windows Server installation has failed“* | Zu wenig RAM beim Setup | 4 GB fest, dynamisch aus |
| VM landet im PXE-Boot | Keine Taste beim DVD-Start gedrückt | VM zurücksetzen, sofort Leertaste |
| Uhr geht Stunden falsch | Zeitzone Pacific, Hyper-V-Zeitsync aktiv | Zeitzone Berlin, Zeitsync aus |
