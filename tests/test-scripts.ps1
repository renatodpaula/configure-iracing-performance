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

# --- measure-frametime.ps1 (CSV reduction) and compare-runs.ps1 --------------
$measure = Join-Path $root 'scripts\measure-frametime.ps1'
$compare = Join-Path $root 'scripts\compare-runs.ps1'
$csvFixture = Join-Path $PSScriptRoot 'fixtures\presentmon-sample.csv'

$measureDir = Join-Path ([System.IO.Path]::GetTempPath()) "iracing-measure-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $measureDir | Out-Null
try {
    $stats = & $measure -Label sample -FromCsv $csvFixture -OutDir $measureDir -OutputFormat Object
    Assert-Equal $stats.SampleCount 9 'measure-frametime miscounted valid frames.'
    Assert-Equal $stats.SkippedRows 2 'measure-frametime did not skip dropped/repeated frames.'
    Assert-Equal $stats.FrameTimeColumn 'FrameTime' 'measure-frametime picked the wrong frame-time column.'
    Assert-Equal $stats.MedianFPS 100 'measure-frametime median FPS is wrong.'
    Assert-Equal $stats.AvgFPS 90 'measure-frametime average FPS is wrong.'
    Assert-Equal $stats.LikelyBoundBy 'GPU' 'measure-frametime bound attribution is wrong.'
    Assert-True (Test-Path -LiteralPath $csvFixture) 'measure-frametime deleted the source CSV in reduce mode.'

    function Save-Stats {
        param([string]$Name, [double]$Avg, [double]$P1, [double]$P01, [double]$Std, [double]$P999)
        $obj = [PSCustomObject]@{
            Label = $Name; AvgFPS = $Avg; OnePercentLowFPS = $P1
            PointOnePercentLowFPS = $P01; StdDevFrameTimeMs = $Std; P999FrameTimeMs = $P999
        }
        $path = Join-Path $measureDir "$Name.json"
        $obj | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
        return $path
    }
    $b1 = Save-Stats 'baseline-1' 100 95 90 1.0 11.5
    $b2 = Save-Stats 'baseline-2' 101 96 91 1.1 11.8
    $candKeep = Save-Stats 'cand-keep' 96 92 88 1.2 12.5     # quality-up drop, still above target
    $candRevert = Save-Stats 'cand-revert' 92 87 82 1.4 13.0 # below target
    $candNoise = Save-Stats 'cand-noise' 100 95.5 90.5 1.05 11.6
    $candSmooth = Save-Stats 'cand-smooth' 99 94 89 0.6 9.5  # consistency win

    $keep = & $compare -Baseline @($b1, $b2) -Candidate $candKeep -Objective balanced -TargetFPS 90 -ChangeType quality-up -OutputFormat Object
    Assert-Equal $keep.SuggestedDecision 'keep' 'compare-runs should keep a quality-up change that holds the target.'
    Assert-Equal $keep.TargetMet $true 'compare-runs target-met check failed for the keep case.'
    Assert-Equal $keep.HumanJudgmentRequired $true 'compare-runs should flag human judgment for a quality-up change.'

    $revert = & $compare -Baseline @($b1, $b2) -Candidate $candRevert -Objective balanced -TargetFPS 90 -ChangeType quality-up -OutputFormat Object
    Assert-Equal $revert.SuggestedDecision 'revert' 'compare-runs should revert when the 1% low falls below target.'
    Assert-Equal $revert.TargetMet $false 'compare-runs should report target not met for the revert case.'

    $noise = & $compare -Baseline @($b1, $b2) -Candidate $candNoise -Objective balanced -TargetFPS 90 -ChangeType neutral -OutputFormat Object
    Assert-Equal $noise.SuggestedDecision 'inconclusive' 'compare-runs should treat within-variance shifts as inconclusive.'

    $smooth = & $compare -Baseline @($b1, $b2) -Candidate $candSmooth -Objective consistency -TargetFPS 90 -ChangeType performance-up -OutputFormat Object
    Assert-Equal $smooth.SuggestedDecision 'keep' 'compare-runs should keep a meaningful consistency improvement.'

    $singleBaseline = & $compare -Baseline @($b1) -Candidate $candNoise -Objective balanced -TargetFPS 90 -OutputFormat Object
    Assert-True (-not [string]::IsNullOrWhiteSpace($singleBaseline.ConfidenceNote)) 'compare-runs should warn when only one baseline is provided.'
}
finally {
    if (Test-Path -LiteralPath $measureDir) {
        Remove-Item -LiteralPath $measureDir -Recurse -Force
    }
}

[PSCustomObject]@{
    Passed = $true
    Tests = @(
        'section-aware diagnosis',
        'structured JSON output',
        'performance-relevant process inventory',
        'process-review rationale',
        'missing renderer rejection',
        'dry-run integrity',
        'live-renderer process-guard scoping',
        'stale hash rejection',
        'unknown key rejection',
        'atomic update and backup',
        'driving/replay separation',
        'replay protection',
        'verified restore',
        'presentmon csv reduction',
        'measured decision: keep/revert/inconclusive',
        'consistency-objective decision',
        'single-baseline confidence warning'
    )
}
