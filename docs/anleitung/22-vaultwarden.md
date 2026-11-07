# Kapitel 22 · Vaultwarden: eigener Passwortmanager auf pve01

[← Kapitel 21](21-immich.md) · [Übersicht](../../README.md#inhaltsverzeichnis) · [Fehlerbehebung](../fehlerbehebung.md#vaultwarden-kapitel-22)

[![Linux & Docker](https://img.shields.io/badge/-Linux%20%26%20Docker-E95420?style=flat-square)](../../README.md#thema-linux) [![Proxmox](https://img.shields.io/badge/-Proxmox-E57000?style=flat-square)](../../README.md#thema-proxmox)

> **Ziel:** [Vaultwarden](https://github.com/dani-garcia/vaultwarden) ist ein schlanker, Bitwarden-kompatibler Server. Browser-Erweiterung, iPhone-App und Web-Tresor von Bitwarden sprechen direkt mit dem eigenen Server. Er läuft als kleiner Alpine-Container auf pve01 und ist mit echtem HTTPS-Zertifikat nur über Tailscale erreichbar.
> **Dauer:** ca. 45 Minuten · **Wo:** Proxmox (Browser und Shell), Tailscale-Admin-Konsole, Browser
> **Voraussetzung:** pve01 ([Kapitel 15](15-proxmox-host.md)), Tailscale im Tailnet ([Kapitel 18](18-betrieb.md)), nächtliches Proxmox-Backup aufs Pi-NAS ([Kapitel 16](16-pi-nas.md))

```text
Browser / Bitwarden-App ──Tailscale──► https://vaultwarden.<tailnet>.ts.net (Zertifikat von Tailscale)
                                           │ tailscale serve (im Container)
                                           ▼
                              LXC vaultwarden 192.168.2.24 ──► Vaultwarden :8000 (selbstsigniert)
```

| Was | Wert |
|---|---|
| Container | LXC (ID frei wählbar, bei mir `104`), Name `vaultwarden`, Alpine 3.24, 1 Kern, 256 MB RAM, 1 GB auf `vmdata`, unprivilegiert, **Protection an** |
| Netz | **Heimnetz** (`vmbr0`), feste IP `192.168.2.24` |
| Adresse | `https://vaultwarden.<tailnet>.ts.net` (nur im Tailnet) · intern `https://192.168.2.24:8000` (selbstsigniert) |
| Konfiguration | `/etc/conf.d/vaultwarden` im Container |
| Daten | im Container, gesichert durch das nächtliche Proxmox-Backup |

**Warum ein eigener Container im Heimnetz und nicht auf TOOLS01?** Kennwörter braucht man auch dann, wenn das Lab kaputt oder aus ist. Auf TOOLS01 hinge Vaultwarden an DC01 (DNS) und am Lab-Netz. Die Hauptzugänge (Proxmox, Domänen-Admin, DSRM, Vaultwarden-Master-Passwort) bleiben trotzdem zusätzlich in **KeePassXC**, denn ohne laufenden pve01 gibt es auch kein Vaultwarden.

**Warum Alpine?** Das Skript bietet Debian 13 oder Alpine an. Unter Debian baut es Vaultwarden aus dem Quellcode und will dafür 4 Kerne, 6 GB RAM und 20 GB Platte. Unter Alpine kommt Vaultwarden als fertiges Paket, 256 MB RAM reichen.

**Warum Tailscale statt Nginx Proxy Manager?** Web-Tresor und Bitwarden-Apps verlangen HTTPS mit einem Zertifikat, dem das Gerät vertraut. Der NPM auf TOOLS01 liefert für `.lab.test` kein solches Zertifikat und läuft im Lab. `tailscale serve` holt automatisch ein echtes Let's-Encrypt-Zertifikat für `*.ts.net`, ganz ohne eigene Domain und Portfreigabe. Nebeneffekt: Vaultwarden ist aus dem Internet gar nicht erreichbar, nur aus dem eigenen Tailnet.

## Schritt 1 · Container anlegen (Proxmox-Shell)

**pve01 → >_ Shell**:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/vaultwarden.sh)"
```

1. **Choose the container OS:** `alpine` tippen und Enter. Nach 10 Sekunden nimmt das Skript sonst Debian.
2. **Advanced Install**, dann die Abfragen:

   | Abfrage | Wert |
   |---|---|
   | Container Type | Unprivileged |
   | Root Password | eigenes Kennwort, in KeePassXC |
   | Container ID | z. B. `104` |
   | Hostname | `vaultwarden` |
   | Disk / CPU / RAM | Standard lassen (1 GB / 1 / 256 MB). Steht dort 20 GB / 4 / 6144, ist Debian gewählt |
   | Bridge | `vmbr0` |
   | IPv4 | static, `192.168.2.24/24`, Gateway `192.168.2.1` |
   | IPv6 | none |
   | DNS Search Domain, VLAN, MTU, MAC | leer |
   | SSH Key / Root SSH | `none` / No. Zugang über die Proxmox-Konsole bzw. `pct enter` |
   | HTTP Proxy, Mknod, Mount FS, Verbose | No / leer |
   | Container Protection | **Yes** |
   | Save as defaults | No |
   | Storage für Template / Container | `local` / `vmdata` |

3. Am Ende steht `Completed successfully!` und die Adresse `https://192.168.2.24:8000`.

**Prüfen:** `https://192.168.2.24:8000` im Browser öffnen, die Zertifikatswarnung bestätigen, die Vaultwarden-Anmeldeseite erscheint. **Noch kein Konto anlegen**, das passiert unter der endgültigen Adresse.

> [!NOTE]
> Bricht die Installation mit `apk install failed` ab, löscht das Skript den Container. Mit **Protection an** klappt das Löschen aber nicht, der kaputte Container bleibt mit derselben IP liegen. Siehe [Fehlerbehebung](../fehlerbehebung.md#vaultwarden-kapitel-22).

## Schritt 2 · Tailscale in den Container (Proxmox-Shell)

1. Auf der **pve01-Shell** (nicht im Container):

   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)"
   ```

   Den Vaultwarden-Container auswählen. Das Skript gibt dem Container `/dev/net/tun` und installiert Tailscale.
2. Container neu starten und anmelden. **Jede Zeile einzeln** eingeben und warten, bis der Prompt erscheint:

   ```bash
   pct reboot 104
   pct enter 104
   ```

   Im Container (`~ #`):

   ```bash
   tailscale up --hostname=vaultwarden --accept-dns=false
   ```

   Den angezeigten Link im Browser öffnen, anmelden, **Connect**. Die Shell dabei **nicht** mit Strg + C abbrechen, sie meldet von selbst `Success.`. Den Hinweis zu `--accept-routes` ignorieren, der Container sitzt ohnehin im Heimnetz.
3. **Tailscale-Admin-Konsole:**
   - **Machines → vaultwarden → ⋯ → Disable key expiry.** Sonst fällt der Container nach 180 Tagen aus dem Tailnet.
   - **DNS:** *MagicDNS* an, bei *HTTPS Certificates* **Enable HTTPS**.

> [!WARNING]
> Mehrere Zeilen auf einmal einfügen geht hier schief: `pct enter` braucht einen Moment, die nächste Zeile läuft dann noch **auf pve01**. Ein `tailscale up --hostname=vaultwarden` auf dem Host würde pve01 umbenennen. Bei mir hat Tailscale das zum Glück verweigert, weil pve01 Subnet-Routen freigibt und dafür alle Optionen genannt werden müssen.

## Schritt 3 · HTTPS über Tailscale (Container)

Weiter im Container:

```bash
tailscale serve --bg https+insecure://localhost:8000
```

Die Ausgabe zeigt die Adresse, z. B. `https://vaultwarden.tailXXXX.ts.net/`. `https+insecure` heißt nur: Tailscale akzeptiert intern das selbstsignierte Zertifikat von Vaultwarden. Nach außen gibt es das echte Zertifikat. Die Einstellung überlebt Neustarts.

Dann Vaultwarden die eigene Adresse mitteilen (wichtig für Passkeys/WebAuthn und Links). Jede Zeile einzeln, eigene Adresse einsetzen:

```bash
echo "export DOMAIN='https://vaultwarden.tailXXXX.ts.net'" >> /etc/conf.d/vaultwarden
rc-service vaultwarden restart
```

## Schritt 4 · Konto, Admin-Token, Registrierung sperren (Browser)

1. Am Arbeits-PC Tailscale verbinden, `https://vaultwarden.tailXXXX.ts.net` öffnen. Es kommt **keine** Zertifikatswarnung mehr. Der allererste Aufruf kann 10–20 Sekunden dauern, weil das Zertifikat erst ausgestellt wird.
2. **Create account**: E-Mail, Name, **Master-Passwort**. Ohne Master-Passwort sind die Daten verloren, auch für den Admin. Lange Passphrase, Kopie in KeePassXC.
3. **Admin-Token** setzen, im Container:

   ```bash
   update
   ```

   **1 YES (Silent Mode)** → **Reset ADMIN_TOKEN** → langes Kennwort eingeben (keine Anzeige beim Tippen). Gespeichert wird nur ein Argon2-Hash. Das Kennwort selbst in KeePassXC, nicht im Vaultwarden.
4. `https://vaultwarden.tailXXXX.ts.net/admin` → mit dem Admin-Kennwort anmelden → **General settings** → Haken bei **Allow new signups** raus → ganz unten **Save**.
5. **Zwei-Faktor:** im Tresor **Settings → Security → Two-step login → Authenticator app → Manage**, QR-Code scannen, Code eintragen, **Turn on**. Danach **View recovery code** und den Code in KeePassXC ablegen.

## Schritt 5 · Browser und Handy

- **Browser-Erweiterung** (Bitwarden): auf dem Anmeldebildschirm bei *Anmelden bei* → **Self-hosted** → Server-URL `https://vaultwarden.tailXXXX.ts.net`.
- **iPhone** (Bitwarden-App): genauso, *Self-hosted* mit derselben URL. Tailscale muss auf dem iPhone verbunden sein, zu Hause wie unterwegs.

## Sicherung

| Daten | Wo | Gesichert durch |
|---|---|---|
| Tresor (SQLite, Anhänge, Schlüssel) | im Container auf `vmdata` | nächtliches Proxmox-Backup aufs Pi-NAS |
| Master-Passwort, Admin-Kennwort, 2FA-Recovery-Code | KeePassXC | Kopie der `.kdbx` auf USB-Stick |

Der Tresor ist Ende-zu-Ende verschlüsselt, auch im Backup. Ab und zu zusätzlich **Tools → Export vault** (verschlüsselt, *Account restricted* oder mit eigenem Passwort) und die Datei getrennt ablegen.

## Updates

Im Container `update` → **1 YES** → **Update**. Tailscale kommt mit `apk upgrade` im Container.

## Prüfen

- [ ] `https://vaultwarden.<tailnet>.ts.net` öffnet ohne Zertifikatswarnung
- [ ] *Create account* auf der Anmeldeseite meldet einen Fehler (Registrierung gesperrt)
- [ ] Anmeldung verlangt den Code aus der Authenticator-App
- [ ] Browser-Erweiterung und iPhone-App zeigen denselben Tresor
- [ ] Nach `pct reboot` ist Vaultwarden unter der `ts.net`-Adresse wieder da
- [ ] In der Tailscale-Konsole steht bei *vaultwarden* „Expiry disabled“
- [ ] Das nächste Proxmox-Backup enthält den Container

## Häufige Fehler

| Problem | Ursache | Lösung |
|---|---|---|
| Skript nimmt Debian | OS-Abfrage hat 10 Sekunden Timeout | sofort `alpine` tippen |
| `apk install failed`, `Container … removed`, Container trotzdem noch da | Protection verhindert das automatische Löschen | **Options → Protection** aus, **More → Remove**, Skript neu starten |
| `update: command not found` | auf pve01 statt im Container getippt | erst `pct enter <ID>` |
| `tailscale up` meldet *requires mentioning all non-default flags* | Befehl lief auf pve01, nicht im Container | nichts geändert, im Container wiederholen |
| `context canceled` nach dem Login-Link | `tailscale up` mit Strg + C abgebrochen | neu starten, warten bis `Success.` |
| `tailscale serve` meldet, HTTPS sei nicht aktiviert | HTTPS-Zertifikate im Tailnet aus | Admin-Konsole → **DNS** → *Enable HTTPS* |
| Konto anlegen klappt unter `http://…` nicht | Web-Tresor braucht HTTPS für die Verschlüsselung im Browser | `https://` bzw. die `ts.net`-Adresse nutzen |
| App: Server nicht erreichbar | Tailscale am Gerät aus | Tailscale verbinden |

Weitere Fälle: [Fehlerbehebung](../fehlerbehebung.md#vaultwarden-kapitel-22)

Weiter: [Kapitel 23 · Proxmox-MCP](23-proxmox-mcp.md)

Wie es weitergeht: [Roadmap](../roadmap.md)
