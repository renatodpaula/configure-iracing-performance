<#
.SYNOPSIS
    Capture a window of iRacing frame times with PresentMon (or reduce an existing PresentMon
    CSV) and emit percentile statistics: median/avg FPS, 1% low, 0.1% low, frame-time
    percentiles, frame-time standard deviation, and CPU/GPU-busy means when available.

.DESCRIPTION
    Closes the "measured experiment" loop the skill assumes: instead of hand-reading the
    in-sim R/G/T meters, this records objective per-frame data for a fixed window and
    reduces it to the ranges/percentiles that compare-runs.ps1 judges against.

    Two modes:
      - Capture (default): run PresentMon against the sim for -DurationSeconds.
        Requires an ELEVATED terminal (PresentMon opens a realtime ETW session),
        PresentMon on PATH / beside this script / via -PresentMonPath, and iRacing
        actively presenting frames.
      - Reduce (-FromCsv <path>): reduce an existing PresentMon CSV. No elevation,
        no capture, no running sim required. Useful to re-reduce a kept capture or a
        CSV recorded elsewhere.

    Column mapping (PresentMon -> iRacing meters):
      FrameTime / msBetweenPresents -> T (total frame time)
      CPUBusy                       -> R (renderer/CPU frame time)
      GPUBusy / msGPUActive         -> G (GPU frame time)

    Nothing is written to any iRacing configuration file. Output goes only to -OutDir.

.EXAMPLE
    scripts/measure-frametime.ps1 -Label baseline-1 -DurationSeconds 60
.EXAMPLE
    scripts/measure-frametime.ps1 -Label baseline-1 -FromCsv .\baseline-1.raw.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Label,
    [string]$ProcessName = 'iRacingSim64DX11.exe',
    [ValidateRange(1, 3600)][int]$DurationSeconds = 60,
    [ValidateRange(0, 120)][int]$WarmupSeconds = 5,
    [string]$FromCsv,
    [string]$OutDir,
    [string]$PresentMonPath,
    [switch]$KeepCsv,
    [ValidateSet('Object', 'Json')]
    [string]$OutputFormat = 'Json'
)

$ErrorActionPreference = 'Stop'
$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$reduceOnly = -not [string]::IsNullOrWhiteSpace($FromCsv)

function Write-Result {
    param($Value, [string]$Format)
    if ($Format -eq 'Json') { $Value | ConvertTo-Json -Depth 6 } else { $Value }
}

function ConvertTo-InvariantDouble {
    param([string]$Text)
    $out = 0.0
    $styles = [System.Globalization.NumberStyles]::Float
    if ([double]::TryParse($Text, $styles, $invariant, [ref]$out)) { return $out }
    return $null
}

function Get-Percentile {
    # $Sorted must be ascending. Linear interpolation between closest ranks.
    param([Parameter(Mandatory)][double[]]$Sorted, [Parameter(Mandatory)][double]$Percentile)
    $n = $Sorted.Length
    if ($n -eq 0) { return $null }
    if ($n -eq 1) { return $Sorted[0] }
    $rank = ($Percentile / 100.0) * ($n - 1)
    $low = [math]::Floor($rank)
    $high = [math]::Ceiling($rank)
    if ($low -eq $high) { return $Sorted[[int]$rank] }
    $frac = $rank - $low
    return ($Sorted[[int]$low] * (1.0 - $frac)) + ($Sorted[[int]$high] * $frac)
}

