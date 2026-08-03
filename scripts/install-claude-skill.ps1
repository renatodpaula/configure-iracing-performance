<#
.SYNOPSIS
    Install this repository as a Claude skill on Windows.

.DESCRIPTION
    Default: create a directory junction so the installed skill always tracks the
    repository. Use -Copy for an independent snapshot of SKILL.md, references/
    and scripts/.
#>
[CmdletBinding()]
param(
    [ValidateSet('User', 'Project', 'Explicit')]
    [string]$Scope = 'User',
    [string]$ProjectPath,
    [string]$TargetRoot,
    [switch]$Copy,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$skillName = Split-Path -Leaf $repoRoot

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'SKILL.md'))) {
    throw "SKILL.md not found in $repoRoot"
}

switch ($Scope) {
    'User' {
        $configRoot = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
        $TargetRoot = Join-Path $configRoot 'skills'
    }
    'Project' {
        if (-not $ProjectPath) { throw 'Scope Project requires -ProjectPath.' }
        $TargetRoot = Join-Path (Join-Path $ProjectPath '.claude') 'skills'
    }
    'Explicit' {
        if (-not $TargetRoot) { throw 'Scope Explicit requires -TargetRoot.' }
    }
}

$target = Join-Path $TargetRoot $skillName

if (Test-Path -LiteralPath $target) {
    if (-not $Force) {
        throw "Already installed at $target. Re-run with -Force to replace it."
    }

    $existing = Get-Item -LiteralPath $target -Force
    if ($existing.LinkType) {
        $existing.Delete()
    }
    else {
        Remove-Item -LiteralPath $target -Recurse -Force
    }
}

New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null

if ($Copy) {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    foreach ($item in @('SKILL.md', 'references', 'scripts')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $item) -Destination $target -Recurse -Force
    }
    Write-Host "Copied SKILL.md, references/ and scripts/ to $target"
}
else {
    New-Item -ItemType Junction -Path $target -Target $repoRoot | Out-Null
    Write-Host "Linked $target -> $repoRoot"
}

Write-Host "Invoke it in Claude Code with /$skillName"
