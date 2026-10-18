# 8 · Gruppenrichtlinien

[← 7 · Dateiserver](07-dateiserver.md) · [Übersicht](../../README.md#anleitung) · weiter: [9 · Testen →](09-testen.md)

Alle GPOs werden in der **Gruppenrichtlinienverwaltung** (Server-Manager → Tools) angelegt: Rechtsklick auf die Ziel-OU → **Gruppenrichtlinienobjekt hier erstellen und verknüpfen** → Name → Rechtsklick → **Bearbeiten**.

Namensschema: `GPO-<Computer|Benutzer>-<Zweck>`, dann sieht man in der Liste sofort, wofür sie ist.

| GPO | Verknüpft mit |
|---|---|
| [GPO-Benutzer-Laufwerk-S](#laufwerk-s-pro-abteilung) | Lab/Benutzer |
| [GPO-RDP-Freigabe](#rdp-einschalten) | Lab/Computer, Lab/Server |
| [GPO-Computer-RDP](#rdp-nur-für-bestimmte-abteilungen) | Lab/Computer |
| [GPO-Computer-LAPS](#windows-laps) | Lab/Computer, Lab/Server |
| [GPO-DC-Zeitserver](#zeit-für-die-domäne) | Domain Controllers |

## Laufwerk S: pro Abteilung

**Benutzerkonfiguration → Einstellungen → Windows-Einstellungen → Laufwerkzuordnungen** → Rechtsklick → Neu → **Zugeordnetes Laufwerk**:

| Registerkarte | Einstellung |
|---|---|
| Allgemein | Aktion **Ersetzen**, Pfad `\\fs01\Abteilungen\Buchhaltung`, Bezeichnung *Buchhaltung*, Laufwerk **S:** |
| Gemeinsam | Haken bei **Zielgruppenadressierung auf Elementebene** → *Zielgruppenadressierung…* → Neues Element → **Sicherheitsgruppe** → `LAB\GG-Buchhaltung` |

Für jede Abteilung ein Eintrag. Am schnellsten: Eintrag kopieren, einfügen, Pfad **und** Zielgruppe anpassen.

![Fünf Zuordnungen für S:](../bilder/gpo-laufwerk-s.png)

> [!TIP]
> **Ersetzen** statt *Aktualisieren*: Sonst bleibt nach einem Abteilungswechsel die alte Zuordnung hängen.

> [!NOTE]
> Hat der Benutzer auf das Ziel keine NTFS-Rechte, scheitert die Zuordnung **ohne Fehlermeldung**. S: fehlt dann einfach.

## RDP einschalten

Die Gruppe *Remotedesktopbenutzer* zu füllen reicht nicht. RDP muss auch an sein, und auf Servern ist es standardmäßig aus.

**Computerkonfiguration → Richtlinien → Administrative Vorlagen → Windows-Komponenten → Remotedesktopdienste → Remotedesktop-Sitzungshost → Verbindungen** → *Benutzern die Remoteverbindung mithilfe der Remotedesktopdienste erlauben* → **Aktiviert**.

Dazu die Firewall: **Computerkonfiguration → Richtlinien → Windows-Einstellungen → Sicherheitseinstellungen → Windows Defender Firewall mit erweiterter Sicherheit → Eingehende Regeln** → Neue Regel → *Vordefiniert: Remotedesktop* → im Anschluss in den Regeleigenschaften unter **Bereich** die Remote-IP auf `10.0.0.0/24` beschränken.

## RDP nur für bestimmte Abteilungen

**Computerkonfiguration → Einstellungen → Systemsteuerungseinstellungen → Lokale Benutzer und Gruppen** → Neu → **Lokale Gruppe**:

- Gruppenname: **`Remotedesktopbenutzer (integriert)`** aus dem Dropdown wählen
- Mitglieder hinzufügen: `LAB\GG-Buchhaltung`, `LAB\GG-Vertrieb`

> [!WARNING]
> Den Gruppennamen **nicht** von Hand eintippen. Wer sich vertippt (z. B. nur `ad`), legt auf jedem Client eine neue lokale Gruppe mit diesem Namen an, statt die richtige zu befüllen.

Wer nicht in diesen Gruppen ist, bekommt beim RDP-Versuch:

![RDP verweigert](../bilder/rdp-verweigert.png)

Das ist gewollt. Über die Hyper-V-Konsole (ohne erweiterten Sitzungsmodus) kann man sich trotzdem anmelden.

Nach demselben Muster lässt sich auch ein Dienstkonto zum lokalen Admin machen: Gruppe **`Administratoren (integriert)`**.

## Windows LAPS

Jeder Rechner bekommt ein eigenes, zufälliges Kennwort für den lokalen Administrator, gespeichert im AD.

Einmalig auf DC01 (PowerShell als Admin):

```powershell
Update-LapsADSchema
Set-LapsADComputerSelfPermission -Identity "OU=Computer,OU=Lab,DC=lab,DC=test"
Set-LapsADComputerSelfPermission -Identity "OU=Server,OU=Lab,DC=lab,DC=test"
```

GPO: **Computerkonfiguration → Richtlinien → Administrative Vorlagen → System → LAPS**:
- *Kennwortsicherungsverzeichnis konfigurieren* → **Aktiviert**, Active Directory
- optional *Kennworteinstellungen* (Länge, Alter)

Und: **Sicherheitseinstellungen → Lokale Richtlinien → Sicherheitsoptionen → Konten: Status des Administratorkontos** → **Aktiviert**. Unter Windows 11 ist das eingebaute Admin-Konto sonst deaktiviert, LAPS setzt nur das Kennwort.

Kennwort nachschauen: ADUC → Computerkonto → Eigenschaften → Registerkarte **LAPS**. Anmelden mit `.\Administrator`.

## Zeit für die Domäne

GPO an der OU **Domain Controllers**: **Computerkonfiguration → Richtlinien → Administrative Vorlagen → System → Windows-Zeitdienst → Zeitanbieter**:

- *Windows-NTP-Client konfigurieren* → Aktiviert, NtpServer `de.pool.ntp.org,0x8`, Typ `NTP`
- *Windows-NTP-Client aktivieren* → Aktiviert

Alle anderen Rechner holen die Zeit automatisch vom DC. Prüfen auf DC01: `w32tm /query /status`.

## GPOs sichern

Gruppenrichtlinienverwaltung → **Gruppenrichtlinienobjekte** → Rechtsklick → **Alle sichern…** → Ordner mit Datum. Vor jedem größeren Umbau.
