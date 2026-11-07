# Kapitel 24 · Echte Zertifikate für pve01 und NetBox über Tailscale

[← Kapitel 23](23-proxmox-mcp.md) · [Übersicht](../../README.md#inhaltsverzeichnis) · [Fehlerbehebung](../fehlerbehebung.md#zertifikate-kapitel-24)

[![Proxmox](https://img.shields.io/badge/-Proxmox-E57000?style=flat-square)](../../README.md#thema-proxmox) [![Netzwerk](https://img.shields.io/badge/-Netzwerk-1D9E75?style=flat-square)](../../README.md#thema-netz) [![Sicherheit](https://img.shields.io/badge/-Sicherheit-EF9F27?style=flat-square)](../../README.md#thema-sec)

> **Ziel:** Proxmox und NetBox ohne Zertifikatswarnung öffnen, auf jedem Gerät im Tailnet. Wie bei Vaultwarden ([Kapitel 22](22-vaultwarden.md)) holt `tailscale serve` ein echtes Let's-Encrypt-Zertifikat für `*.ts.net`. Nebeneffekt: Der Proxmox-MCP aus [Kapitel 23](23-proxmox-mcp.md) läuft danach ohne Dev-Mode.
> **Dauer:** ca. 30 Minuten (ohne Fehlersuche) · **Wo:** pve01-Shell, NetBox-Container, Tailscale-Admin-Konsole
> **Voraussetzung:** Tailscale auf pve01 ([Kapitel 15](15-proxmox-host.md)), *HTTPS Certificates* im Tailnet aktiv ([Kapitel 22](22-vaultwarden.md))

```text
Browser / MCP ──Tailscale──► https://pve01.<tailnet>.ts.net  ──tailscale serve──► localhost:8006 (Proxmox)
              ──Tailscale──► https://netbox.<tailnet>.ts.net ──tailscale serve──► localhost:443  (Apache → NetBox)
```

**Warum Tailscale und keine eigene CA?** Eine eigene Zertifizierungsstelle (AD CS) steht auf der [Roadmap](../roadmap.md) und ist der „richtige“ Firmenweg. Ihr Stammzertifikat müsste aber auf jedes Gerät, und sie hängt am Lab: Ist DC01 aus, gibt es keine neuen Zertifikate. Tailscale liefert sofort Zertifikate, denen jedes Gerät vertraut, und erneuert sie selbst. Dafür sind die Adressen lang und nur im Tailnet erreichbar.

## Schritt 1 · pve01 (pve01-Shell)

```bash
tailscale serve --bg https+insecure://localhost:8006
```

Die Ausgabe zeigt `https://pve01.<tailnet>.ts.net/`. `https+insecure` heißt nur: Tailscale akzeptiert intern das selbstsignierte Proxmox-Zertifikat, nach außen gibt es das echte. Die Einstellung überlebt Neustarts.

**Prüfen:** Adresse im Browser öffnen, keine Warnung, Anmeldung, eine Konsole (noVNC) öffnet sich. Der allererste Aufruf kann 10–20 Sekunden dauern, weil das Zertifikat erst ausgestellt wird. Mit `tailscale cert pve01.<tailnet>.ts.net` lässt sich das vorab anstoßen.

> [!IMPORTANT]
> Lädt die Seite ewig, obwohl `tailscale ping pve01` antwortet: siehe [Fehlerbehebung](../fehlerbehebung.md#zertifikate-kapitel-24). Bei mir half erst `systemctl restart tailscaled` auf pve01.

## Schritt 2 · Proxmox-MCP umstellen (Arbeits-PC)

In `claude_desktop_config.json` aus [Kapitel 23](23-proxmox-mcp.md) im `env`-Block:

```json
"PROXMOX_HOST": "pve01.<tailnet>.ts.net",
"PROXMOX_PORT": "443",
"PROXMOX_VERIFY_SSL": "true",
```

Die Zeile `PROXMOX_DEV_MODE` löschen (auf das letzte Komma achten). Claude Desktop komplett beenden und neu starten.

**Prüfen:** Unter **Einstellungen → Entwickler** steht `proxmox` auf **Läuft**, eine Abfrage aller Gäste klappt.

## Schritt 3 · Tailscale in den NetBox-Container (pve01-Shell)

Wie in Kapitel 22, Schritt 2:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/addon/add-tailscale-lxc.sh)"
```

Container **netbox** auswählen. Dann **jede Zeile einzeln**:

```bash
pct reboot 101
pct enter 101
```

Im Container:

```bash
tailscale up --hostname=netbox --accept-dns=false
```

Link öffnen, **Connect**, auf `Success.` warten. In der Tailscale-Admin-Konsole **Machines → netbox → ⋯ → Disable key expiry**.

## Schritt 4 · NetBox über `tailscale serve` (Container)

```bash
tailscale serve --bg https+insecure://localhost:443
```

Jetzt müssen Apache und NetBox noch zu der neuen Adresse passen. Drei Anpassungen, jede Zeile einzeln:

1. **Debian-Standardseite abschalten.** Im Container gibt es zwei VirtualHosts auf Port 80 ohne `ServerName`, Apache nimmt dann den zuerst geladenen (`000-default`):

   ```bash
   a2dissite 000-default
   ```

2. **Doppelten `X-Forwarded-Host` verhindern.** Tailscale schickt den Header mit, Apache hängt seinen eigenen Wert an. NetBox liest daraus `name, name` und antwortet mit *Bad Request (400)*, selbst mit `ALLOWED_HOSTS = ["*"]`:

   ```bash
   sed -i --follow-symlinks 's/^\(\s*\)ProxyPreserveHost On/&\n\1RequestHeader unset X-Forwarded-Host early/' /etc/apache2/sites-enabled/netbox.conf
   apachectl configtest
   systemctl reload apache2
   ```

   `grep -n X-Forwarded-Host /etc/apache2/sites-enabled/netbox.conf` zeigt danach zwei Zeilen, eine pro VirtualHost.

3. **Login-Formular für die neue Adresse freigeben** (eigene Adresse einsetzen):

   ```bash
   echo "CSRF_TRUSTED_ORIGINS = ['https://netbox.<tailnet>.ts.net']" >> /opt/netbox/netbox/netbox/configuration.py
   systemctl restart netbox netbox-rq
   ```

**Prüfen:** `https://netbox.<tailnet>.ts.net` zeigt die Anmeldeseite ohne Warnung, die Anmeldung klappt. Gegenprobe im Container:

```bash
curl -sk -o /dev/null -w "%{http_code}\n" -H "Host: netbox.<tailnet>.ts.net" -H "X-Forwarded-Host: netbox.<tailnet>.ts.net" https://localhost/login/
```

muss `200` liefern.

## Schritt 5 · Arbeits-PC: keine Subnet-Route im eigenen Netz

Im Tailscale-Menü am Arbeits-PC **Preferences → Use Tailscale subnets** abschalten. Der PC steht selbst im Heimnetz. Mit der Option lief bei mir der ganze Heimnetz-Verkehr (Laufwerk vom Pi-NAS, Proxmox-Oberfläche) durch den Tunnel über pve01, rund 13 GB. Unterwegs (Laptop, Handy) bleibt die Option an.

## Prüfen

- [ ] `https://pve01.<tailnet>.ts.net` und `https://netbox.<tailnet>.ts.net` öffnen ohne Warnung, auch am Handy im Tailnet
- [ ] Proxmox-Konsole (noVNC) funktioniert über die `ts.net`-Adresse
- [ ] Proxmox-MCP läuft mit `PROXMOX_VERIFY_SSL=true` und ohne Dev-Mode
- [ ] Bei *netbox* steht in der Tailscale-Konsole „Expiry disabled“
- [ ] `tailscale ping --icmp pve01` vom Arbeits-PC antwortet

## Häufige Fehler

| Problem | Ursache | Lösung |
|---|---|---|
| `ts.net`-Seite lädt ewig, `tailscale ping` geht, `--icmp` nicht | `tailscaled` auf pve01 nimmt keine neuen Verbindungen an | `systemctl restart tailscaled` auf pve01 |
| NetBox zeigt die Debian-Seite „It works!“ | `000-default` gewinnt auf Port 80 | `a2dissite 000-default`, Apache neu laden |
| NetBox: *Bad Request (400)* | doppelter `X-Forwarded-Host` | `RequestHeader unset X-Forwarded-Host early` |
| NetBox-Login: *CSRF verification failed* | neue Adresse nicht bekannt | `CSRF_TRUSTED_ORIGINS` setzen, NetBox neu starten |
| `context canceled` nach dem Login-Link | `tailscale up` mit Strg + C abgebrochen | `tailscale status` prüfen, ggf. neu anmelden |

Weitere Fälle: [Fehlerbehebung](../fehlerbehebung.md#zertifikate-kapitel-24)

Wie es weitergeht: [Roadmap](../roadmap.md)
