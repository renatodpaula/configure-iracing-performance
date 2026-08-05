[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected' but found '$Actual'."
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

$root = Split-Path -Parent $PSScriptRoot
$diagnose = Join-Path $root 'scripts\diagnose.ps1'
$update = Join-Path $root 'scripts\update-renderer.ps1'
$restore = Join-Path $root 'scripts\restore-renderer.ps1'
$fixture = Join-Path $PSScriptRoot 'fixtures\renderer-sections.ini'
$diagnoseSource = Get-Content -Raw -LiteralPath $diagnose

Assert-True ($diagnoseSource -match "Category = 'SimulatorSupportControl'") 'Simulator-support process category is missing.'
Assert-True ($diagnoseSource -match "Pattern = '\^\(SimHub\.\*\)\$'") 'SimHub is not classified as simulator-support software.'
Assert-True ($diagnoseSource -match 'belt tensioners') 'Required SimHub hardware outputs are not documented in process rationale.'

$parsed = & $diagnose -RendererPath $fixture -DisplayMode monitor -OutputFormat Object -SkipHardware -ProcessSampleSeconds 0
Assert-Equal $parsed.Config.DrivingGraphics.MaxCarsToDraw '20' 'Driving and replay sections were mixed.'
Assert-Equal $parsed.Config.DrivingGraphics.SSAO '0' 'Driving SSAO is incorrect.'
Assert-Equal $parsed.Config.ReplayGraphics.MaxCarsToDraw '64' 'Replay maximum cars is incorrect.'
Assert-Equal $parsed.Config.ReplayGraphics.SSAO '1' 'Replay SSAO is incorrect.'
Assert-True ($null -ne $parsed.Processes.PerformanceRelevant) 'Performance-relevant process inventory is missing.'
Assert-True ($parsed.Processes.ReviewNote -match 'not proof') 'Process-review guardrail is missing.'
foreach ($candidate in $parsed.Processes.PerformanceRelevant) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($candidate.Rationale)) 'A process candidate lacks rationale.'
    Assert-True (-not [string]::IsNullOrWhiteSpace($candidate.ReviewQuestion)) 'A process candidate lacks a review question.'
}
$parsedJson = (& $diagnose -RendererPath $fixture -DisplayMode monitor -OutputFormat Json -SkipHardware -ProcessSampleSeconds 0) | ConvertFrom-Json
Assert-Equal $parsedJson.Config.DrivingGraphics.LODMinFPSTarget '144' 'JSON output lost the driving LOD target.'

$missingRendererWasRejected = $false
try {
    & $diagnose -RendererPath (Join-Path $PSScriptRoot 'fixtures\missing.ini') -DisplayMode monitor -OutputFormat Object -SkipHardware -ProcessSampleSeconds 0 | Out-Null
}
catch {
    $missingRendererWasRejected = $true
}
Assert-True $missingRendererWasRejected 'A missing renderer was not rejected.'

$testDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "configure-iracing-performance-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $testDirectory | Out-Null

try {
    $workingRenderer = Join-Path $testDirectory 'renderer-sections.ini'
    Copy-Item -LiteralPath $fixture -Destination $workingRenderer
    $originalHash = (Get-FileHash -LiteralPath $workingRenderer -Algorithm SHA256).Hash

    $preview = & $update -RendererPath $workingRenderer -Section 'Graphics Options' -Set 'MaxCarsToDraw=30' -ExpectedHash $originalHash -OutputFormat Object
    Assert-True (-not $preview.Applied) 'Dry-run unexpectedly changed the renderer.'
    Assert-True (-not $preview.ProcessGuardApplied) 'A temporary fixture was treated as the live renderer.'
    Assert-Equal (Get-FileHash -LiteralPath $workingRenderer -Algorithm SHA256).Hash $originalHash 'Dry-run changed file contents.'

    $staleHashWasRejected = $false
    try {
        & $update -RendererPath $workingRenderer -Section 'Graphics Options' -Set 'MaxCarsToDraw=30' -ExpectedHash ('0' * 64) -OutputFormat Object | Out-Null
    }
    catch {
        $staleHashWasRejected = $true
    }
    Assert-True $staleHashWasRejected 'A stale renderer hash was not rejected.'

    $unknownKeyWasRejected = $false
    try {
        & $update -RendererPath $workingRenderer -Section 'Graphics Options' -Set 'UnknownOption=1' -OutputFormat Object | Out-Null
    }
    catch {
        $unknownKeyWasRejected = $true
    }
    Assert-True $unknownKeyWasRejected 'An unknown key was created instead of rejected.'

    $applied = & $update -RendererPath $workingRenderer -Section 'Graphics Options' -Set 'MaxCarsToDraw=30' -ExpectedHash $originalHash -Apply -OutputFormat Object
    Assert-True $applied.Applied 'The requested renderer change was not applied.'
    Assert-True (Test-Path -LiteralPath $applied.BackupPath) 'The renderer backup was not created.'

    $changed = & $diagnose -RendererPath $workingRenderer -DisplayMode monitor -OutputFormat Object -SkipHardware -ProcessSampleSeconds 0
    Assert-Equal $changed.Config.DrivingGraphics.MaxCarsToDraw '30' 'Driving value was not updated.'
    Assert-Equal $changed.Config.ReplayGraphics.MaxCarsToDraw '64' 'Replay value changed with the driving value.'

    $replayWasProtected = $false
    try {
        & $update -RendererPath $workingRenderer -Section 'Replay Graphics' -Set 'MaxCarsToDraw=30' -OutputFormat Object | Out-Null
    }
    catch {
        $replayWasProtected = $true
    }
    Assert-True $replayWasProtected 'Replay changes were not protected by default.'

    $restored = & $restore -RendererPath $workingRenderer -BackupPath $applied.BackupPath -ExpectedHash $applied.NewSHA256 -Apply -OutputFormat Object
    Assert-True $restored.Applied 'The renderer backup was not restored.'
    Assert-True (-not $restored.ProcessGuardApplied) 'A temporary restore was treated as the live renderer.'
    Assert-Equal (Get-FileHash -LiteralPath $workingRenderer -Algorithm SHA256).Hash $originalHash 'Restored renderer does not match the original.'
}
finally {
    $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $resolvedTestDirectory = [System.IO.Path]::GetFullPath($testDirectory)
    if ($resolvedTestDirectory.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedTestDirectory)) {
        Remove-Item -LiteralPath $resolvedTestDirectory -Recurse -Force
    }
}

[PSCustomObject]@{
    Passed = $true
    Tests = @(
        'section-aware diagnosis',
        'structured JSON output',
        'performance-relevant process inventory',
        'process-review rationale',
        'required SimHub workload classification',
        'missing renderer rejection',
        'dry-run integrity',
        'live-renderer process-guard scoping',
        'stale hash rejection',
        'unknown key rejection',
        'atomic update and backup',
        'driving/replay separation',
        'replay protection',
        'verified restore'
    )
}
