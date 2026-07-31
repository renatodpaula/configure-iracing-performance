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

Compare frame-time ranges with the target budget:

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

## Establish natural variance

1. Warm the session and caches before measuring.
2. Record at least two baseline windows of equal duration; use 30–60 seconds when reading meters manually.
3. Ask for low-to-high ranges for FPS, `R`, `G`, and `T`, plus the typical value when the driver can judge it. Do not ask for or decide from one instantaneous value.
4. If telemetry or logging is available, prefer median, 1% low FPS, and high-percentile frame times over isolated minimum or maximum spikes.
5. Treat the combined baseline ranges as the natural-variance envelope.
6. By default, treat a one- or two-FPS shift or a few tenths of a millisecond as inconclusive when the ranges overlap. A smaller change may count only when repeated windows consistently reproduce it.
7. Do not compare a brief best-case spike or the FPS cap against a sustained range. Reaching the cap once is not evidence that the target is stable.

## Run a comparable test

1. Choose a demanding, repeatable scene representative of the driver's use: race start, dense grid, pit lane, night lighting, rain, or a specific VR view.
2. Keep car, track, session time, weather, grid, camera, test duration, resolution, and required background applications fixed.
3. A car parked in the pits is not sufficient control when simulated time, sky, shadows, weather, or track state continue to evolve.
4. Prefer a fixed-time session or restart to the same session state. Otherwise use an A/B/A sequence and compare equivalent elapsed-time windows.
5. Record baseline FPS, `R`, `G`, `T`, smoothness, latency, and perceived image quality as ranges.
6. Change one performance lever.
7. Restart when required and repeat the same measurement windows.
8. Classify the result:
   - **Keep:** repeated ranges shift meaningfully toward the objective without an unacceptable trade-off.
   - **Revert:** repeated ranges shift meaningfully away from the objective or quality cost is unacceptable.
   - **Inconclusive:** ranges overlap or the difference fits natural variance; restore renderer changes and test longer before drawing a conclusion.

A no-car pit-box test is useful for detecting caps and large system overhead, but it cannot certify a racing target. Certify the target only in the representative workload the driver actually requires, including any required background workload and a meaningful car/grid load. If the driver declines that test, preserve the chosen configuration and label the result provisional.

Use this result record:

```text
Scenario:
Objective and target:
Required background software:
Window duration and repetitions:
Change:
Before FPS range / R range / G range / T range:
After FPS range / R range / G range / T range:
Natural-variance envelope:
Visual or latency impact:
Decision: keep / revert / inconclusive
```

## Official references

- [Meter Box](https://support.iracing.com/support/solutions/articles/31000133494-meter-box-f-key-in-game-)
- [Understanding Resolution Scaling](https://support.iracing.com/support/solutions/articles/31000167510-understanding-resolution-scaling)
- [Dealing with Freezing and/or Stuttering Issues](https://support.iracing.com/support/solutions/articles/31000141916-dealing-with-freezing-and-or-stuttering-issues)
