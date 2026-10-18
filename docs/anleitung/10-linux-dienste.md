# 10 · Linux-Dienste (optional)

[← 9 · Testen](09-testen.md) · [Übersicht](../../README.md#anleitung)

Eine Ubuntu-VM `TOOLS01` (`10.0.0.50`) mit Docker übernimmt die Werkzeuge rund ums Lab: Überwachung, Reverse Proxy, Jump Host, Kennwörter.

## VM anlegen

| Einstellung | Wert |
|---|---|
| Generation | 2 |
| Sicherheit | Secure-Boot-Vorlage **Microsoft UEFI-Zertifizierungsstelle** |
| RAM | **4–6 GB fest**, dynamisch aus |
| Netzwerk | `LAB` |

> [!WARNING]
> Mit der Standardvorlage *Microsoft Windows* startet der Ubuntu-Installer nicht (*„The signed image's hash is not allowed“*). Mit dynamischem RAM gibt es beim Start von Containern Out-of-Memory oder eine Kernel Panic.

Bei der Installation feste IP `10.0.0.50/24`, Gateway `10.0.0.1`, DNS `10.0.0.10`, Suchdomäne `lab.test`, **OpenSSH-Server** an. DC01 muss dabei laufen, sonst gibt es *„Temporary failure resolving“*.

Nach der Installation die ganze Platte nutzen (der Installer nimmt nur einen Teil):

```bash
sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
```

Docker nach der offiziellen Anleitung auf docs.docker.com installieren.

## Uptime Kuma

```bash
mkdir -p ~/tools/uptime-kuma && cd ~/tools/uptime-kuma
cat > docker-compose.yml <<'EOF'
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - ./data:/app/data
EOF
docker compose up -d
```

Weboberfläche: `http://10.0.0.50:3001`. Monitore anlegen:

| Ziel | Typ |
|---|---|
| DC01 | Ping + DNS (`dc01.lab.test` über `10.0.0.10`) |
| FS01 | TCP-Port 445 |
| Weitere Dienste | HTTP |

> [!TIP]
> `restart: unless-stopped` in jede `docker-compose.yml`. Ohne startet nach einem Neustart der VM nichts von selbst.

## Was sonst noch auf TOOLS01 läuft

| Dienst | Zweck |
|---|---|
| Nginx Proxy Manager | Namen wie `kuma.lab.test` statt IP:Port. Dafür im DNS auf DC01 CNAMEs auf `tools01.lab.test` anlegen |
| Netdata | Leistungsdaten der Linux-VMs |
| Warpgate | Jump Host für RDP und SSH mit Sitzungsaufzeichnung |
| Infisical | Kennwörter des Labs |

Separat auf `NETBOX01` läuft **NetBox** (per `netbox-docker`) als Quelle der Wahrheit für IP-Adressen und VMs.

## Ausblick: MECM

Auf `CM01` läuft Microsoft Configuration Manager. Das ist ein eigenes großes Kapitel (SQL Server, ADK, Schema-Erweiterung, Site-Installation). Die wichtigsten Stolpersteine aus diesem Lab:

- SQL Server braucht **festen** RAM (8 GB für die ganze VM)
- Ohne eigene PKI scheitert der Client mit `CCM_E_NO_CLIENT_PKI_CERT`, wenn die Site auf *HTTPS only* steht. Lösung: *Enhanced HTTP*
- Für Client-Push ein eigenes Dienstkonto, das per GPO lokaler Admin auf den Clients ist ([Kapitel 8](08-gruppenrichtlinien.md#rdp-nur-für-bestimmte-abteilungen))
