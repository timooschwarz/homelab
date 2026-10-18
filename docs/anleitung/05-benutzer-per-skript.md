# Kapitel 5 · Testbenutzer per Skript

[← Kapitel 4](04-ad-struktur.md) · [Übersicht](../../README.md#anleitung) · weiter: [Kapitel 6 · Client →](06-client.md)

> **Ziel:** Über 100 realistische Testbenutzer in Abteilungs-OUs, jeweils in der richtigen Gruppe.
> **Dauer:** ca. 15 Minuten · **Wo:** DC01

Ein paar Benutzer legt man per Hand an. Für realistische Tests von Rechten, GPOs und Laufwerken braucht man aber mehr, und 100 Benutzer klickt niemand. Dafür gibt es [`New-LabBulkUsers.ps1`](../../scripts/New-LabBulkUsers.ps1).

## Was das Skript macht

- Legt Benutzer in `Lab/Benutzer/<Abteilung>` an
- Legt fehlende Abteilungs-OUs und Gruppen `GG-<Abteilung>` selbst an
- Nimmt jeden Benutzer in seine Abteilungsgruppe auf
- Fragt das Startkennwort beim Start ab, es steht **nicht** in der CSV
- Gibt allen die Beschreibung *Bulk-Import Testbenutzer*, damit man sie später wiederfindet
- Überspringt vorhandene Benutzer, kann also mehrfach laufen
- Mit `-WhatIf` zeigt es nur an, was passieren würde

## Schritt 1 · CSV vorbereiten

Trennzeichen Semikolon, Datei als `benutzer.csv` neben das Skript legen. Vorlage: [`benutzer.example.csv`](../../scripts/benutzer.example.csv)

```
Vorname;Nachname;Benutzername;Abteilung
Anna;Beispiel;abeispiel;Buchhaltung
Ben;Muster;bmuster;Vertrieb
```

Der Benutzername darf höchstens 20 Zeichen lang sein.

## Schritt 2 · Dateien auf DC01 bringen und entsperren

1. Skript und CSV nach DC01 kopieren, z. B. nach `C:\Skripte`
2. Heruntergeladene Dateien sind von Windows markiert. Rechtsklick auf die `.ps1` → **Eigenschaften** → Registerkarte **Allgemein** → ganz unten Haken bei **Zulassen** → OK. Dasselbe für die CSV.

> [!NOTE]
> Ohne Entsperren kommt *„… is not digitally signed. You cannot run this script on the current system.“* Bei englischem Windows heißt der Haken **Unblock**, und er steht auf **General**, nicht auf *Security*.

## Schritt 3 · Probelauf

PowerShell **als Administrator** öffnen:

```powershell
cd C:\Skripte
.\New-LabBulkUsers.ps1 -WhatIf
```

Das Skript listet jeden Benutzer mit Ziel-OU und Gruppe auf, ändert aber nichts:

![Probelauf mit -WhatIf](../bilder/skript-whatif.png)

## Schritt 4 · Echter Lauf

```powershell
.\New-LabBulkUsers.ps1
```

Startkennwort eingeben. Am Ende steht z. B. *„114 angelegt, 0 übersprungen, 0 Fehler“*.

> [!IMPORTANT]
> Das Startkennwort muss zur Kennwortrichtlinie der Domäne passen. Standard sind 7 Zeichen mit Komplexität, in diesem Lab sind es 12 Zeichen. Sonst scheitert jeder einzelne Benutzer.

Optional: `-PasswortBeiAnmeldungAendern`, dann müssen die Benutzer das Kennwort bei der ersten Anmeldung ändern.

## Prüfen

- ADUC → `Lab/Benutzer` → **F5**: Abteilungs-OUs mit Benutzern
- Gruppe öffnen → Registerkarte **Mitglieder**
- Log: `C:\Temp\LabBulkUsers.log`

## Wieder aufräumen

ADUC → Rechtsklick auf `lab.test` → **Suchen** → Registerkarte *Erweitert* → Feld **Beschreibung** *ist genau* `Bulk-Import Testbenutzer`. Die Abteilungs-OUs sind gegen versehentliches Löschen geschützt: **Ansicht → Erweiterte Features**, dann OU → Eigenschaften → Registerkarte **Objekt** → Haken entfernen.
