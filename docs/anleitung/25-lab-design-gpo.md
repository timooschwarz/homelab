# Kapitel 25 · Lab-Design per GPO: Hintergrund, Kontobild, Dark Mode und Sperrbildschirm je Computer

[← Kapitel 24](24-zertifikate-tailscale.md) · [Übersicht](../../README.md#inhaltsverzeichnis) · [Fehlerbehebung](../fehlerbehebung.md#lab-design-kapitel-25)

[![Gruppenrichtlinien](https://img.shields.io/badge/-Gruppenrichtlinien-7F77DD?style=flat-square)](../../README.md#thema-gpo) [![Windows 11](https://img.shields.io/badge/-Windows%2011-0078D4?style=flat-square)](../../README.md#thema-client) [![PowerShell](https://img.shields.io/badge/-PowerShell-5391FE?style=flat-square)](../../README.md#thema-ps)

> **Ziel:** Jeder Rechner im Lab zeigt sein eigenes Hintergrundbild und sein eigenes Kontobild, dazu Dark Mode und denselben Sperrbildschirm. Alles kommt aus einer einzigen GPO. Wer per RDP auf mehreren Maschinen gleichzeitig arbeitet, sieht sofort, wo er gerade ist.
> **Dauer:** ca. 45 Minuten · **Wo:** DC01, zum Testen ein Client
> **Voraussetzung:** OU-Struktur ([Kapitel 4](04-ad-struktur.md)), Umgang mit GPOs ([Kapitel 8](08-gruppenrichtlinien.md))
> **Menüs:** Englisch

```text
\\lab.test\NETLOGON\Hintergrund\
  wallpaper.jpg                      allgemeines Bild für alle
  CLIENT02\wallpaper.jpg             eigenes Bild für CLIENT02
  CLIENT02\Kontobild\user*.png       eigenes Kontobild für CLIENT02
  DC01\…                             und so weiter, ein Ordner je Computername
        │
        │  GPO-Computer-Design: Files-Preference mit %ComputerName% in der Quelle
        ▼
C:\Windows\Web\Wallpaper\lab-wallpaper.jpg            Desktop und Sperrbildschirm zeigen auf diese eine Datei
C:\ProgramData\Microsoft\User Account Pictures\       Standard-Kontobild von Windows
```

**Die Idee:** Die GPO sagt auf jedem Rechner dasselbe, nämlich „nimm `lab-wallpaper.jpg`“. Welches Bild unter diesem Namen liegt, entscheidet eine Files-Preference, deren Quelle die Variable `%ComputerName%` enthält. Jeder Rechner setzt dort seinen eigenen Namen ein und holt sich das Bild aus seinem Ordner. Dafür braucht es keine zweite GPO, keine Sicherheitsfilterung und keinen WMI-Filter.

**Warum erst lokal kopieren?** Die Richtlinie für den Hintergrund zeigt auf eine lokale Datei, nicht auf die Freigabe. So ist das Bild auch dann da, wenn das Netz bei der Anmeldung noch nicht steht.

| Was | Wert |
|---|---|
| GPO | `GPO-Computer-Design` |
| Verknüpft mit | `Lab/Computer`, `Lab/Server`, `Domain Controllers` |
| Quelle der Bilder | `\\lab.test\NETLOGON\Hintergrund\` |
| Hintergrund lokal | `C:\Windows\Web\Wallpaper\lab-wallpaper.jpg` |
| Kontobilder lokal | `C:\ProgramData\Microsoft\User Account Pictures` |
| Skript | [`scripts/lab-design/Deploy-LabTheme.ps1`](../../scripts/lab-design/Deploy-LabTheme.ps1) |

## Schritt 1 · Grund-GPO: ein Bild für alle (DC01)

Diesen Teil gab es bei mir schon länger. Er ist die Grundlage für alles Weitere.

1. Ein Bild als **echtes JPEG** nach `\\lab.test\NETLOGON\Hintergrund\wallpaper.jpg` legen.
2. **Group Policy Management** → GPO `GPO-Computer-Design` anlegen und mit `Lab/Computer` verknüpfen → **Edit**.
3. **Computer Configuration → Preferences → Windows Settings → Files → New → File:**
   - Source file(s): `\\lab.test\NETLOGON\Hintergrund\wallpaper.jpg`
   - Destination File: `C:\Windows\Web\Wallpaper\lab-wallpaper.jpg`
4. **User Configuration → Policies → Administrative Templates → Desktop → Desktop → Desktop Wallpaper:** **Enabled**, Wallpaper Name `C:\Windows\Web\Wallpaper\lab-wallpaper.jpg`, Wallpaper Style **Fill**.
5. **Computer Configuration → Policies → Administrative Templates → System → Group Policy → Configure user Group Policy loopback processing mode:** **Enabled**, Mode **Merge**.

> [!NOTE]
> **Warum Loopback?** Die GPO hängt an der OU der Computer, der Hintergrund ist aber eine Benutzereinstellung. Ohne Loopback bekäme sie niemand, weil die Benutzer in einer anderen OU liegen. Mit *Merge* gelten die Benutzereinstellungen dieser GPO für jeden, der sich an einem Computer aus der OU anmeldet.

## Schritt 2 · Bilder je Computer vorbereiten (DC01)

Pro Rechner ein Ordner, der genauso heißt wie der Computer:

```text
Hintergrund\
  CLIENT02\
    wallpaper.jpg          Hintergrund, bei mir 2560×1440
    Kontobild\
      user.png             448×448
      user.bmp             448×448
      user-192.png         192×192
      user-48.png          48×48
      user-40.png          40×40
      user-32.png          32×32
```

Die sechs Dateien im Ordner `Kontobild` heißen so wie die Standardbilder von Windows. Sie ersetzen diese später eins zu eins.

Das Skript [`Deploy-LabTheme.ps1`](../../scripts/lab-design/Deploy-LabTheme.ps1) prüft die Bilder, kopiert die Ordner nach NETLOGON und schaltet die Richtlinie für das Kontobild aus Schritt 4 ein. In einer PowerShell **als Administrator** auf DC01:

```powershell
# erst nur anzeigen, was passieren würde
powershell -ExecutionPolicy Bypass -File "C:\Pfad\Deploy-LabTheme.ps1" -Source "C:\Pfad\Hintergrund" -WhatIf

# dann wirklich
powershell -ExecutionPolicy Bypass -File "C:\Pfad\Deploy-LabTheme.ps1" -Source "C:\Pfad\Hintergrund"
```

Immer den vollen Pfad angeben und `-Source` mitgeben, so lief es bei mir. Wer lieber von Hand kopiert, legt die Ordner selbst unter `\\lab.test\NETLOGON\Hintergrund\` ab und setzt die Richtlinie aus Schritt 4 per Klick.

## Schritt 3 · Zwei Files-Einträge mit `%ComputerName%` (DC01)

In derselben GPO unter **Computer Configuration → Preferences → Windows Settings → Files**, jeweils **New → File** mit Action **Replace**:

| Eintrag | Source file(s) | Destination |
|---|---|---|
| Hintergrund | `\\lab.test\NETLOGON\Hintergrund\%ComputerName%\wallpaper.jpg` | File: `C:\Windows\Web\Wallpaper\lab-wallpaper.jpg` |
| Kontobilder | `\\lab.test\NETLOGON\Hintergrund\%ComputerName%\Kontobild\*.*` | Folder: `C:\ProgramData\Microsoft\User Account Pictures` |

Beide Einträge müssen **unter** dem allgemeinen Eintrag aus Schritt 1 stehen (Spalte *Order*). So wird erst das allgemeine Bild kopiert und danach vom eigenen überschrieben. Ein Rechner ohne eigenen Ordner soll so beim allgemeinen Bild bleiben. Diesen Fall habe ich nicht eigens getestet.

> [!IMPORTANT]
> Den Pfad **eintippen**, nicht über den Knopf mit den drei Punkten auswählen. Der Dialog trägt sonst einen lokalen Pfad von DC01 ein, und auf den Clients passiert nichts. Mit **F3** zeigt das Feld alle Variablen, die Group Policy Preferences kennt.

## Schritt 4 · Ein Kontobild für alle Konten (DC01)

**Computer Configuration → Policies → Administrative Templates → Control Panel → User Accounts → Apply the default account picture to all users:** **Enabled**.

Damit zeigt Windows bei jedem Konto das Standardbild, und das ist nach Schritt 3 das Bild der Maschine. Das Skript aus Schritt 2 setzt die Richtlinie bereits.

## Schritt 5 · Dark Mode erzwingen (DC01)

**User Configuration → Preferences → Windows Settings → Registry → New → Registry Item**, zweimal:

| Feld | Wert |
|---|---|
| Action | Update |
| Hive | `HKEY_CURRENT_USER` |
| Key Path | `Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` |
| Value name | `AppsUseLightTheme` beziehungsweise `SystemUsesLightTheme` |
| Value type | `REG_DWORD` |
| Value data | `0` |

> [!IMPORTANT]
> Die beiden Einträge gehören in den Zweig **User Configuration**. Unter *Computer Configuration* zeigt die Spalte *Hive* zwar auch `HKEY_CURRENT_USER`, dahinter steht aber `HKU\.DEFAULT`, und beim angemeldeten Benutzer kommt nichts an.

## Schritt 6 · Sperrbildschirm unter Windows 11 Pro (DC01)

Die passende Richtlinie *Force a specific default lock screen and logon image* gilt laut Microsoft nur für Enterprise, Education und Server, nicht für Windows 11 Pro. Auf Pro lässt sich der Sperrbildschirm über drei Registry-Werte setzen. Das ist kein offiziell unterstützter Weg und kann je nach Build ohne Wirkung bleiben. Auf CLIENT02 (Windows 11 Pro) hat es am 15.11.2026 funktioniert.

**Computer Configuration → Preferences → Windows Settings → Registry → New → Registry Item**, dreimal, jeweils Action **Update**, Hive `HKEY_LOCAL_MACHINE`, Key Path `SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP`:

| Value name | Value type | Value data |
|---|---|---|
| `LockScreenImagePath` | `REG_SZ` | `C:\Windows\Web\Wallpaper\lab-wallpaper.jpg` |
| `LockScreenImageUrl` | `REG_SZ` | `C:\Windows\Web\Wallpaper\lab-wallpaper.jpg` |
| `LockScreenImageStatus` | `REG_DWORD` | `1` |

Den Key Path eintippen. Auf DC01 gibt es den Schlüssel noch nicht, deshalb findet ihn die Suche im Dialog nicht. Weil alle Rechner dieselbe lokale Datei verwenden, bekommt jeder automatisch sein eigenes Motiv auch als Sperrbildschirm.

## Schritt 7 · Server und Domain Controller mitnehmen (DC01)

1. Für jeden Server einen Ordner mit seinem Namen anlegen, bei mir `DC01`, `FS01` und `CM01`, und wie in Schritt 2 nach NETLOGON kopieren.
2. In **Group Policy Management** die GPO zusätzlich mit `Lab/Server` und `Domain Controllers` verknüpfen: Rechtsklick auf die OU → **Link an Existing GPO…** → `GPO-Computer-Design`.

Mit der Verknüpfung kommt alles aus der GPO mit, auch Loopback und Dark Mode.

## Prüfen

Auf dem Client `gpupdate /force` ausführen, neu starten und anmelden.

- [ ] Der Anmeldebildschirm zeigt das Kontobild der Maschine
- [ ] Der Desktop zeigt das eigene Hintergrundbild
- [ ] Explorer und Einstellungen sind dunkel
- [ ] Nach Windows-Taste + L liegt dasselbe Bild hinter der Anmeldung
- [ ] `C:\Windows\Web\Wallpaper\lab-wallpaper.jpg` ist auf zwei Rechnern verschieden

## Stand bei mir

| Rechner | Hintergrund | Kontobild | Dark Mode | Sperrbildschirm |
|---|---|---|---|---|
| CLIENT02 (Windows 11 Pro) | ja | ja | ja | ja |
| DC01, CM01 (Windows Server 2025) | ja | erscheint nicht, siehe unten | ja | nicht geprüft |
| FS01 (Windows Server 2025) | nicht geprüft | nicht geprüft | nicht geprüft | nicht geprüft |

**Offen:** Auf DC01 liegt das richtige Bild in `C:\ProgramData\Microsoft\User Account Pictures`, beim Admin-Konto erscheint es unter **Settings → Accounts** trotzdem nicht. Auf CM01 fehlt es dort genauso. Neustart, Ab- und Anmelden und das Ausschalten der Richtlinie aus Schritt 4 haben nichts geändert. Die Ursache ist noch nicht gefunden.

## Häufige Fehler

| Problem | Ursache | Lösung |
|---|---|---|
| Trotz `gpupdate` und Abmelden bleibt das alte Bild | Quelle im Files-Eintrag über den Dialog gewählt, eingetragen ist ein lokaler Pfad von DC01 | UNC-Pfad mit `%ComputerName%` eintippen (Schritt 3) |
| Dark Mode greift nicht | Registry-Einträge liegen unter *Computer Configuration*, Hive zeigt `HKEY_CURRENT_USER (HKU\.DEFAULT)` | Unter *User Configuration* neu anlegen (Schritt 5) |
| Skript: *Cannot bind argument to parameter 'Path' because it is an empty string* | Windows PowerShell 5.1 kennt `$PSScriptRoot` in den Vorgabewerten von `param()` nicht, wenn das Skript mit `-File` läuft | `-Source "<Pfad>\Hintergrund"` mitgeben. Im Skript ist das inzwischen abgefangen |
| Skript: Datei nicht gefunden | PowerShell als Administrator startet in `C:\Windows\System32`, `.\Deploy-LabTheme.ps1` zeigt ins Leere | Vollen Pfad angeben |
| Hintergrund bleibt schwarz | Datei heißt in Wirklichkeit `wallpaper.jpg.png` | Echtes JPEG speichern, siehe [Fehlerbehebung](../fehlerbehebung.md#gpo-hintergrundbild-bleibt-schwarz) |

Weitere Fälle: [Fehlerbehebung](../fehlerbehebung.md#lab-design-kapitel-25)

Wie es weitergeht: [Roadmap](../roadmap.md)
