# 9 · Testen

[← 8 · Gruppenrichtlinien](08-gruppenrichtlinien.md) · [Übersicht](../../README.md#anleitung) · weiter: [10 · Linux-Dienste →](10-linux-dienste.md)

Erst wenn ein Benutzer **jeder** Abteilung getestet ist, ist es fertig. Die meisten Fehler in diesem Lab sind erst beim Testen mit mehreren Konten aufgefallen.

## Werkzeuge

| Befehl | Wofür |
|---|---|
| `gpupdate /force` | GPOs sofort neu holen |
| `gpresult /r` | Welche GPOs angewendet wurden, in welchen Gruppen der Benutzer ist |
| `whoami /groups` | Gruppen des angemeldeten Benutzers |
| `net use` | Verbundene Laufwerke |

Neue Gruppenmitgliedschaften gelten erst nach **Ab- und Anmelden**.

![gpresult: GPO angewendet, Benutzer in GG-Personal](../bilder/gpresult.png)

## Testplan

| Test | Erwartet |
|---|---|
| Anmelden als Benutzer der Abteilung X | S: zeigt auf `\\fs01\Abteilungen\X` |
| `\\fs01\Abteilungen` öffnen | Nur Ordner X sichtbar |
| Datei in S: anlegen | klappt |
| Datei eines Kollegen aus X öffnen und speichern | klappt |
| RDP auf CLIENT01 als Buchhaltung/Vertrieb | klappt |
| RDP auf CLIENT01 als andere Abteilung | wird verweigert |
| `.\Administrator` mit LAPS-Kennwort | klappt |

![Laufwerk S: beim Benutzer](../bilder/laufwerk-s-client.png)

## Wenn S: fehlt

1. `gpresult /r`: Ist die GPO angewendet? Ist der Benutzer in der richtigen GG-Gruppe?
2. `\\fs01\Abteilungen` öffnen: Welche Ordner sieht er? Durch die zugriffsbasierte Aufzählung zeigt das direkt, worauf er NTFS-Rechte hat.
3. Läuft FS01?
4. Ist der Benutzer in **zwei** Abteilungsgruppen? Dann gewinnt die letzte Zuordnung.

Mehr Fälle: [Fehlerbehebung](../fehlerbehebung.md)
