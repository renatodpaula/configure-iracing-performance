[CmdletBinding()]
param(
    [string]$RendererPath,
    [ValidateSet('monitor', 'openxr', 'openvr', 'oculus')]
    [string]$DisplayMode = 'monitor',
    [ValidateSet('Object', 'Json')]
    [string]$OutputFormat = 'Json',
    [switch]$SkipHardware
)

$ErrorActionPreference = 'Stop'

function Get-IniSections {
    param([Parameter(Mandatory)][string]$Path)

    $sections = [ordered]@{}
    $currentSection = '__root__'
    $sections[$currentSection] = [ordered]@{}

    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*\[([^\]]+)\]\s*(?:;.*)?$') {
            $currentSection = $matches[1].Trim()
            if (-not $sections.Contains($currentSection)) {
                $sections[$currentSection] = [ordered]@{}
            }
            continue
        }

        if ($line -match '^\s*([^=;]+?)\s*=\s*([^;\r\n]*)(?:;.*)?$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $sections[$currentSection][$key] = $value
        }
    }

    return $sections
}

function Get-IniSection {
    param(
        [Parameter(Mandatory)]$Sections,
        [Parameter(Mandatory)][string[]]$Names
    )

    foreach ($name in $Names) {
        $actualName = @($Sections.Keys | Where-Object { $_ -ieq $name } | Select-Object -First 1)
        if ($actualName.Count -gt 0) {
            return $Sections[$actualName[0]]
        }
    }

    return $null
}

function Select-IniKeys {
    param(
        $Section,
        [Parameter(Mandatory)][string[]]$Keys
    )

    $selected = [ordered]@{}
    if ($null -eq $Section) {
        return [PSCustomObject]$selected
    }

    foreach ($key in $Keys) {
        $actualKey = @($Section.Keys | Where-Object { $_ -ieq $key } | Select-Object -First 1)
        if ($actualKey.Count -gt 0) {
            $selected[$actualKey[0]] = $Section[$actualKey[0]]
        }
    }

    return [PSCustomObject]$selected
}

function Get-ProcessValue {
    param($Process, [string]$PropertyName)

    try {
        return $Process.$PropertyName
    }
    catch {
        return $null
    }
}

$documents = [Environment]::GetFolderPath('MyDocuments')
$iracingDocuments = Join-Path $documents 'iRacing'
$rendererFiles = @{
    monitor = 'rendererDX11Monitor.ini'
    openxr = 'rendererDX11OpenXR.ini'
    openvr = 'rendererDX11OpenVR.ini'
    oculus = 'rendererDX11Oculus.ini'
}
$expectedRendererFile = $rendererFiles[$DisplayMode]

if (-not $RendererPath) {
    $RendererPath = Join-Path $iracingDocuments $expectedRendererFile
    if (-not (Test-Path -LiteralPath $RendererPath)) {
        $available = @(
            Get-ChildItem -LiteralPath $iracingDocuments -Filter 'rendererDX11*.ini' -File -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Name
        )
        $availableText = if ($available.Count -gt 0) { $available -join ', ' } else { 'none' }
        throw "Expected renderer not found for display mode '$DisplayMode': $RendererPath. Available renderer files: $availableText"
    }
}

if (-not (Test-Path -LiteralPath $RendererPath -PathType Leaf)) {
    throw "Renderer file not found: $RendererPath"
}

$RendererPath = (Resolve-Path -LiteralPath $RendererPath).Path
$warnings = @()
$rendererMatchesDisplayMode = ([System.IO.Path]::GetFileName($RendererPath) -ieq $expectedRendererFile)
if (-not $rendererMatchesDisplayMode) {
    $warnings += "Renderer filename does not match display mode '$DisplayMode'. Expected '$expectedRendererFile'."
}

$sections = Get-IniSections -Path $RendererPath
$drivingSection = Get-IniSection -Sections $sections -Names @('Graphics Options')
$replaySection = Get-IniSection -Sections $sections -Names @('Replay Graphics', 'Replay Options')
$displaySection = Get-IniSection -Sections $sections -Names @('Display')
$monitorSection = Get-IniSection -Sections $sections -Names @('MonitorSetup', 'Monitor Setup')
$openXrSection = Get-IniSection -Sections $sections -Names @('OpenXR', 'openXR')

if ($null -eq $drivingSection) {
    $warnings += "Section [Graphics Options] was not found. Driving graphics cannot be diagnosed safely."
}
if ($null -eq $replaySection) {
    $warnings += "Replay graphics section was not found. Replay values are unavailable."
}

