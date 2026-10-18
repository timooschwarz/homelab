# 6 · Windows-11-Client CLIENT01

[← 5 · Benutzer per Skript](05-benutzer-per-skript.md) · [Übersicht](../../README.md#anleitung) · weiter: [7 · Dateiserver →](07-dateiserver.md)

## VM anlegen

| Einstellung | Wert |
|---|---|
| Name | `CLIENT01` |
| Generation | 2, **TPM aktivieren** (Einstellungen → Sicherheit), sonst verweigert Windows 11 die Installation |
| RAM | 4096 MB |
| Netzwerk | `LAB` |
| Festplatte | 64 GB |

Windows 11 **Pro** oder **Enterprise** installieren (Home kann keiner Domäne beitreten). Beim Einrichten ein lokales Konto anlegen.

## IP prüfen

Eingabeaufforderung → `ipconfig /all`. Erwartet:
- IP aus `10.0.0.100 – 200`
- Gateway `10.0.0.1`
- DNS `10.0.0.10`

Bekommt der Client nur `169.254.x.x`, läuft DHCP auf DC01 nicht oder ist nicht autorisiert.

## Domäne beitreten

1. Einstellungen → **System → Info** → **Domäne oder Arbeitsgruppe**
2. **Ändern…** → Computername `CLIENT01`, Mitglied von **Domäne** `lab.test`
3. Mit einem Domänen-Admin bestätigen → Neustart

Danach **Anderer Benutzer** → Anmeldung mit einem Domänenkonto. Unter dem Kennwortfeld steht *Anmelden bei: LAB*, man muss also nicht `LAB\` davorschreiben.

## Prüfen

ADUC → `Lab/Computer` → `CLIENT01` ist da (dank `redircmp` aus [Kapitel 4](04-ad-struktur.md#neue-computer-automatisch-in-die-richtige-ou)).
