# Kapitel 10 · Linux-Dienste (optional)

[← Kapitel 9](09-testen.md) · [Übersicht](../../README.md#anleitung)

> **Ziel:** Eine Ubuntu-VM mit Docker für Überwachung, Reverse Proxy, Jump Host und Kennwortverwaltung.
> **Dauer:** ca. 90 Minuten · **Wo:** Host, danach TOOLS01 (per SSH)

## Schritt 1 · VM anlegen (Host)

| Einstellung | Wert |
|---|---|
| Name | `TOOLS01` |
| Generation | 2 |
| Arbeitsspeicher | **6 GB fest**, dynamisch aus |
| Netzwerk | `LAB` |
| Festplatte | 60 GB |

Vor dem ersten Start: **Einstellungen → Sicherheit** → Vorlage **Microsoft UEFI-Zertifizierungsstelle**. Mit der Standardvorlage *Microsoft Windows* startet der Ubuntu-Installer nicht:

<img src="../bilder/ubuntu-secure-boot-fehler.png" width="480" alt="Secure Boot blockiert Ubuntu">

> [!WARNING]
> **Kein dynamischer Arbeitsspeicher für Linux-VMs.** Beim Start von Containern bekommt Linux nicht schnell genug RAM nach, das endet mit *Out of memory* oder einer Kernel Panic:
>
> <p>
>   <img src="../bilder/ubuntu-kernel-panic.png" width="45%" alt="Kernel Panic">
>   <img src="../bilder/hyperv-dynamischer-ram.png" width="45%" alt="Dynamischen RAM ausschalten">
> </p>

## Schritt 2 · Ubuntu installieren (TOOLS01)

DC01 muss laufen, sonst gibt es beim Installer *„Temporary failure resolving“*.

| Installer-Seite | Einstellung |
|---|---|
| Netzwerk | Manuell: `10.0.0.50/24`, Gateway `10.0.0.1`, DNS `10.0.0.10`, Suchdomäne `lab.test` |
| Speicher | Ganze Platte, LVM |
| Profil | Servername `tools01`, eigener Benutzer |
| SSH | **OpenSSH-Server installieren** |

Nach der Installation die ganze Platte nutzen. Der Installer nimmt nur einen Teil:

```bash
sudo lvextend -r -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
```

Ab jetzt arbeitest du vom Host aus per SSH (`ssh benutzer@10.0.0.50`). Das ist bequemer als die Hyper-V-Konsole, und Kopieren/Einfügen funktioniert.

## Schritt 3 · Docker installieren

Nach der offiziellen Anleitung auf docs.docker.com (*Install Docker Engine on Ubuntu → apt repository*). Danach:

```bash
sudo usermod -aG docker $USER   # abmelden und neu anmelden
docker run --rm hello-world
```

Alle Dienste bekommen einen eigenen Ordner unter `~/tools/<dienst>` mit einer eigenen `docker-compose.yml`.

## Schritt 4 · Uptime Kuma (Überwachung)

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

![Uptime Kuma startet](../bilder/docker-uptime-kuma-start.png)

Im Browser `http://10.0.0.50:3001` → Admin-Konto anlegen → **Neuen Monitor hinzufügen**:

| Ziel | Monitor-Typ |
|---|---|
| DC01 | Ping auf `10.0.0.10` und DNS (`dc01.lab.test` über `10.0.0.10`) |
| FS01 | TCP-Port `10.0.0.40:445` |
| Weboberflächen | HTTP(s) |

![Uptime Kuma meldet DC01 offline](../bilder/uptime-kuma-dashboard.png)

> [!TIP]
> `restart: unless-stopped` gehört in jede `docker-compose.yml`. Ohne startet nach einem Neustart der VM nichts von selbst.

## Schritt 5 · Weitere Dienste

Nach demselben Muster laufen auf TOOLS01:

| Dienst | Zweck | Port |
|---|---|---|
| **Nginx Proxy Manager** | Namen wie `kuma.lab.test` statt IP:Port. Im DNS auf DC01 je einen CNAME auf `tools01.lab.test` anlegen | 80, 81 (Admin) |
| **Netdata** | Leistungsdaten der Linux-VMs | 19999 |
| **Warpgate** | Jump Host für RDP und SSH mit Sitzungsaufzeichnung | 8888 |
| **Infisical** | Kennwörter und Secrets des Labs | 8080 |

<p align="center">
  <img src="../bilder/npm-proxy-hosts.png" width="49%" alt="Nginx Proxy Manager">
  <img src="../bilder/infisical-uebersicht.png" width="49%" alt="Infisical">
</p>

Auf einer eigenen VM `NETBOX01` (`10.0.0.30`, 4 GB fest) läuft **NetBox** per `netbox-docker` als Quelle der Wahrheit für IP-Adressen und VMs:

![NetBox: alle VMs des Labs](../bilder/netbox-vms.png)

## Ausblick · MECM

Auf `CM01` (`10.0.0.20`) läuft Microsoft Configuration Manager. Das ist ein eigenes großes Thema: SQL Server, Windows ADK, Schema-Erweiterung, Site-Installation. Die wichtigsten Stolpersteine aus diesem Lab:

<p align="center">
  <img src="../bilder/mecm-setup-standort.png" width="40%" alt="MECM-Setup: Standortcode">
  <img src="../bilder/mecm-konsole-geraete.png" width="58%" alt="MECM-Konsole mit Geräten">
</p>

- SQL Server braucht **festen** Arbeitsspeicher, 8 GB für die ganze VM
- Ohne eigene PKI scheitert der Client mit `CCM_E_NO_CLIENT_PKI_CERT`, wenn die Site auf *HTTPS only* steht. Lösung: Communication Security auf **Enhanced HTTP**
- Für Client-Push ein eigenes Dienstkonto, das per GPO lokaler Admin auf den Clients ist ([Kapitel 8](08-gruppenrichtlinien.md#schritt-3--rdp-nur-für-bestimmte-abteilungen))
- Configuration Manager bekommt ab Version 2609 nur noch ein Release pro Jahr, Microsoft entwickelt vor allem Intune weiter

Wie es danach weitergeht: [Roadmap](../roadmap.md)
