[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RendererPath,
    [Parameter(Mandatory)][string]$BackupPath,
    [string]$ExpectedHash,
    [switch]$Apply,
    [ValidateSet('Object', 'Json')]
    [string]$OutputFormat = 'Json'
)

$ErrorActionPreference = 'Stop'

function Write-Result {
    param($Value, [string]$Format)
    if ($Format -eq 'Json') {
        $Value | ConvertTo-Json -Depth 5
    }
    else {
        $Value
    }
}

if (-not (Test-Path -LiteralPath $RendererPath -PathType Leaf)) {
    throw "Renderer file not found: $RendererPath"
}
if (-not (Test-Path -LiteralPath $BackupPath -PathType Leaf)) {
    throw "Backup file not found: $BackupPath"
}

$RendererPath = (Resolve-Path -LiteralPath $RendererPath).Path
$BackupPath = (Resolve-Path -LiteralPath $BackupPath).Path
$rendererDirectory = Split-Path -Parent $RendererPath
$backupDirectory = Split-Path -Parent $BackupPath
$rendererLeaf = Split-Path -Leaf $RendererPath
$backupLeaf = Split-Path -Leaf $BackupPath

if ($rendererDirectory -ine $backupDirectory -or $backupLeaf -notlike "$rendererLeaf.backup-*") {
    throw "Backup must be a generated '$rendererLeaf.backup-*' file in the renderer directory."
}

$currentHash = (Get-FileHash -LiteralPath $RendererPath -Algorithm SHA256).Hash
$backupHash = (Get-FileHash -LiteralPath $BackupPath -Algorithm SHA256).Hash
if ($ExpectedHash -and $currentHash -ine $ExpectedHash) {
    throw "Renderer hash changed. Expected $ExpectedHash but found $currentHash. Diagnose the current file before restoring."
}

$blocking = @(
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessName -ieq 'iRacingUI' -or $_.ProcessName -imatch '^iRacingSim'
        } |
        Select-Object ProcessName, Id
)

$preview = [PSCustomObject]@{
    RendererPath = $RendererPath
    BackupPath = $BackupPath
    CurrentSHA256 = $currentHash
    BackupSHA256 = $backupHash
    Applied = $false
    SafeToRestore = ($blocking.Count -eq 0)
    BlockingProcesses = $blocking
    SafetyBackupPath = $null
}

if (-not $Apply) {
    Write-Result -Value $preview -Format $OutputFormat
    return
}

if ($blocking.Count -gt 0) {
    $names = ($blocking | ForEach-Object { "$($_.ProcessName) ($($_.Id))" }) -join ', '
    throw "Close iRacing UI and simulator processes before restoring: $names"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$safetyBackupPath = Join-Path $rendererDirectory "$rendererLeaf.pre-restore-$stamp"
$temporaryPath = Join-Path $rendererDirectory ".$rendererLeaf.restore-$([guid]::NewGuid().ToString('N')).tmp"

try {
    [System.IO.File]::Copy($BackupPath, $temporaryPath, $false)
    [System.IO.File]::Replace($temporaryPath, $RendererPath, $safetyBackupPath, $true)
}
finally {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
}

$restoredHash = (Get-FileHash -LiteralPath $RendererPath -Algorithm SHA256).Hash
if ($restoredHash -ine $backupHash) {
    throw "Restore verification failed. Expected backup hash $backupHash but found $restoredHash."
}

$result = [PSCustomObject]@{
    RendererPath = $RendererPath
    BackupPath = $BackupPath
    CurrentSHA256 = $currentHash
    BackupSHA256 = $backupHash
    Applied = $true
    SafeToRestore = $true
    BlockingProcesses = @()
    SafetyBackupPath = $safetyBackupPath
    RestoredSHA256 = $restoredHash
}
Write-Result -Value $result -Format $OutputFormat
