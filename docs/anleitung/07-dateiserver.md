# Kapitel 7 · Dateiserver FS01

[← Kapitel 6](06-client.md) · [Übersicht](../../README.md#anleitung) · weiter: [Kapitel 8 · Gruppenrichtlinien →](08-gruppenrichtlinien.md)

> **Ziel:** Eine Freigabe `\\fs01\Abteilungen` mit einem Ordner pro Abteilung. Jeder sieht und bearbeitet nur seinen eigenen.
> **Dauer:** ca. 60 Minuten · **Wo:** Host, danach FS01

## Schritt 1 · VM mit zweiter Platte (Host)

1. VM `FS01` anlegen wie DC01 ([Kapitel 2](02-domain-controller.md)), Systemplatte 60 GB
2. Rechtsklick → **Einstellungen → SCSI-Controller → Festplatte → Hinzufügen → Neu** → VHDX, dynamisch erweiterbar, Name `FS01-Daten.vhdx`, **50 GB**

<img src="../bilder/hyperv-fs01-datenplatte.png" width="520" alt="Zweite Platte am SCSI-Controller">

> [!WARNING]
> Bei der Windows-Installation die **60-GB**-Platte als Ziel wählen, die 50-GB-Platte nicht anfassen.

## Schritt 2 · Grundeinrichtung (FS01)

1. Zeitzone Berlin, Name `FS01`
2. Feste IP: `10.0.0.40`, Maske `255.255.255.0`, Gateway `10.0.0.1`, DNS `10.0.0.10`
3. Test: `ping dc01.lab.test`
4. `sysdm.cpl` → Domäne `lab.test` beitreten → Neustart
5. Auf DC01 in ADUC das Computerkonto von *Computers* nach **`Lab/Server`** verschieben

## Schritt 3 · Datenplatte einrichten (FS01)

1. Rechtsklick auf Start → **Datenträgerverwaltung**
2. Die neue Platte ist *Offline*: Rechtsklick → **Online**, dann **Datenträgerinitialisierung** → GPT
3. Rechtsklick auf den freien Bereich → **Neues einfaches Volume** → Laufwerksbuchstabe **E:**, NTFS, Bezeichnung `Daten`

<p align="center">
  <img src="../bilder/fs01-datentraegerverwaltung.png" width="54%" alt="Datenträgerverwaltung">
  <img src="../bilder/fs01-laufwerk-e.png" width="44%" alt="Laufwerk E: Daten">
</p>

## Schritt 4 · Ordner anlegen (FS01)

Im Explorer:

```
E:\Shares\Abteilungen\
├── Buchhaltung
├── Vertrieb
├── IT
├── Personal
└── Leitung
```

## Schritt 5 · Freigabe erstellen (FS01)

Server-Manager → **Datei-/Speicherdienste → Freigaben** → *Aufgaben* → **Neue Freigabe** → **SMB-Freigabe – Schnell**:

| Seite | Einstellung |
|---|---|
| Freigabepfad | *Benutzerdefinierten Pfad eingeben* → `E:\Shares\Abteilungen` |
| Freigabename | `Abteilungen` |
| Andere Einstellungen | Haken bei **Zugriffsbasierte Aufzählung aktivieren** |
| Berechtigungen | *Berechtigungen anpassen* → Registerkarte **Freigabe** → *Authenticated Users* mit **Vollzugriff** |

> [!TIP]
> Freigaberecht großzügig, NTFS streng. Gesteuert wird nur über NTFS, dann suchst du bei Problemen nur an einer Stelle.

## Schritt 6 · NTFS-Rechte pro Abteilungsordner (FS01)

Für **jeden** Abteilungsordner: Rechtsklick → Eigenschaften → **Sicherheit** → **Erweitert**:

1. **Vererbung deaktivieren** → *Vererbte Berechtigungen in explizite Berechtigungen umwandeln*
2. Alles **entfernen**, was nicht in die Tabelle gehört (z. B. *Benutzer* / *Users*)
3. **Hinzufügen** → *Prinzipal auswählen* → `GG-<Abteilung>` → Namen überprüfen → OK

Ziel pro Ordner:

| Prinzipal | Zugriff | Anwenden auf |
|---|---|---|
| Administratoren | Vollzugriff | Diesen Ordner, Unterordner und Dateien |
| SYSTEM | Vollzugriff | Diesen Ordner, Unterordner und Dateien |
| ERSTELLER-BESITZER | Vollzugriff | Nur Unterordner und Dateien |
| GG-&lt;Abteilung&gt; | **Ändern** | **Diesen Ordner, Unterordner und Dateien** |

> [!WARNING]
> **Häufigster Fehler:** Bei der Gruppe steht *Nur dieser Ordner* (*This folder only*). Dann kann jeder nur seine **eigenen** Dateien öffnen (über ERSTELLER-BESITZER), die Kollegen bekommen *„Zugriff verweigert“*. Mit nur einem Testbenutzer pro Abteilung fällt das nicht auf.
>
> <img src="../bilder/ntfs-abteilungsordner.png" width="560" alt="Falsch: Recht gilt nur für diesen Ordner">

> [!WARNING]
> Bei fünf Ordnern hintereinander vertauscht man schnell die Gruppen. Danach also mit einem Benutzer **jeder** Abteilung testen ([Kapitel 9](09-testen.md)).

## Prüfen

Auf CLIENT01 als Benutzer der Buchhaltung `\\fs01\Abteilungen` öffnen:

- Durch die zugriffsbasierte Aufzählung ist **nur** der Ordner *Buchhaltung* zu sehen
- Darin lassen sich Dateien anlegen, ändern und löschen
- Eine Datei, die ein Kollege angelegt hat, lässt sich öffnen und speichern
