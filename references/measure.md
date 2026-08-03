# Automated Frame-Time Measurement (PresentMon)

Manual meter reading (see [metrics.md](metrics.md)) is the fallback. When PresentMon is
available, capture frame times programmatically so every keep/revert decision rests on the
same objective statistics instead of eyeballed ranges. This is the loop the "measured
experiment" philosophy assumes but the hand-read path only approximates.

## Prerequisites

- **PresentMon** (Intel, open source): https://github.com/GameTechDev/PresentMon/releases.
  Put `PresentMon.exe` on PATH, beside `scripts/`, or pass `-PresentMonPath`.
- **Elevated terminal.** PresentMon opens a realtime ETW session and needs administrator
  rights. `measure-frametime.ps1` refuses to capture otherwise (the `-FromCsv` reduce mode
  needs no elevation).
- **iRacing in a live, presenting scene.** Measure the demanding scene the driver actually
  cares about (race start, dense grid, rain, night), not a parked pit box.

Nothing here writes to any iRacing configuration file. Captures land in
`Documents\iRacing\perf-runs\` by default (override with `-OutDir`).

## Capture a window

```powershell
scripts/measure-frametime.ps1 -Label baseline-1 -DurationSeconds 60 -WarmupSeconds 5
```

`-WarmupSeconds` is discarded before counting so shader/cache warm-up does not pollute the
window. Each run writes `<Label>.json`. Keep the raw per-frame CSV with `-KeepCsv`. To
re-reduce an existing capture without re-running the sim:

```powershell
scripts/measure-frametime.ps1 -Label baseline-1 -FromCsv .\baseline-1.raw.csv
```

### What the statistics mean

| Field | Meaning |
| --- | --- |
| `AvgFPS` | `1000 / mean frame time` — frames divided by wall-clock time, not a mean of instantaneous FPS. |
| `MedianFPS` | FPS at the median (50th percentile) frame time. |
| `OnePercentLowFPS` | FPS at the 99th-percentile frame time (percentile-method 1% low). |
| `PointOnePercentLowFPS` | FPS at the 99.9th-percentile frame time (0.1% low). |
| `StdDevFrameTimeMs` | Frame-time standard deviation — the direct **consistency** signal. |
| `P999FrameTimeMs` | 99.9th-percentile frame time — the worst-case stutter signal. |
| `AvgCpuBusyMs` | Mean CPU-busy time per frame — corresponds to the `R` meter. |
| `AvgGpuBusyMs` | Mean GPU-busy time per frame — corresponds to the `G` meter. |
| `LikelyBoundBy` | `CPU` or `GPU`, from whichever busy time dominates (supporting evidence only). |

`CPUBusy`/`GPUBusy` are only present when the PresentMon build exposes them (2.x does; some
1.x captures do not). Everything else is derived from the frame-time column, which the
script resolves as `FrameTime` (2.x) or `msBetweenPresents` (1.x) automatically.

### Column and frame handling

- Generated/repeated frames (frame-generation builds) and dropped presents are excluded so
  only real, presented Application frames count. `SkippedRows` reports how many were dropped.
- All numbers are parsed with invariant culture, so a comma-decimal Windows locale does not
  corrupt the `.`-decimal PresentMon output.

## Decide against the envelope

Capture **two or more** baselines to establish natural variance, then one candidate window
per single lever change, then judge:

```powershell
scripts/compare-runs.ps1 -Baseline runs/baseline-1.json,runs/baseline-2.json `
  -Candidate runs/cap-90.json -Objective balanced -TargetFPS 90 -ChangeType quality-up
```

`compare-runs.ps1` builds a min/max envelope from the baselines (widened by
`-NoiseMarginPct`, default 2%) and reports, per objective:

- `PrimaryMetric` — `OnePercentLowFPS` for `visual-immersion`/`balanced`, `StdDevFrameTimeMs`
  for `consistency`.
- `PerformanceVerdict` — improved / regressed / inconclusive vs the envelope.
- `TargetMet` — whether the candidate's 1% low still clears the target/floor.
- `SuggestedDecision` — keep / revert / inconclusive.
- `HumanJudgmentRequired` — true for `-ChangeType quality-up`, where the FPS cost is expected
  and the driver must decide whether the visual gain justifies it.

`-ChangeType` disambiguates intent the numbers cannot: `quality-up` keeps a small FPS drop as
long as the floor holds; `performance-up` only keeps a meaningful FPS gain; `neutral` just
reports the measured verdict. A candidate whose 1% low fails the floor is never certified,
regardless of average FPS.

### Honest limits

- This automates the **measured** side only. Perceived image quality, latency feel, and
  reprojection artifacts remain human judgments — surface them, do not pretend to score them.
- A pit-box capture still cannot certify a racing target; certify only in the representative
  workload with a meaningful car/grid load. Otherwise label the result provisional.
- One baseline window yields a weak envelope; `ConfidenceNote` flags it. Prefer two or more.