$graphicsKeys = @(
    'VirtualMirrors', 'VRMode', 'MSAAUseFilter', 'MSAASamples', 'AntiAliasMethod',
    'FSRSharpness', 'SSRLevel', 'SSRRainOnly', 'SSAO', 'ResolutionScaling',
    'FoliageDetail', 'SysMemToUseMB', 'VidMemToUseMB', 'NvReflexMode',
    'LowQualityTrees', 'AllowTSOSelfShadows', 'DNSMFilter', 'DNSMNumLights',
    'DNSMWallsCastShadows', 'DNSMTSOsCastShadows', 'DNSMEnable', 'TwoPassTrees',
    'NumFixedCubemaps', 'NumDynamicCubemaps', 'Distortion', 'Sharpening',
    'MotionBlurDrivingCams', 'MotionBlurStrength', 'HeatHaze', 'DepthOfField',
    'ShadowMapType', 'DynamicShadowMaps', 'ShadowDetail', 'MaxCockpitMirrors',
    'MirrorDetail', 'ParticlesFullRes', 'ParticleDetail', 'WeekendDetail',
    'ObjectDetail', 'GrandstandDetail', 'CrowdDetail', 'PitObjectDetail',
    'CarDetail', 'SkyRefreshRate', 'LODMinFPSTarget', 'MaxPitObjsToDrawInMirrors',
    'MaxPitObjsToDraw', 'MaxCarsToDrawInMirrors', 'MaxCarsToDraw', 'EnableHDR',
    'DynamicShadowRes', 'ShaderQuality', 'HeadlightLevel', 'HeadlightsInMirrors',
    'CarPaint2048x2048', 'MipLODBias', 'LimitFrameRate', 'DesiredFPSLimit',
    'MaxPreRenderedFrames', 'VerticalSync'
)
$displayKeys = @(
    'border', 'deviceIdx', 'fullScreen', 'fullScreenDepth', 'fullScreenHeight',
    'fullScreenWidth', 'HDRFormat', 'RefreshRate', 'windowedHeight',
    'windowedMaximized', 'windowedWidth', 'windowedXPos', 'windowedYPos'
)
$monitorKeys = @(
    'MonitorType', 'RadiusOfCurvature', 'ViewingDist', 'BezelProtectionPct',
    'NumMonitors', 'EnableSMPSurround', 'RenderViewPerMonitor', 'MonitorWidth',
    'ScreenWidth', 'ScreenAngles'
)

$allProcesses = @(
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -like 'iRacing*' } |
        ForEach-Object {
            [PSCustomObject]@{
                ProcessName = $_.ProcessName
                Id = $_.Id
                CPUSeconds = Get-ProcessValue -Process $_ -PropertyName 'CPU'
                WorkingSetBytes = Get-ProcessValue -Process $_ -PropertyName 'WorkingSet64'
                StartTime = Get-ProcessValue -Process $_ -PropertyName 'StartTime'
            }
        }
)
$blockingProcesses = @(
    $allProcesses | Where-Object {
        $_.ProcessName -ieq 'iRacingUI' -or $_.ProcessName -imatch '^iRacingSim'
    }
)

$processor = @()
$memoryGb = $null
$videoControllers = @()
$nvidiaSnapshot = @()

if (-not $SkipHardware) {
    try {
        $processor = @(
            Get-CimInstance Win32_Processor |
                Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
        )
        $computerSystem = Get-CimInstance Win32_ComputerSystem
        $memoryGb = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 1)
    }
    catch {
        $warnings += "CPU or memory query unavailable: $($_.Exception.Message)"
    }

    try {
        $videoControllers = @(
            Get-CimInstance Win32_VideoController |
                Select-Object Name, DriverVersion, AdapterRAM, CurrentHorizontalResolution,
                    CurrentVerticalResolution, CurrentRefreshRate
        )
    }
    catch {
        $warnings += "Display query unavailable: $($_.Exception.Message)"
    }

    $nvidiaSmi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if ($nvidiaSmi) {
        $gpuRows = @(
            & $nvidiaSmi.Source --query-gpu=name,utilization.gpu,power.draw,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits
        )
        if ($LASTEXITCODE -eq 0) {
            $nvidiaSnapshot = @(
                foreach ($row in $gpuRows) {
                    $parts = @($row -split ',' | ForEach-Object { $_.Trim() })
                    if ($parts.Count -ge 6) {
                        [PSCustomObject]@{
                            Name = $parts[0]
                            UtilizationPercent = $parts[1]
                            PowerWatts = $parts[2]
                            TemperatureC = $parts[3]
                            MemoryUsedMiB = $parts[4]
                            MemoryTotalMiB = $parts[5]
                        }
                    }
                }
            )
        }
        else {
            $warnings += "nvidia-smi returned exit code $LASTEXITCODE."
        }
    }
}

$rendererItem = Get-Item -LiteralPath $RendererPath
$result = [PSCustomObject]@{
    Renderer = [PSCustomObject]@{
        Path = $RendererPath
        DisplayMode = $DisplayMode
        ExpectedFile = $expectedRendererFile
        MatchesDisplayMode = $rendererMatchesDisplayMode
        LastWriteTime = $rendererItem.LastWriteTime
        SHA256 = (Get-FileHash -LiteralPath $RendererPath -Algorithm SHA256).Hash
    }
    Processes = [PSCustomObject]@{
        All = $allProcesses
        Blocking = $blockingProcesses
        SafeToEdit = ($blockingProcesses.Count -eq 0)
    }
    Hardware = [PSCustomObject]@{
        Processor = $processor
        MemoryGB = $memoryGb
        VideoControllers = $videoControllers
        NvidiaSnapshot = $nvidiaSnapshot
        SnapshotNote = 'GPU utilization is instantaneous supporting evidence, not a standalone bottleneck diagnosis.'
    }
    Config = [PSCustomObject]@{
        DrivingGraphics = Select-IniKeys -Section $drivingSection -Keys $graphicsKeys
        ReplayGraphics = Select-IniKeys -Section $replaySection -Keys $graphicsKeys
        Display = Select-IniKeys -Section $displaySection -Keys $displayKeys
        MonitorSetup = Select-IniKeys -Section $monitorSection -Keys $monitorKeys
        OpenXR = if ($null -ne $openXrSection) { [PSCustomObject]$openXrSection } else { [PSCustomObject][ordered]@{} }
        SectionNames = @($sections.Keys)
    }
    Warnings = @($warnings)
}

if ($OutputFormat -eq 'Json') {
    $result | ConvertTo-Json -Depth 8
}
else {
    $result
}
