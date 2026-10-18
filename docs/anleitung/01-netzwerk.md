# 1 · Netzwerk: eigener Switch mit NAT

[← 0 · Voraussetzungen](00-voraussetzungen.md) · [Übersicht](../../README.md#anleitung) · weiter: [2 · Domain Controller →](02-domain-controller.md)

Das Lab bekommt ein eigenes Netz `10.0.0.0/24`. Der Host spielt den Router und leitet per NAT ins Internet weiter. So stört der DHCP-Server des Labs nicht dein Heimnetz.

## Switch und NAT anlegen

Das geht nur per PowerShell. Auf dem **Host** PowerShell **als Administrator** öffnen:

```powershell
# Interner Switch
New-VMSwitch -Name "LAB" -SwitchType Internal

# Host bekommt im Lab-Netz die Adresse 10.0.0.1 (= Gateway der VMs)
New-NetIPAddress -IPAddress 10.0.0.1 -PrefixLength 24 -InterfaceAlias "vEthernet (LAB)"

# NAT für das ganze Netz
New-NetNat -Name "LABNAT" -InternalIPInterfaceAddressPrefix 10.0.0.0/24
```

## Prüfen

- Im Hyper-V-Manager unter **Manager für virtuelle Switches** taucht `LAB` als *Intern* auf.
- `Get-NetNat` zeigt `LABNAT` mit `10.0.0.0/24`.

## Optional: Lab-Namen vom Host aus auflösen

Damit `netbox.lab.test` & Co. später auch im Browser auf dem Host funktionieren, ohne den DNS des Heimnetzes umzustellen, hilft eine NRPT-Regel. Sie schickt nur Anfragen für `*.lab.test` an DC01:

```powershell
Add-DnsClientNrptRule -Namespace ".lab.test" -NameServers "10.0.0.10"
```

Das geht erst, wenn DC01 läuft (nächstes Kapitel).
