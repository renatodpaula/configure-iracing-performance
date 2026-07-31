[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RendererPath,
    [Parameter(Mandatory)][string]$Section,
    [Parameter(Mandatory)][string[]]$Set,
    [string]$ExpectedHash,
    [switch]$AllowReplayChanges,
    [switch]$Apply,
    [ValidateSet('Object', 'Json')]
    [string]$OutputFormat = 'Json'
)

$ErrorActionPreference = 'Stop'

function Get-BlockingIRacingProcesses {
    return @(
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ProcessName -ieq 'iRacingUI' -or $_.ProcessName -imatch '^iRacingSim'
            } |
            Select-Object ProcessName, Id
    )
}

function Test-IsLiveRendererPath {
    param([Parameter(Mandatory)][string]$Path)

    $documents = [Environment]::GetFolderPath('MyDocuments')
    $liveRendererDirectory = [System.IO.Path]::GetFullPath((Join-Path $documents 'iRacing'))
    $candidateDirectory = [System.IO.Path]::GetFullPath((Split-Path -Parent $Path))
    return $candidateDirectory.Equals($liveRendererDirectory, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-TextFile {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $offset = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $encoding = [System.Text.UTF8Encoding]::new($true)
        $offset = 3
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encoding = [System.Text.UnicodeEncoding]::new($false, $true)
        $offset = 2
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encoding = [System.Text.UnicodeEncoding]::new($true, $true)
        $offset = 2
    }
    else {
        $encoding = [System.Text.UTF8Encoding]::new($false)
    }

    $text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
    $newLine = if ($text.Contains("`r`n")) { "`r`n" } elseif ($text.Contains("`n")) { "`n" } else { "`r`n" }

    return [PSCustomObject]@{
        Text = $text
        Encoding = $encoding
        NewLine = $newLine
    }
}

function Write-Result {
    param($Value, [string]$Format)

    if ($Format -eq 'Json') {
        $Value | ConvertTo-Json -Depth 6
    }
    else {
        $Value
    }
}

if (-not (Test-Path -LiteralPath $RendererPath -PathType Leaf)) {
    throw "Renderer file not found: $RendererPath"
}
$RendererPath = (Resolve-Path -LiteralPath $RendererPath).Path

if ($Section -imatch '^Replay' -and -not $AllowReplayChanges) {
    throw "Replay changes are protected by default. Add -AllowReplayChanges only after the user explicitly requests a replay change."
}

$requested = [ordered]@{}
foreach ($item in $Set) {
    if ($item -notmatch '^([^=]+)=(.*)$') {
        throw "Invalid setting '$item'. Use Key=Value."
    }
    $key = $matches[1].Trim()
    $value = $matches[2].Trim()
    if (-not $key) {
        throw "A setting key cannot be empty."
    }
    if ($value -match '[;\r\n]') {
        throw "Value for '$key' contains a forbidden semicolon or line break."
    }
    if (@($requested.Keys | Where-Object { $_ -ieq $key }).Count -gt 0) {
        throw "Setting '$key' was provided more than once."
    }
    $requested[$key] = $value
}

$currentHash = (Get-FileHash -LiteralPath $RendererPath -Algorithm SHA256).Hash
if ($ExpectedHash -and $currentHash -ine $ExpectedHash) {
    throw "Renderer hash changed. Expected $ExpectedHash but found $currentHash. Run diagnose.ps1 again before editing."
}

$file = Get-TextFile -Path $RendererPath
$lines = [regex]::Split($file.Text, '\r\n|\n|\r')
$currentSection = $null
$foundSection = $false
$foundCounts = @{}
$changes = @()

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match '^\s*\[([^\]]+)\]\s*(?:;.*)?$') {
        $currentSection = $matches[1].Trim()
        if ($currentSection -ieq $Section) {
            $foundSection = $true
        }
        continue
    }

    if ($currentSection -ine $Section) {
        continue
    }

    foreach ($key in $requested.Keys) {
        $escapedKey = [regex]::Escape($key)
        if ($lines[$index] -match "^(\s*$escapedKey\s*=\s*)(.*?)(\s*;.*)?$") {
            if (-not $foundCounts.ContainsKey($key)) {
                $foundCounts[$key] = 0
            }
            $foundCounts[$key]++
            $oldValue = $matches[2].Trim()
            $newValue = [string]$requested[$key]
            $suffix = if ($null -ne $matches[3]) { $matches[3] } else { '' }
            $lines[$index] = $matches[1] + $newValue + $suffix
            $changes += [PSCustomObject]@{
                Section = $Section
                Key = $key
                OldValue = $oldValue
                NewValue = $newValue
                Changed = ($oldValue -cne $newValue)
            }
        }
    }
}

if (-not $foundSection) {
    throw "Section [$Section] was not found in $RendererPath."
}
foreach ($key in $requested.Keys) {
    $count = if ($foundCounts.ContainsKey($key)) { $foundCounts[$key] } else { 0 }
    if ($count -eq 0) {
        throw "Key '$key' was not found in section [$Section]. Refusing to create an unknown key."
    }
    if ($count -gt 1) {
        throw "Key '$key' appears $count times in section [$Section]. Refusing an ambiguous edit."
    }
}

$effectiveChanges = @($changes | Where-Object Changed)
$processGuardApplied = Test-IsLiveRendererPath -Path $RendererPath
$blocking = if ($processGuardApplied) { Get-BlockingIRacingProcesses } else { @() }
$preview = [PSCustomObject]@{
    RendererPath = $RendererPath
    Section = $Section
    CurrentSHA256 = $currentHash
    Applied = $false
    ProcessGuardApplied = $processGuardApplied
    SafeToEdit = ($blocking.Count -eq 0)
    BlockingProcesses = $blocking
    Changes = $changes
    BackupPath = $null
    NewSHA256 = $currentHash
}

if (-not $Apply -or $effectiveChanges.Count -eq 0) {
    Write-Result -Value $preview -Format $OutputFormat
    return
}

if ($blocking.Count -gt 0) {
    $names = ($blocking | ForEach-Object { "$($_.ProcessName) ($($_.Id))" }) -join ', '
    throw "Close iRacing UI and simulator processes before editing: $names"
}

$newText = $lines -join $file.NewLine
$directory = Split-Path -Parent $RendererPath
$leaf = Split-Path -Leaf $RendererPath
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$backupPath = Join-Path $directory "$leaf.backup-$stamp"
$temporaryPath = Join-Path $directory ".$leaf.codex-$([guid]::NewGuid().ToString('N')).tmp"

try {
    [System.IO.File]::WriteAllText($temporaryPath, $newText, $file.Encoding)
    [System.IO.File]::Replace($temporaryPath, $RendererPath, $backupPath, $true)
}
finally {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
}

$newHash = (Get-FileHash -LiteralPath $RendererPath -Algorithm SHA256).Hash
$result = [PSCustomObject]@{
    RendererPath = $RendererPath
    Section = $Section
    CurrentSHA256 = $currentHash
    Applied = $true
    ProcessGuardApplied = $processGuardApplied
    SafeToEdit = $true
    BlockingProcesses = @()
    Changes = $changes
    BackupPath = $backupPath
    NewSHA256 = $newHash
}
Write-Result -Value $result -Format $OutputFormat
