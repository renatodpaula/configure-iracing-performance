[CmdletBinding()]
param(
    [string]$RendererPath,
    [ValidateSet('monitor', 'openxr', 'openvr', 'oculus')]
    [string]$DisplayMode = 'monitor',
    [ValidateSet('Object', 'Json')]
    [string]$OutputFormat = 'Json',
    [switch]$SkipHardware,
    [ValidateRange(0, 10)]
    [double]$ProcessSampleSeconds = 2
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

function Get-PerformanceRelevantProcesses {
    param([Parameter(Mandatory)][object[]]$RunningProcesses)

    $rules = @(
        [PSCustomObject]@{
            Category = 'CaptureOrStreaming'
            Pattern = '^(obs64|Streamlabs OBS|slobs|XSplit.*|Medal|NVIDIA Overlay|nvsphelper64|Overwolf|TwitchStudio|Bandicam)$'
            MinimumWorkingSetMB = 0
            Rationale = 'Capture and streaming software can consume render, copy, encode, memory, and disk resources.'
            ReviewQuestion = 'Is this software required for recording or streaming in the target setup?'
        },
        [PSCustomObject]@{
            Category = 'SimulatorSupportControl'
            Pattern = '^(SimHub.*)$'
            MinimumWorkingSetMB = 0
            Rationale = 'Simulator-support software may drive required dashboards, bass shakers, belt tensioners, motion, wind, LEDs, or telemetry consumers; preserve required functions and isolate only optional components.'
            ReviewQuestion = 'Which SimHub functions and outputs are required and must remain active for every measured session?'
        },
        [PSCustomObject]@{
            Category = 'OverlayOrTelemetry'
            Pattern = '^(RTSS|RTSSHooksLoader64|MSIAfterburner|Discord|Racelab.*|CrewChief.*|iOverlay.*|Kapps.*|TradingPaints.*|trophi.*|MarvinsAIRA)$'
            MinimumWorkingSetMB = 0
            Rationale = 'Overlays and telemetry tools can hook the renderer, poll hardware, or update frequently.'
            ReviewQuestion = 'Is this overlay, communication, or telemetry tool required while driving?'
        },
        [PSCustomObject]@{
            Category = 'HardwareOrRgbUtility'
            Pattern = '^(iCUE|Corsair.*|LightingService|ArmouryCrate.*|L-Connect.*|NZXT CAM|Razer.*|lghub.*|Logi.*|Fanatec.*|MOZA.*|AORUS.*|RGBFusion.*|Elgato.*|StreamDeck.*)$'
            MinimumWorkingSetMB = 0
            Rationale = 'Hardware and RGB utilities can use background CPU, but may be required for controls, audio, cooling, or lighting.'
            ReviewQuestion = 'Does this utility provide a required device or control function for the session?'
        },
        [PSCustomObject]@{
            Category = 'RemoteOrVirtualDisplay'
            Pattern = '^(Parsec|Sunshine|Moonlight|spacedesk.*|Duet.*|VirtualDesktop.*|Oculus.*|Meta.*|WinUsbDisplay|AnyDesk|TeamViewer.*)$'
            MinimumWorkingSetMB = 0
            Rationale = 'Remote and virtual-display software can change the presentation path or consume GPU copy and encode resources.'
            ReviewQuestion = 'Is this remote or virtual-display software required for the target display path?'
        },
        [PSCustomObject]@{
            Category = 'BrowserOrLauncher'
            Pattern = '^(chrome|msedge|firefox|steamwebhelper)$'
            MinimumWorkingSetMB = 500
            Rationale = 'Many browser or launcher processes can collectively use meaningful CPU, GPU, and memory.'
            ReviewQuestion = 'Are these browser or launcher processes needed during the measured session?'
        }
    )

    $candidates = @(
        foreach ($rule in $rules) {
            $matches = @($RunningProcesses | Where-Object { $_.ProcessName -match $rule.Pattern })
            foreach ($group in @($matches | Group-Object ProcessName)) {
                $workingSetBytes = 0
                $cpuSeconds = 0.0
                $ids = @()
                foreach ($process in $group.Group) {
                    $workingSet = Get-ProcessValue -Process $process -PropertyName 'WorkingSet64'
                    $cpu = Get-ProcessValue -Process $process -PropertyName 'CPU'
                    if ($null -ne $workingSet) {
                        $workingSetBytes += [int64]$workingSet
                    }
                    if ($null -ne $cpu) {
                        $cpuSeconds += [double]$cpu
                    }
                    $ids += $process.Id
                }

                $workingSetMB = [math]::Round($workingSetBytes / 1MB, 1)
                if ($workingSetMB -lt $rule.MinimumWorkingSetMB) {
                    continue
                }

                [PSCustomObject]@{
                    Category = $rule.Category
                    ProcessName = $group.Name
                    InstanceCount = $group.Count
                    Ids = @($ids)
                    WorkingSetMB = $workingSetMB
                    CumulativeCPUSeconds = [math]::Round($cpuSeconds, 2)
                    Rationale = $rule.Rationale
                    ReviewQuestion = $rule.ReviewQuestion
                }
            }
        }
    )

    return @($candidates | Sort-Object Category, ProcessName)
}

function Add-ProcessActivitySample {
    param(
        [Parameter(Mandatory)][object[]]$Candidates,
        [Parameter(Mandatory)][double]$DurationSeconds
    )

    $startingCpu = @{}
    if ($DurationSeconds -gt 0 -and $Candidates.Count -gt 0) {
        foreach ($id in @($Candidates.Ids | Select-Object -Unique)) {
            $process = Get-Process -Id $id -ErrorAction SilentlyContinue
            if ($null -ne $process) {
                $cpu = Get-ProcessValue -Process $process -PropertyName 'CPU'
                if ($null -ne $cpu) {
                    $startingCpu[$id] = [double]$cpu
                }
            }
        }
        Start-Sleep -Milliseconds ([int][math]::Round($DurationSeconds * 1000))
    }

    $sampled = @(
        foreach ($candidate in $Candidates) {
            $sampleCpuSeconds = 0.0
            if ($DurationSeconds -gt 0) {
                foreach ($id in $candidate.Ids) {
                    if (-not $startingCpu.ContainsKey($id)) {
                        continue
                    }
                    $process = Get-Process -Id $id -ErrorAction SilentlyContinue
                    if ($null -eq $process) {
                        continue
                    }
                    $endingCpu = Get-ProcessValue -Process $process -PropertyName 'CPU'
                    if ($null -ne $endingCpu) {
                        $sampleCpuSeconds += [math]::Max(0, ([double]$endingCpu - $startingCpu[$id]))
                    }
                }
            }

            [PSCustomObject]@{
                Category = $candidate.Category
                ProcessName = $candidate.ProcessName
                InstanceCount = $candidate.InstanceCount
                Ids = $candidate.Ids
                WorkingSetMB = $candidate.WorkingSetMB
                CumulativeCPUSeconds = $candidate.CumulativeCPUSeconds
                SampleDurationSeconds = $DurationSeconds
                SampleCPUSeconds = if ($DurationSeconds -gt 0) { [math]::Round($sampleCpuSeconds, 3) } else { $null }
                ApproxOneCorePercent = if ($DurationSeconds -gt 0) {
                    [math]::Round(($sampleCpuSeconds / $DurationSeconds) * 100, 1)
                }
                else {
                    $null
                }
                Rationale = $candidate.Rationale
                ReviewQuestion = $candidate.ReviewQuestion
            }
        }
    )

    return $sampled
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

$runningProcesses = @(Get-Process -ErrorAction SilentlyContinue)
$allProcesses = @(
    $runningProcesses |
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
$performanceRelevantProcesses = @(
    Add-ProcessActivitySample `
        -Candidates @(Get-PerformanceRelevantProcesses -RunningProcesses $runningProcesses) `
        -DurationSeconds $ProcessSampleSeconds
)
$topProcessesByWorkingSet = @(
    $runningProcesses |
        Where-Object { $_.ProcessName -notmatch '^(Idle|System|Memory Compression)$' } |
        Group-Object ProcessName |
        ForEach-Object {
            $workingSetBytes = 0
            foreach ($process in $_.Group) {
                $workingSet = Get-ProcessValue -Process $process -PropertyName 'WorkingSet64'
                if ($null -ne $workingSet) {
                    $workingSetBytes += [int64]$workingSet
                }
            }
            [PSCustomObject]@{
                ProcessName = $_.Name
                InstanceCount = $_.Count
                WorkingSetMB = [math]::Round($workingSetBytes / 1MB, 1)
            }
        } |
        Sort-Object WorkingSetMB -Descending |
        Select-Object -First 10
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
            & $nvidiaSmi.Source --query-gpu=name,utilization.gpu,utilization.encoder,power.draw,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits
        )
        if ($LASTEXITCODE -eq 0) {
            $nvidiaSnapshot = @(
                foreach ($row in $gpuRows) {
                    $parts = @($row -split ',' | ForEach-Object { $_.Trim() })
                    if ($parts.Count -ge 7) {
                        [PSCustomObject]@{
                            Name = $parts[0]
                            UtilizationPercent = $parts[1]
                            EncoderUtilizationPercent = $parts[2]
                            PowerWatts = $parts[3]
                            TemperatureC = $parts[4]
                            MemoryUsedMiB = $parts[5]
                            MemoryTotalMiB = $parts[6]
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
        PerformanceRelevant = $performanceRelevantProcesses
        ReviewRequired = ($performanceRelevantProcesses.Count -gt 0)
        ReviewNote = 'Presence is not proof of a bottleneck. Explain each candidate and ask whether it is required before changing it. Preserve required simulator-support and hardware-control functions.'
        TopByWorkingSet = $topProcessesByWorkingSet
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
