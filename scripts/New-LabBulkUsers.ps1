<#
.SYNOPSIS
    Legt Testbenutzer aus benutzer.csv in lab.test an.

.DESCRIPTION
    - Benutzer landen in OU=<Abteilung>,OU=Benutzer,OU=Lab
    - Fehlende Abteilungs-OUs und Gruppen GG-<Abteilung> (in OU=Gruppen,OU=Lab) werden angelegt
    - Jeder Benutzer kommt in seine Gruppe GG-<Abteilung>
    - Ein gemeinsames Startpasswort wird beim Start abgefragt (steht NICHT in der CSV)
    - Alle Benutzer bekommen die Beschreibung "Bulk-Import Testbenutzer", damit man sie
      spaeter wiederfindet bzw. wieder loeschen kann
    - Vorhandene Benutzer werden uebersprungen, das Skript kann also mehrfach laufen

    Auf DC01 als Domaenen-Admin ausfuehren (oder auf einem Rechner mit RSAT).

.EXAMPLE
    .\New-LabBulkUsers.ps1 -WhatIf
    Probelauf: zeigt nur an, was passieren wuerde, aendert nichts.

.EXAMPLE
    .\New-LabBulkUsers.ps1
    Echter Lauf.

.EXAMPLE
    .\New-LabBulkUsers.ps1 -PasswortBeiAnmeldungAendern
    Benutzer muessen das Passwort bei der ersten Anmeldung aendern.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$CsvPath = (Join-Path $PSScriptRoot 'benutzer.csv'),
    [string]$LogPath = 'C:\Temp\LabBulkUsers.log',
    [switch]$PasswortBeiAnmeldungAendern
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

# --- Domaene automatisch ermitteln (lab.test) -------------------------------
$Domain     = Get-ADDomain
$DomainDN   = $Domain.DistinguishedName   # DC=lab,DC=test
$DnsRoot    = $Domain.DNSRoot             # lab.test
$BenutzerOU = "OU=Benutzer,OU=Lab,$DomainDN"
$GruppenOU  = "OU=Gruppen,OU=Lab,$DomainDN"
$Kennung    = 'Bulk-Import Testbenutzer'

# --- Logging ----------------------------------------------------------------
$logDir = Split-Path -Path $LogPath -Parent
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -WhatIf:$false | Out-Null }

function Write-Log {
    param([string]$Text, [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Text
    Add-Content -Path $LogPath -Value $line -WhatIf:$false
    switch ($Level) {
        'WARN'  { Write-Warning $Text }
        'ERROR' { Write-Host $Text -ForegroundColor Red }
        default { Write-Host $Text }
    }
}

Write-Log "---- Start (Domaene $DnsRoot, WhatIf=$WhatIfPreference) ----"

# --- Voraussetzungen pruefen ------------------------------------------------
foreach ($dn in $BenutzerOU, $GruppenOU) {
    try   { Get-ADOrganizationalUnit -Identity $dn | Out-Null }
    catch { Write-Log "OU fehlt: $dn - bitte zuerst anlegen." 'ERROR'; return }
}

if (-not (Test-Path $CsvPath)) { Write-Log "CSV nicht gefunden: $CsvPath" 'ERROR'; return }

$Benutzer = @(Import-Csv -Path $CsvPath -Delimiter ';' -Encoding UTF8)
if ($Benutzer.Count -eq 0) { Write-Log 'CSV ist leer.' 'ERROR'; return }

$spalten = $Benutzer[0].PSObject.Properties.Name
$fehlend = @('Vorname','Nachname','Benutzername','Abteilung' | Where-Object { $_ -notin $spalten })
if ($fehlend.Count -gt 0) { Write-Log "Spalten fehlen in der CSV: $($fehlend -join ', ')" 'ERROR'; return }

Write-Log "$($Benutzer.Count) Eintraege in der CSV gefunden."

# --- Startpasswort ----------------------------------------------------------
if ($WhatIfPreference) {
    $Passwort = ConvertTo-SecureString 'WhatIf-Dummy-123!' -AsPlainText -Force
} else {
    $Passwort = Read-Host 'Startpasswort fuer alle Testbenutzer' -AsSecureString
}

# --- Abteilungs-OUs und Gruppen ---------------------------------------------
$Abteilungen = $Benutzer | ForEach-Object { $_.Abteilung.Trim() } | Sort-Object -Unique

foreach ($abt in $Abteilungen) {
    $ouDN = "OU=$abt,$BenutzerOU"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'")) {
        if ($PSCmdlet.ShouldProcess($ouDN, 'OU anlegen')) {
            New-ADOrganizationalUnit -Name $abt -Path $BenutzerOU -ProtectedFromAccidentalDeletion $true
            Write-Log "OU angelegt: $ouDN"
        }
    }

    $grp = "GG-$abt"
    if (-not (Get-ADGroup -Filter "SamAccountName -eq '$grp'")) {
        if ($PSCmdlet.ShouldProcess("$grp in $GruppenOU", 'Gruppe anlegen')) {
            New-ADGroup -Name $grp -SamAccountName $grp -GroupScope Global -GroupCategory Security `
                        -Path $GruppenOU -Description "Abteilung $abt"
            Write-Log "Gruppe angelegt: $grp"
        }
    }
}

# --- Benutzer ---------------------------------------------------------------
$angelegt = 0; $uebersprungen = 0; $fehler = 0

foreach ($u in $Benutzer) {
    $vor  = $u.Vorname.Trim()
    $nach = $u.Nachname.Trim()
    $sam  = $u.Benutzername.Trim().ToLower()
    $abt  = $u.Abteilung.Trim()
    $name = "$vor $nach"
    $upn  = "$sam@$DnsRoot"
    $ouDN = "OU=$abt,$BenutzerOU"

    if ([string]::IsNullOrWhiteSpace($sam) -or $sam.Length -gt 20) {
        Write-Log "Ungueltiger Benutzername '$sam' ($name) - max. 20 Zeichen." 'WARN'; $fehler++; continue
    }

    if (Get-ADUser -Filter "SamAccountName -eq '$sam'") {
        Write-Log "Existiert bereits, uebersprungen: $sam" 'WARN'; $uebersprungen++; continue
    }

    if ($PSCmdlet.ShouldProcess("$name ($sam) -> $ouDN, Gruppe GG-$abt", 'Benutzer anlegen')) {
        try {
            New-ADUser -Name $name -GivenName $vor -Surname $nach -DisplayName $name `
                       -SamAccountName $sam -UserPrincipalName $upn -EmailAddress $upn `
                       -Department $abt -Description $Kennung -Path $ouDN `
                       -AccountPassword $Passwort -Enabled $true `
                       -ChangePasswordAtLogon $PasswortBeiAnmeldungAendern.IsPresent
            Add-ADGroupMember -Identity "GG-$abt" -Members $sam
            Write-Log "Angelegt: $sam ($name) -> $abt"
            $angelegt++
        }
        catch {
            Write-Log "Fehler bei ${sam}: $($_.Exception.Message)" 'ERROR'; $fehler++
        }
    }
}

Write-Log "---- Fertig: $angelegt angelegt, $uebersprungen uebersprungen, $fehler Fehler. Log: $LogPath ----"
