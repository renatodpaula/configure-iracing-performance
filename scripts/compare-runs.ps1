<#
.SYNOPSIS
    Judge a candidate capture against a baseline natural-variance envelope and suggest
    keep / revert / inconclusive, per the decision rules in references/metrics.md.

.DESCRIPTION
    Consumes JSON produced by measure-frametime.ps1. Builds a natural-variance envelope
    from one or more baseline windows (two or more strongly recommended), then classifies
    the candidate for the chosen objective. Only the MEASURED side is decided here; when a
    visual or latency trade-off is in play (-ChangeType quality-up), HumanJudgmentRequired
    is set so the driver makes the final call.

    A metric moves "meaningfully" only when the candidate falls outside the baseline
    envelope widened by -NoiseMarginPct. Overlap counts as noise, matching the skill's
    "do not decide from a one- or two-FPS shift" guardrail.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/compare-runs.ps1 `
      -Baseline runs/baseline-1.json,runs/baseline-2.json -Candidate runs/cap-90.json `
      -Objective balanced -TargetFPS 90 -ChangeType quality-up
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Baseline,
    [Parameter(Mandatory)][string]$Candidate,
    [ValidateSet('visual-immersion', 'balanced', 'consistency')]
    [string]$Objective = 'balanced',
    [double]$TargetFPS,
    [double]$MinAcceptableFPS,
    [ValidateSet('quality-up', 'performance-up', 'neutral')]
    [string]$ChangeType = 'neutral',
    [ValidateRange(0, 25)][double]$NoiseMarginPct = 2,
    [ValidateSet('Object', 'Json')]
    [string]$OutputFormat = 'Json'
)

$ErrorActionPreference = 'Stop'

function Write-Result {
    param($Value, [string]$Format)
    if ($Format -eq 'Json') { $Value | ConvertTo-Json -Depth 6 } else { $Value }
}

