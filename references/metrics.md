# Measurement and Decision Guide

Use measurements to decide whether a recommendation is successful. Documentation and presets provide hypotheses, not proof.

## Establish the objective

| Objective | Optimize for | Required constraint |
| --- | --- | --- |
| Visual immersion | Highest perceived image quality | Agree on a minimum acceptable driving FPS and smoothness |
| Balanced | Highest quality inside a stable FPS budget | Use the driver's explicit target FPS |
| Maximum consistency | Stable frame time and low latency | Agree on target FPS or native VR cadence and visual trade-offs |

Keep replay independent. Default to high or maximum replay quality and accept a lower replay FPS unless the driver specifies a real-time capture target.

## Read the iRacing meters

Enable System Meters through the widget editor (`Alt+K`) and use numerical values when available:

- `R`: renderer/CPU frame time.
- `G`: GPU frame time.
- `T`: total frame time. It is related to, but not simply equal to, `R + G`.
- `P`: page-fault or interrupt pressure. A sustained problematic value can indicate memory, device, or background-system issues.

Compare frame time with the target budget:

| Target | Budget |
| ---: | ---: |
| 60 FPS | 16.67 ms |
| 72 FPS | 13.89 ms |
| 90 FPS | 11.11 ms |
| 120 FPS | 8.33 ms |
| 144 FPS | 6.94 ms |
| 165 FPS | 6.06 ms |
| 240 FPS | 4.17 ms |

Calculate other budgets as `1000 / target FPS`.

## Classify with multiple signals

- Treat high `R` relative to the target budget as renderer/CPU pressure.
- Treat high `G` relative to the target budget as GPU pressure.
- Treat high `T`, stable `R`, and stable `G` with visible spikes as a frame-pacing or external-system investigation.
- Treat a configured FPS cap as intentional only after checking the in-sim cap, V-Sync, Windows refresh rate, VR cadence, adaptive sync, and reprojection.
- Use `nvidia-smi` or vendor utilization only as supporting evidence. A single snapshot cannot prove the bottleneck.
- Diagnose stutter separately from average FPS. Check overlays, RGB or hardware utilities, replay spooling, Auto HDR, USB resets, thermal or power throttling, and background processes when frame-time spikes remain.

## Run a comparable test

1. Choose a demanding, repeatable scene representative of the driver's use: race start, dense grid, pit lane, night lighting, rain, or a specific VR view.
2. Keep car, track, time, weather, grid, camera, runtime, resolution, and background applications fixed.
3. Record baseline FPS, `R`, `G`, `T`, smoothness, latency, and the driver's perceived image quality.
4. Change one performance lever.
5. Restart the simulator when the UI marks a setting as requiring restart.
6. Repeat the same scene and record the same evidence.
7. Keep the change only when it advances the selected objective. Revert a measured or perceived regression even when documentation recommends the setting.

Use this result record:

```text
Scenario:
Objective and target:
Change:
Before FPS / R / G / T:
After FPS / R / G / T:
Visual or latency impact:
Decision: keep / revert / provisional
```

## Official references

- [Meter Box](https://support.iracing.com/support/solutions/articles/31000133494-meter-box-f-key-in-game-)
- [Understanding Resolution Scaling](https://support.iracing.com/support/solutions/articles/31000167510-understanding-resolution-scaling)
- [Dealing with Freezing and/or Stuttering Issues](https://support.iracing.com/support/solutions/articles/31000141916-dealing-with-freezing-and-or-stuttering-issues)
