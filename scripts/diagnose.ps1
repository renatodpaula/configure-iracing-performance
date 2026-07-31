[CmdletBinding()]
param(
    [string]$RendererPath,
    [ValidateSet('monitor', 'openxr', 'openvr', 'oculus')]
    [string]$DisplayMode = 'monitor'
)

$ErrorActionPreference = 'Stop'
$documents = [Environment]::GetFolderPath('MyDocuments')
$iracingDocuments = Join-Path $documents 'iRacing'

if (-not $RendererPath) {
    $rendererFile = @{
        monitor = 'rendererDX11Monitor.ini'
        openxr = 'rendererDX11OpenXR.ini'
        openvr = 'rendererDX11OpenVR.ini'
        oculus = 'rendererDX11Oculus.ini'
    }[$DisplayMode]
    $selectedRenderer = Join-Path $iracingDocuments $rendererFile
    if (Test-Path -LiteralPath $selectedRenderer) {
        $RendererPath = $selectedRenderer
    }
    else {
        $RendererPath = Get-ChildItem -LiteralPath $iracingDocuments -Filter 'rendererDX11*.ini' -ErrorAction Stop |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }
}

if (-not (Test-Path -LiteralPath $RendererPath)) {
    throw "Renderer file not found: $RendererPath"
}

$keys = @(
    'NumMonitors', 'RenderViewPerMonitor', 'fullScreen', 'RefreshRate', 'windowedWidth', 'windowedHeight',
    'VerticalSync', 'LimitFrameRate', 'DesiredFPSLimit', 'ResolutionScaling', 'FSRSharpness',
    'AntiAliasMethod', 'MSAASamples', 'SSRLevel', 'SSAO', 'DynamicShadowMaps', 'ShadowDetail',
    'MirrorDetail', 'MaxCarsToDraw', 'MaxCarsToDrawInMirrors', 'LODMinFPSTarget', 'ShaderQuality'
)
$config = @{}
foreach ($line in Get-Content -LiteralPath $RendererPath) {
    if ($line -match '^([^=;]+)=([^;\r\n]+)') {
        $name = $matches[1].Trim()
        if ($keys -contains $name) { $config[$name] = $matches[2].Trim() }
    }
}

$processes = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.ProcessName -like 'iRacing*' } |
    Select-Object ProcessName, Id, CPU, WorkingSet64, StartTime

$gpu = $null
$nvidiaSmi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
if ($nvidiaSmi) {
    $gpu = & $nvidiaSmi.Source --query-gpu=name,utilization.gpu,power.draw,temperature.gpu,memory.used,memory.total --format=csv,noheader
}

$display = $null
try {
    $display = Get-CimInstance Win32_VideoController |
        Where-Object { $_.Name -like '*NVIDIA*' } |
        Select-Object Name, DriverVersion, CurrentHorizontalResolution, CurrentVerticalResolution, CurrentRefreshRate
}
catch {
    $display = "Display query unavailable: $($_.Exception.Message)"
}

[PSCustomObject]@{
    RendererPath = $RendererPath
    DisplayMode = $DisplayMode
    RendererModified = (Get-Item -LiteralPath $RendererPath).LastWriteTime
    IRacingProcesses = $processes
    NvidiaGpu = $gpu
    Display = $display
    GraphicsOptions = $config
}
