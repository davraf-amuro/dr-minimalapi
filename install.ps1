<#
.SYNOPSIS
    Installa il pacchetto dr-minimalapi (Minimal API .NET) nel progetto corrente.
.DESCRIPTION
    Esegui dalla root del progetto host.

    Installazione:
        irm https://raw.githubusercontent.com/davraf-amuro/dr-minimalapi/main/install.ps1 | iex

    Aggiornamento (sovrascrive i file gia presenti):
        & ([scriptblock]::Create((irm https://raw.githubusercontent.com/davraf-amuro/dr-minimalapi/main/install.ps1))) -Update

    Dipende da dr-dotnet-backend: se assente dal manifest del progetto host,
    viene installato automaticamente prima di dr-minimalapi.
.PARAMETER Update
    Sovrascrive i file gia presenti nel progetto con la versione corrente del pacchetto.
#>

[CmdletBinding()]
param([switch]$Update)

$libUrl = "https://raw.githubusercontent.com/davraf-amuro/dr-guidelines/main/install-lib.ps1"

try {
    $libContent = Invoke-RestMethod -Uri $libUrl
    Invoke-Expression $libContent
} catch {
    # Fallback per test in fase Private (gate 2b): invocazione da path locale del workspace,
    # dove $PSScriptRoot e' valorizzato (non e' il caso di `irm | iex`, dove e' vuoto).
    if ($PSScriptRoot) {
        $localLib = Join-Path (Split-Path $PSScriptRoot -Parent) "dr-guidelines\install-lib.ps1"
        if (Test-Path $localLib) {
            . $localLib
        } else {
            throw
        }
    } else {
        throw
    }
}

Install-DrPackage -PackageName "dr-minimalapi" -Update:$Update
