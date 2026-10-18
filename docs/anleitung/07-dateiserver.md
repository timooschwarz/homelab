# 7 · Dateiserver FS01

[← 6 · Client](06-client.md) · [Übersicht](../../README.md#anleitung) · weiter: [8 · Gruppenrichtlinien →](08-gruppenrichtlinien.md)

Ziel: eine Freigabe `\\fs01\Abteilungen` mit einem Ordner pro Abteilung. Jeder sieht und bearbeitet nur seinen eigenen.

## Server vorbereiten

1. VM `FS01` wie DC01 anlegen (Kapitel 2), feste IP `10.0.0.40`, DNS `10.0.0.10`
2. Zweite virtuelle Festplatte (50 GB) für Daten hinzufügen
3. **Datenträgerverwaltung** → neue Platte online schalten → initialisieren (GPT) → Volume **E:** „Daten“
4. Der Domäne beitreten, Computerkonto nach `Lab/Server` verschieben

## Ordner anlegen

```
E:\Shares\Abteilungen\
├── Buchhaltung
├── Vertrieb
├── IT
├── Personal
└── Leitung
```

## Freigabe

Server-Manager → **Datei-/Speicherdienste → Freigaben** → Aufgaben → **Neue Freigabe** → *SMB-Freigabe – Schnell*:

| Schritt | Einstellung |
|---|---|
| Pfad | `E:\Shares\Abteilungen` |
| Name | `Abteilungen` |
| Weitere Einstellungen | Haken bei **Zugriffsbasierte Aufzählung aktivieren** |
| Berechtigungen | Freigabe: *Authenticated Users* **Vollzugriff** |

> [!TIP]
> Freigaberecht großzügig, NTFS streng. Gesteuert wird nur über NTFS, dann muss man nur an einer Stelle suchen.

## NTFS-Rechte pro Abteilungsordner

Rechtsklick auf den Ordner → Eigenschaften → **Sicherheit** → **Erweitert**:

1. **Vererbung deaktivieren** → *Vererbte Berechtigungen in explizite umwandeln*
2. Alles entfernen, was nicht in die Tabelle gehört (z. B. *Benutzer*)
3. **Hinzufügen** → Prinzipal auswählen → `GG-<Abteilung>` → Berechtigungen siehe Tabelle

| Prinzipal | Recht | Gilt für |
|---|---|---|
| Administratoren | Vollzugriff | Diesen Ordner, Unterordner und Dateien |
| SYSTEM | Vollzugriff | Diesen Ordner, Unterordner und Dateien |
| ERSTELLER-BESITZER | Vollzugriff | Nur Unterordner und Dateien |
| GG-&lt;Abteilung&gt; | **Ändern** | **Diesen Ordner, Unterordner und Dateien** |

> [!WARNING]
> Steht bei der Gruppe *Nur dieser Ordner* (*This folder only*), kann jeder nur seine **eigenen** Dateien öffnen. Die Kollegen bekommen „Zugriff verweigert“. Mit nur einem Testbenutzer pro Abteilung fällt das nicht auf.
>
> ![Falsch: Recht gilt nur für diesen Ordner](../bilder/ntfs-abteilungsordner.png)

> [!WARNING]
> Bei vielen Ordnern hintereinander passiert es schnell, dass man die Gruppen vertauscht. Danach also immer mit einem Benutzer **jeder** Abteilung testen (Kapitel 9).

## Prüfen

Als Benutzer der Buchhaltung `\\fs01\Abteilungen` öffnen: Dank zugriffsbasierter Aufzählung ist **nur** der Ordner Buchhaltung zu sehen, darin kann er Dateien anlegen und ändern.