function Get-FirstColumn {
    param([string[]]$Available, [string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        $match = $Available | Where-Object { $_ -ieq $candidate } | Select-Object -First 1
        if ($match) { return $match }
    }
    return $null
}

# --- Resolve output location (both modes) ------------------------------------
if (-not $OutDir) {
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $OutDir = Join-Path (Join-Path $documents 'iRacing') 'perf-runs'
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path
$safeLabel = ($Label -replace '[^\w.\-]', '_')
$jsonPath = Join-Path $OutDir "$safeLabel.json"

if ($reduceOnly) {
    # --- Reduce an existing CSV ----------------------------------------------
    if (-not (Test-Path -LiteralPath $FromCsv -PathType Leaf)) {
        throw "CSV not found: $FromCsv"
    }
    $csvPath = (Resolve-Path -LiteralPath $FromCsv).Path
    $PresentMonPath = $null
}
else {
    # --- Capture with PresentMon ---------------------------------------------
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "PresentMon needs an elevated ETW session. Re-run this script from a terminal started with 'Run as administrator', or reduce an existing capture with -FromCsv."
    }

    $processLeaf = [System.IO.Path]::GetFileNameWithoutExtension($ProcessName)
    $targets = @(Get-Process -Name $processLeaf -ErrorAction SilentlyContinue)
    if ($targets.Count -eq 0) {
        throw "Target process '$ProcessName' is not running. Launch iRacing into a session that is actively rendering, then measure."
    }

    # Locate PresentMon: explicit path, then beside this script, then PATH.
    $scriptDir = Split-Path -Parent $PSCommandPath
    if (-not $PresentMonPath) {
        $localMatch = Get-ChildItem -LiteralPath $scriptDir -Filter 'PresentMon*.exe' -File -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($localMatch) {
            $PresentMonPath = $localMatch.FullName
        }
        else {
            $onPath = Get-Command 'PresentMon.exe' -ErrorAction SilentlyContinue
            if (-not $onPath) {
                $onPath = Get-Command 'PresentMon*' -ErrorAction SilentlyContinue | Select-Object -First 1
            }
            if ($onPath) { $PresentMonPath = $onPath.Source }
        }
    }
    if (-not $PresentMonPath -or -not (Test-Path -LiteralPath $PresentMonPath -PathType Leaf)) {
        throw "PresentMon.exe not found. Download it from https://github.com/GameTechDev/PresentMon/releases and pass -PresentMonPath, place it beside this script, or add it to PATH."
    }
    $PresentMonPath = (Resolve-Path -LiteralPath $PresentMonPath).Path

    $csvPath = Join-Path $OutDir "$safeLabel.raw.csv"
    if (Test-Path -LiteralPath $csvPath) { Remove-Item -LiteralPath $csvPath -Force }

    # Flags used here are supported across PresentMon 1.6+ and 2.x.
    $pmArgs = @(
        '--process_name', $ProcessName,
        '--output_file', $csvPath,
        '--timed', "$DurationSeconds",
        '--terminate_after_timed',
        '--stop_existing_session'
    )
    if ($WarmupSeconds -gt 0) { $pmArgs += @('--delay', "$WarmupSeconds") }

    & $PresentMonPath @pmArgs 2>&1 | Out-Null
    $pmExit = $LASTEXITCODE

    if (-not (Test-Path -LiteralPath $csvPath -PathType Leaf)) {
        throw "PresentMon exited with code $pmExit and produced no capture. Confirm the terminal is elevated and '$ProcessName' is presenting frames."
    }
}

# --- Parse CSV (both modes) --------------------------------------------------
$rows = @(Import-Csv -LiteralPath $csvPath)
if ($rows.Count -eq 0) {
    if (-not $reduceOnly -and -not $KeepCsv) { Remove-Item -LiteralPath $csvPath -Force -ErrorAction SilentlyContinue }
    throw "Capture contained no frames. Increase -DurationSeconds or confirm the scene is actively rendering."
}

# Column resolution (robust to PresentMon 1.x vs 2.x naming).
$columns = @($rows[0].PSObject.Properties.Name)
$frameTimeCol = Get-FirstColumn -Available $columns -Candidates @('FrameTime', 'msBetweenPresents')
if (-not $frameTimeCol) {
    if (-not $reduceOnly -and -not $KeepCsv) { Remove-Item -LiteralPath $csvPath -Force -ErrorAction SilentlyContinue }
    throw "Could not find a frame-time column (FrameTime / msBetweenPresents). Columns present: $($columns -join ', ')"
}
$cpuBusyCol = Get-FirstColumn -Available $columns -Candidates @('CPUBusy')
$gpuBusyCol = Get-FirstColumn -Available $columns -Candidates @('GPUBusy', 'msGPUActive', 'GPUTime')
$frameTypeCol = Get-FirstColumn -Available $columns -Candidates @('FrameType')
$droppedCol = Get-FirstColumn -Available $columns -Candidates @('Dropped')

$frameTimes = [System.Collections.Generic.List[double]]::new()
$cpuBusy = [System.Collections.Generic.List[double]]::new()
$gpuBusy = [System.Collections.Generic.List[double]]::new()
$skippedRows = 0

foreach ($row in $rows) {
    # Skip generated/repeated frames (frame-generation builds) and dropped presents.
    if ($frameTypeCol) {
        $frameType = [string]$row.$frameTypeCol
        if ($frameType -and $frameType -notmatch '^(Application|NotSet)$') { $skippedRows++; continue }
    }
    if ($droppedCol) {
        $droppedValue = ConvertTo-InvariantDouble ([string]$row.$droppedCol)
        if ($null -ne $droppedValue -and $droppedValue -ge 1) { $skippedRows++; continue }
    }

    $ft = ConvertTo-InvariantDouble ([string]$row.$frameTimeCol)
    if ($null -eq $ft -or $ft -le 0) { $skippedRows++; continue }
    $frameTimes.Add($ft)

    if ($cpuBusyCol) {
        $c = ConvertTo-InvariantDouble ([string]$row.$cpuBusyCol)
        if ($null -ne $c -and $c -ge 0) { $cpuBusy.Add($c) }
    }
    if ($gpuBusyCol) {
        $g = ConvertTo-InvariantDouble ([string]$row.$gpuBusyCol)
        if ($null -ne $g -and $g -ge 0) { $gpuBusy.Add($g) }
    }
}

if ($frameTimes.Count -lt 2) {
    if (-not $reduceOnly -and -not $KeepCsv) { Remove-Item -LiteralPath $csvPath -Force -ErrorAction SilentlyContinue }
    throw "Too few valid frames ($($frameTimes.Count)) to compute statistics."
}

# --- Statistics --------------------------------------------------------------
$sorted = [double[]]@($frameTimes | Sort-Object)   # ascending frame times (ms)
$count = $sorted.Length
$sum = 0.0
foreach ($v in $sorted) { $sum += $v }
$mean = $sum / $count
$sumSq = 0.0
foreach ($v in $sorted) { $sumSq += [math]::Pow($v - $mean, 2) }
$stdDev = [math]::Sqrt($sumSq / $count)

$p50 = Get-Percentile -Sorted $sorted -Percentile 50
$p99 = Get-Percentile -Sorted $sorted -Percentile 99
$p999 = Get-Percentile -Sorted $sorted -Percentile 99.9
$minFt = $sorted[0]
$maxFt = $sorted[$count - 1]

# FPS from frame time (ms). Average FPS uses the mean frame time (== frames / total time).
# 1% / 0.1% low use the 99th / 99.9th percentile frame time (percentile method).
function ToFps { param([double]$Ms) if ($Ms -le 0) { return $null } return [math]::Round(1000.0 / $Ms, 2) }
function AvgOrNull {
    param([System.Collections.Generic.List[double]]$Values)
    if ($Values.Count -eq 0) { return $null }
    $s = 0.0; foreach ($v in $Values) { $s += $v }
    return [math]::Round($s / $Values.Count, 3)
}

$avgCpuBusy = AvgOrNull $cpuBusy
$avgGpuBusy = AvgOrNull $gpuBusy
$bound = $null
if ($null -ne $avgCpuBusy -and $null -ne $avgGpuBusy) {
    $bound = if ($avgGpuBusy -ge $avgCpuBusy) { 'GPU' } else { 'CPU' }
}

$stats = [PSCustomObject]@{
    Label                 = $Label
    ProcessName           = $ProcessName
    Source                = if ($reduceOnly) { 'csv' } else { 'presentmon' }
    DurationSeconds       = if ($reduceOnly) { $null } else { $DurationSeconds }
    WarmupSeconds         = if ($reduceOnly) { $null } else { $WarmupSeconds }
    SampleCount           = $count
    SkippedRows           = $skippedRows
    FrameTimeColumn       = $frameTimeCol
    AvgFPS                = ToFps $mean
    MedianFPS             = ToFps $p50
    OnePercentLowFPS      = ToFps $p99
    PointOnePercentLowFPS = ToFps $p999
    MaxFPS                = ToFps $minFt
    MinFPS                = ToFps $maxFt
    AvgFrameTimeMs        = [math]::Round($mean, 3)
    MedianFrameTimeMs     = [math]::Round($p50, 3)
    P99FrameTimeMs        = [math]::Round($p99, 3)
    P999FrameTimeMs       = [math]::Round($p999, 3)
    MaxFrameTimeMs        = [math]::Round($maxFt, 3)
    StdDevFrameTimeMs     = [math]::Round($stdDev, 3)
    AvgCpuBusyMs          = $avgCpuBusy   # ~ R meter
    AvgGpuBusyMs          = $avgGpuBusy   # ~ G meter
    LikelyBoundBy         = $bound
    PresentMonPath        = $PresentMonPath
    CsvPath               = if ($reduceOnly) { $csvPath } elseif ($KeepCsv) { $csvPath } else { $null }
    JsonPath              = $jsonPath
    Note                 = 'Percentile-method 1% / 0.1% lows: FPS derived from the 99th / 99.9th percentile frame time. AvgFPS = 1000 / mean frame time.'
}

$stats | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

if (-not $reduceOnly -and -not $KeepCsv -and (Test-Path -LiteralPath $csvPath)) {
    Remove-Item -LiteralPath $csvPath -Force -ErrorAction SilentlyContinue
}

Write-Result -Value $stats -Format $OutputFormat
