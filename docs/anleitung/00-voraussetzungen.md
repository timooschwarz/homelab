# 0 · Voraussetzungen

[Übersicht](../../README.md#anleitung) · weiter: [1 · Netzwerk →](01-netzwerk.md)

## Hardware

| | Minimum | Empfohlen |
|---|---|---|
| RAM | 16 GB (DC, Dateiserver, Client) | 32 GB, mit MECM eher 64 GB |
| CPU | 4 Kerne mit Virtualisierung (Intel VT-x / AMD-V) | 6+ Kerne |
| Speicher | 200 GB SSD | 500 GB SSD |

Wie viel RAM die einzelnen VMs brauchen, steht in [Aufbau](../aufbau.md#server). Die Faustregel: Linux-VMs und SQL Server bekommen festen RAM, Windows-VMs dynamischen.

## Software

| Was | Woher | Hinweis |
|---|---|---|
| Windows 10/11 **Pro** oder Enterprise als Host | – | Home kann kein Hyper-V |
| Windows Server 2025 Evaluation (ISO) | Microsoft Evaluation Center | 180 Tage kostenlos, verlängerbar mit `slmgr /rearm` |
| Windows 11 Enterprise Evaluation oder Pro (ISO) | Microsoft Evaluation Center bzw. Media Creation Tool | Für den Testclient |
| Ubuntu Server LTS (ISO) | ubuntu.com | Nur für die optionalen Linux-Dienste |

## Hyper-V aktivieren

1. Startmenü → **„Windows-Features aktivieren oder deaktivieren“**
2. Haken bei **Hyper-V** (mit allen Unterpunkten) → OK
3. Neu starten

Danach gibt es im Startmenü den **Hyper-V-Manager**.

## Namen und Adressen in dieser Anleitung

| Was | Wert |
|---|---|
| Domäne | `lab.test` (NetBIOS `LAB`) |
| Netz | `10.0.0.0/24` |
| Gateway (Host) | `10.0.0.1` |
| DC01 | `10.0.0.10` |
| FS01 | `10.0.0.40` |
| DHCP-Bereich | `10.0.0.100` – `10.0.0.200` |

`.test` ist eine reservierte Endung, die es im Internet nie geben wird. Für ein Lab ist das sicherer als eine echte Domain oder `.local`.