function Import-Stats {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Stats file not found: $Path"
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

# Direction of a candidate value relative to the baseline envelope, widened by margin.
function Get-Direction {
    param(
        [Parameter(Mandatory)][double[]]$BaselineValues,
        [Parameter(Mandatory)][double]$CandidateValue,
        [Parameter(Mandatory)][bool]$HigherIsBetter,
        [Parameter(Mandatory)][double]$MarginPct
    )
    $min = ($BaselineValues | Measure-Object -Minimum).Minimum
    $max = ($BaselineValues | Measure-Object -Maximum).Maximum
    $mean = ($BaselineValues | Measure-Object -Average).Average
    $margin = [math]::Abs($mean) * ($MarginPct / 100.0)

    if ($CandidateValue -gt ($max + $margin)) { $moved = 'higher' }
    elseif ($CandidateValue -lt ($min - $margin)) { $moved = 'lower' }
    else { $moved = 'within-variance' }

    $verdict = switch ($moved) {
        'within-variance' { 'inconclusive' }
        'higher' { if ($HigherIsBetter) { 'better' } else { 'worse' } }
        'lower' { if ($HigherIsBetter) { 'worse' } else { 'better' } }
    }

    $deltaAbs = $CandidateValue - $mean
    $deltaPct = if ($mean -ne 0) { [math]::Round(($deltaAbs / [math]::Abs($mean)) * 100, 2) } else { $null }

    return [PSCustomObject]@{
        BaselineMin    = [math]::Round($min, 3)
        BaselineMax    = [math]::Round($max, 3)
        BaselineMean   = [math]::Round($mean, 3)
        CandidateValue = [math]::Round($CandidateValue, 3)
        DeltaAbs       = [math]::Round($deltaAbs, 3)
        DeltaPct       = $deltaPct
        Moved          = $moved
        Verdict        = $verdict
        HigherIsBetter = $HigherIsBetter
    }
}

# --- Load ---------------------------------------------------------------------
$baselineStats = @($Baseline | ForEach-Object { Import-Stats -Path $_ })
$candidateStats = Import-Stats -Path $Candidate

$metricDefs = @(
    [PSCustomObject]@{ Name = 'AvgFPS'; HigherIsBetter = $true },
    [PSCustomObject]@{ Name = 'OnePercentLowFPS'; HigherIsBetter = $true },
    [PSCustomObject]@{ Name = 'PointOnePercentLowFPS'; HigherIsBetter = $true },
    [PSCustomObject]@{ Name = 'StdDevFrameTimeMs'; HigherIsBetter = $false },
    [PSCustomObject]@{ Name = 'P999FrameTimeMs'; HigherIsBetter = $false }
)

$metrics = [ordered]@{}
foreach ($def in $metricDefs) {
    $baselineValues = @(
        $baselineStats | ForEach-Object { $_.$($def.Name) } | Where-Object { $null -ne $_ } | ForEach-Object { [double]$_ }
    )
    $candidateValue = $candidateStats.$($def.Name)
    if ($baselineValues.Count -eq 0 -or $null -eq $candidateValue) { continue }
    $metrics[$def.Name] = Get-Direction -BaselineValues $baselineValues -CandidateValue ([double]$candidateValue) `
        -HigherIsBetter $def.HigherIsBetter -MarginPct $NoiseMarginPct
}

# --- Objective-specific decision ---------------------------------------------
$floor = if ($PSBoundParameters.ContainsKey('MinAcceptableFPS')) { $MinAcceptableFPS }
elseif ($PSBoundParameters.ContainsKey('TargetFPS')) { $TargetFPS }
else { $null }

switch ($Objective) {
    'consistency' { $primaryName = 'StdDevFrameTimeMs' }
    default { $primaryName = 'OnePercentLowFPS' }   # visual-immersion and balanced
}
$primary = $metrics[$primaryName]

# Does the candidate's low end still satisfy the target/floor?
$candidateOnePercentLow = $candidateStats.OnePercentLowFPS
$targetMet = $null
if ($null -ne $floor -and $null -ne $candidateOnePercentLow) {
    $targetMet = ([double]$candidateOnePercentLow -ge [double]$floor)
}

$humanJudgmentRequired = ($ChangeType -eq 'quality-up')
$rationaleParts = @()

if ($null -eq $primary) {
    $suggested = 'inconclusive'
    $rationaleParts += "Primary metric '$primaryName' was not comparable across the runs."
}
else {
    switch ($primary.Verdict) {
        'inconclusive' {
            $suggested = 'inconclusive'
            $rationaleParts += "$primaryName stayed within the baseline variance envelope (+/- $NoiseMarginPct%)."
        }
        'better' {
            if ($ChangeType -eq 'quality-up' -and $targetMet -eq $false) {
                $suggested = 'revert'
                $rationaleParts += "$primaryName improved but the candidate's 1% low fell below the target/floor."
            }
            else {
                $suggested = 'keep'
                $rationaleParts += "$primaryName moved meaningfully toward the objective."
            }
        }
        'worse' {
            if ($ChangeType -eq 'quality-up' -and $targetMet -eq $true) {
                # A visual-up change is expected to cost some FPS; keep as long as the floor holds.
                $suggested = 'keep'
                $rationaleParts += "$primaryName dropped (expected for a quality-up change) but the 1% low still satisfies the target/floor; confirm the visual gain is worth it."
            }
            else {
                $suggested = 'revert'
                $rationaleParts += "$primaryName regressed meaningfully" + $(if ($targetMet -eq $false) { " and the 1% low is below the target/floor." } else { "." })
            }
        }
    }
}

if ($null -ne $targetMet) {
    $rationaleParts += $(if ($targetMet) { "Target/floor met at the 1% low." } else { "Target/floor NOT met at the 1% low." })
    if ($targetMet -eq $false -and $suggested -eq 'keep') {
        # Never certify a target the low end fails, regardless of averages.
        $suggested = 'revert'
        $rationaleParts += "Overriding to revert: the low end does not satisfy the target."
    }
}

$performanceVerdict = if ($null -ne $primary) {
    switch ($primary.Verdict) { 'better' { 'improved' } 'worse' { 'regressed' } default { 'inconclusive' } }
}
else { 'inconclusive' }

$confidenceNote = if ($baselineStats.Count -lt 2) {
    "Only $($baselineStats.Count) baseline window supplied; the variance envelope is weak. Capture at least two baselines for a trustworthy verdict."
}
else { $null }

$result = [PSCustomObject]@{
    Objective             = $Objective
    ChangeType            = $ChangeType
    TargetFPS             = if ($PSBoundParameters.ContainsKey('TargetFPS')) { $TargetFPS } else { $null }
    MinAcceptableFPS      = if ($PSBoundParameters.ContainsKey('MinAcceptableFPS')) { $MinAcceptableFPS } else { $null }
    FloorUsedFPS          = $floor
    NoiseMarginPct        = $NoiseMarginPct
    BaselineCount         = $baselineStats.Count
    BaselineLabels        = @($baselineStats | ForEach-Object { $_.Label })
    CandidateLabel        = $candidateStats.Label
    PrimaryMetric         = $primaryName
    PrimaryVerdict        = if ($primary) { $primary.Verdict } else { $null }
    PerformanceVerdict    = $performanceVerdict
    TargetMet             = $targetMet
    SuggestedDecision     = $suggested
    HumanJudgmentRequired = $humanJudgmentRequired
    Rationale             = ($rationaleParts -join ' ')
    ConfidenceNote        = $confidenceNote
    Metrics               = $metrics
    Note                 = 'Measured side only. When HumanJudgmentRequired is true, the driver decides whether the visual/latency trade-off justifies the FPS change.'
}

Write-Result -Value $result -Format $OutputFormat
