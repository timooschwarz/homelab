<#
.SYNOPSIS
    Lab-Theme verteilen: Hintergrund und Kontobild je Client nach NETLOGON kopieren
    und in der GPO das Standard-Kontobild einschalten.

.DESCRIPTION
    Auf DC01 als Domaenen-Admin in einer PowerShell "Als Administrator" starten.

    Das Skript
      1. prueft die Bilddateien (echtes JPEG, alle Kontobild-Groessen vorhanden),
      2. kopiert jeden Ordner unter .\Hintergrund nach \\<Domaene>\NETLOGON\Hintergrund\<COMPUTERNAME>,
      3. setzt in der GPO die Richtlinie "Apply the default account picture to all users".

    Die vorhandene Datei NETLOGON\Hintergrund\wallpaper.jpg wird nicht angefasst.
    Die zwei Files-Eintraege in der GPO legst du danach von Hand an (siehe Ausgabe am Ende),
    dafuer gibt es kein unterstuetztes Cmdlet.

.PARAMETER GpoName
    Name der GPO, die an Lab/Computer haengt.

.PARAMETER Source
    Ordner mit einem Unterordner je Computername.

.PARAMETER TargetRoot
    Zielordner. Leer = \\<Domaene>\NETLOGON\Hintergrund.

.PARAMETER SkipPolicy
    Nur Dateien kopieren, die GPO nicht aendern.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File "C:\Pfad\Deploy-LabTheme.ps1" -Source "C:\Pfad\Hintergrund" -WhatIf

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File "C:\Pfad\Deploy-LabTheme.ps1" -Source "C:\Pfad\Hintergrund"

.NOTES
    Anleitung: docs/anleitung/25-lab-design-gpo.md
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$GpoName = 'GPO-Computer-Design',
    [string]$Source = '',
    [string]$TargetRoot = '',
    [switch]$SkipPolicy
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$accountFiles = 'user.png', 'user.bmp', 'user-32.png', 'user-40.png', 'user-48.png', 'user-192.png'
$onWindows = ($env:OS -eq 'Windows_NT')

# --- Voraussetzungen -------------------------------------------------------
if ($onWindows) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Bitte die PowerShell "Als Administrator" starten.'
    }
}

# Windows PowerShell 5.1 kennt $PSScriptRoot im param-Block noch nicht, deshalb erst hier.
if (-not $Source) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $Source = Join-Path $scriptDir 'Hintergrund'
}

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    throw "Quellordner nicht gefunden: $Source"
}

if (-not $TargetRoot) {
    $domain = (Get-CimInstance -ClassName Win32_ComputerSystem).Domain
    $TargetRoot = "\\$domain\NETLOGON\Hintergrund"
}

# --- 1. Dateien pruefen ----------------------------------------------------
$clients = @(Get-ChildItem -LiteralPath $Source -Directory)
if ($clients.Count -eq 0) {
    throw "Unter $Source liegt kein Client-Ordner."
}

foreach ($client in $clients) {
    $wallpaper = Join-Path $client.FullName 'wallpaper.jpg'
    if (-not (Test-Path -LiteralPath $wallpaper -PathType Leaf)) {
        throw "$($client.Name): wallpaper.jpg fehlt."
    }

    # Die Datei muss ein echtes JPEG sein, nicht nur so heissen (siehe Fehlerbehebung: GPO-Hintergrundbild bleibt schwarz).
    $stream = [System.IO.File]::OpenRead($wallpaper)
    try {
        $head = New-Object byte[] 3
        [void]$stream.Read($head, 0, 3)
    }
    finally {
        $stream.Dispose()
    }
    if (-not ($head[0] -eq 0xFF -and $head[1] -eq 0xD8 -and $head[2] -eq 0xFF)) {
        throw "$($client.Name): wallpaper.jpg ist kein echtes JPEG."
    }

    foreach ($name in $accountFiles) {
        $file = Join-Path (Join-Path $client.FullName 'Kontobild') $name
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "$($client.Name): Kontobild\$name fehlt."
        }
    }
}
$clientNames = ($clients | ForEach-Object { $_.Name }) -join ', '
Write-Host "Geprueft: $clientNames" -ForegroundColor Green

# --- 2. Nach NETLOGON kopieren ---------------------------------------------
foreach ($client in $clients) {
    $dest = Join-Path $TargetRoot $client.Name
    $destPictures = Join-Path $dest 'Kontobild'

    if ($PSCmdlet.ShouldProcess($dest, 'Hintergrund und Kontobilder kopieren')) {
        New-Item -ItemType Directory -Path $destPictures -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $client.FullName 'wallpaper.jpg') -Destination $dest -Force
        foreach ($name in $accountFiles) {
            $file = Join-Path (Join-Path $client.FullName 'Kontobild') $name
            Copy-Item -LiteralPath $file -Destination $destPictures -Force
        }
        Write-Host "Kopiert:  $dest" -ForegroundColor Green
    }
}

# --- 3. Richtlinie fuer das Standard-Kontobild -----------------------------
if ($SkipPolicy) {
    Write-Host 'GPO nicht geaendert (-SkipPolicy).' -ForegroundColor Yellow
}
else {
    Import-Module GroupPolicy
    $gpo = Get-GPO -Name $GpoName
    if ($PSCmdlet.ShouldProcess($gpo.DisplayName, 'UseDefaultTile = 1 setzen')) {
        Set-GPRegistryValue -Name $gpo.DisplayName `
            -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' `
            -ValueName 'UseDefaultTile' -Type DWord -Value 1 | Out-Null
        Write-Host "GPO:      $($gpo.DisplayName) -> Apply the default account picture to all users = Enabled" -ForegroundColor Green
    }
}

# --- Was noch von Hand fehlt -----------------------------------------------
Write-Host ''
Write-Host 'Noch von Hand in der GPO (Computer Configuration > Preferences > Windows Settings > Files):' -ForegroundColor Cyan
Write-Host "  A) Source:      $TargetRoot\%ComputerName%\wallpaper.jpg"
Write-Host '     Destination: C:\Windows\Web\Wallpaper\lab-wallpaper.jpg   (Action: Replace, unter dem vorhandenen Eintrag)'
Write-Host "  B) Source:      $TargetRoot\%ComputerName%\Kontobild\*.*"
Write-Host '     Destination: C:\ProgramData\Microsoft\User Account Pictures   (Action: Replace)'
Write-Host ''
Write-Host 'Danach auf dem Client: gpupdate /force, neu starten, anmelden.' -ForegroundColor Cyan
