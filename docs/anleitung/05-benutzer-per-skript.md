# 5 · Testbenutzer per Skript

[← 4 · AD-Struktur](04-ad-struktur.md) · [Übersicht](../../README.md#anleitung) · weiter: [6 · Client →](06-client.md)

Ein paar Benutzer legt man per Hand an. Für realistische Tests (Rechte, GPOs, Laufwerke) braucht man aber mehr. Das Skript [`New-LabBulkUsers.ps1`](../../scripts/New-LabBulkUsers.ps1) legt sie aus einer CSV an.

## Was das Skript macht

- Benutzer landen in `Lab/Benutzer/<Abteilung>`
- Fehlende Abteilungs-OUs und Gruppen `GG-<Abteilung>` werden angelegt
- Jeder Benutzer kommt in seine Abteilungsgruppe
- Das Startkennwort wird beim Start **abgefragt**, es steht nicht in der CSV
- Alle bekommen die Beschreibung *Bulk-Import Testbenutzer*, so findet man sie später wieder
- Vorhandene Benutzer werden übersprungen, das Skript darf also mehrfach laufen
- `-WhatIf` zeigt nur an, was passieren würde

## CSV vorbereiten

Trennzeichen Semikolon (passt zu Excel mit deutschen Einstellungen), Datei als `benutzer.csv` neben das Skript legen. Vorlage: [`benutzer.example.csv`](../../scripts/benutzer.example.csv)

```
Vorname;Nachname;Benutzername;Abteilung
Anna;Beispiel;abeispiel;Buchhaltung
Ben;Muster;bmuster;Vertrieb
```

## Ausführen

1. Skript und CSV nach DC01 kopieren, z. B. `C:\Skripte`
2. Heruntergeladene Dateien entsperren: Rechtsklick → Eigenschaften → Registerkarte **Allgemein** → unten Haken bei **Zulassen**
   Sonst kommt *„… is not digitally signed“*.
3. PowerShell **als Administrator**:

```powershell
cd C:\Skripte
.\New-LabBulkUsers.ps1 -WhatIf     # Probelauf
.\New-LabBulkUsers.ps1             # echter Lauf, fragt nach dem Startkennwort
```

![Probelauf mit -WhatIf](../bilder/skript-whatif.png)

> [!IMPORTANT]
> Das Startkennwort muss zur Kennwortrichtlinie der Domäne passen (Standard: 7 Zeichen und Komplexität; in diesem Lab 12 Zeichen). Sonst schlägt jeder einzelne Benutzer fehl.

## Prüfen

- ADUC → `Lab/Benutzer` → F5: die Abteilungs-OUs mit Benutzern
- Gruppe öffnen → Registerkarte **Mitglieder**
- Log unter `C:\Temp\LabBulkUsers.log`

## Wieder entfernen

ADUC → Rechtsklick auf `lab.test` → **Suchen** → Registerkarte *Erweitert* → Feld *Beschreibung* ist genau `Bulk-Import Testbenutzer`. Die Abteilungs-OUs sind gegen versehentliches Löschen geschützt: **Ansicht → Erweiterte Features**, dann OU → Eigenschaften → Registerkarte *Objekt* → Haken entfernen.
