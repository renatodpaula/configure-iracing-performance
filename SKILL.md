---
name: configure-iracing-performance
description: Diagnose, test, and safely tune iRacing driving and replay graphics for single-monitor, triple-monitor, or VR systems, including relevant system-level bottlenecks when evidence points outside the simulator. Use when a driver wants visual immersion, the best image quality at a stable FPS target, maximum consistency and low latency, help with stutter or reprojection, an explanation for an FPS cap, renderer-file tuning, or optimization after a hardware, display, capture, peripheral, or software change.
---

# iRacing Performance Configuration

Treat every recommendation as a measured experiment. Prefer the best image quality that satisfies the driver's chosen goal; never accept a preset or documentation recommendation when a same-scenario test performs or feels worse. Treat small, overlapping measurement changes as noise until repeated evidence separates them.

## Establish the Goal First

If the request does not already answer these points, ask one focused opening question before diagnosing, then stop and wait for the answer. Do not bundle target FPS, refresh rate, synchronization, hardware, or test-scenario questions into the opening message:

`Will you use 1 monitor, 3 monitors, or VR, and is your priority maximum visual immersion, balanced quality at a specific stable FPS, or maximum consistency/lowest latency?`

When the display path is already known, ask only for the objective. When the objective is missing, always present these three explicit choices in the user's language and end the response:

1. Maximum visual immersion, accepting lower FPS.
2. Best graphics possible at a specific stable FPS.
3. Maximum consistency and lowest latency, accepting larger visual reductions.

Do not infer that a request to "improve performance" excludes visual immersion. Continue the technical inventory only in the next turn after the user chooses.

Then collect only missing details:

- For **visual immersion**, agree on the minimum acceptable driving FPS.
- For **balanced**, record the stable FPS target and maximize quality inside that budget.
- For **maximum consistency**, record the FPS or native VR cadence, latency preference, and acceptable visual trade-offs.
- For monitors, confirm resolution, monitor count, Windows refresh rate, and adaptive-sync/V-Sync use.
- For VR, confirm headset, runtime, connection, native refresh rate, render resolution, and reprojection or motion smoothing.
- Define the repeatable test: car, track, session type, fixed session time, weather, grid size, camera, test duration, and the demanding scene to compare.
- Confirm whether recording, streaming, telemetry, overlays, hardware utilities, or communication software must remain active in the target setup.

## Keep Driving and Replay Independent

- Diagnose and tune driving from `[Graphics Options]`.
- Read `[Replay Graphics]` separately and preserve it by default.
- Prefer high or maximum replay quality because replay usually does not require racing-level FPS and may be used to record cinematic takes.
- Change replay settings only when the driver explicitly requests it. For real-time recording, ask for the capture resolution and FPS target first.
- Never copy a monitor profile wholesale to VR or a driving profile wholesale to replay.

## Guardrails

- Diagnose only when the user asks for analysis. Apply changes only when the user asks to tune, optimize, or make the proposed change.
- Do not edit while `iRacingUI` or an iRacing simulation process is running.
- Use the exact renderer for the selected display mode. Do not fall back to a different renderer.
- Prefer supported in-sim controls. Use direct INI edits only when the intended section and key are verified.
- Before the first file edit, make a backup and record the original SHA-256 hash.
- Preserve resolution, monitor topology, FOV, and replay quality unless the driver accepts a change.
- Change one performance lever per test. A lever may require tightly coupled keys, such as enabling a cap and setting its value.
- Never terminate, disable, or reconfigure external software merely because it is present. Explain why each candidate may matter and ask whether it is intentional for the target scenario.
- Preserve required capture, streaming, telemetry, communication, and peripheral software across every comparison; optimize around it as part of the system.
- Do not keep or revert a change because of an isolated one- or two-FPS movement or a few tenths of a millisecond. Use ranges and repeated evidence.
- Treat system-wide input, audio, video, or device stalls as a platform problem first. Pause renderer tuning until the symptom is isolated.
- Identify an unfamiliar driver, virtual display, or device by process path, publisher, hardware IDs, and active resource use before proposing action. Prefer a reversible test; uninstall only with explicit authorization and a rollback path.

## Diagnose

1. Read [references/preflight.md](references/preflight.md).
2. Read [references/metrics.md](references/metrics.md).
3. Read [references/monitor.md](references/monitor.md) for one or three monitors, or [references/vr.md](references/vr.md) for VR.
4. Read [references/external-troubleshooting.md](references/external-troubleshooting.md) only when observed software, devices, recent system changes, or symptoms outside iRacing make it relevant.
5. Run:

   ```powershell
   scripts/diagnose.ps1 -DisplayMode <monitor|openxr|openvr|oculus> -OutputFormat Json
   ```

6. Confirm `Renderer.MatchesDisplayMode`, inspect `Processes.Blocking`, and use `Config.DrivingGraphics` for the driving diagnosis. Treat `Config.ReplayGraphics` as an independent high-quality profile.
7. Review every entry in `Processes.PerformanceRelevant` before changing graphics. For each entry, state the observed software, its category and rationale, then ask whether it must remain active. Do not infer that a recorder, overlay, telemetry tool, browser, or peripheral utility is unnecessary.
8. If software must remain active, record only the workload details relevant to the observed symptom and keep the required setup active for every baseline and retest.
9. When a symptom extends beyond iRacing or correlates with an external program, device, or recent system change, stop graphics tuning, rank plausible causes, and isolate that branch with reversible one-variable tests. Resume renderer tuning only after resolving or excluding it.
10. Establish natural variance with repeated baseline windows in the agreed scenario. Record FPS, `R`, `G`, and `T` as ranges rather than single values. Treat GPU-utilization snapshots and process presence as supporting evidence only.

## Measure (automated, preferred when available)

Read [references/measure.md](references/measure.md). When PresentMon is available, replace hand-read meter ranges with captured frame-time statistics — this is the objective evidence the decision rules below assume. When it is not, keep reading the in-sim meters as in [references/metrics.md](references/metrics.md).

1. Establish natural variance with **two or more** baseline windows in the agreed scenario, each captured the same way (an elevated terminal is required):

   ```powershell
   scripts/measure-frametime.ps1 -Label baseline-1 -DurationSeconds 60
   scripts/measure-frametime.ps1 -Label baseline-2 -DurationSeconds 60
   ```

   Each run writes a stats JSON (median/avg FPS, 1% low, 0.1% low, frame-time percentiles, frame-time standard deviation, and CPU/GPU-busy means when the PresentMon build exposes them). `CPUBusy` corresponds to the `R` meter, `GPUBusy` to the `G` meter, and `FrameTime` to the `T` meter.
2. After each single lever change, capture a candidate window the same way (e.g. `-Label cap-90`), restarting to the same session state first when required.
3. Judge the result against the baseline envelope instead of eyeballing it:

   ```powershell
   scripts/compare-runs.ps1 -Baseline runs/baseline-1.json,runs/baseline-2.json -Candidate runs/cap-90.json -Objective balanced -TargetFPS 90 -ChangeType quality-up
   ```

   `SuggestedDecision` (keep / revert / inconclusive) and `TargetMet` cover the measured side only. When `HumanJudgmentRequired` is true, the visual or latency trade-off still has to be judged by the driver — report both and let them decide.

## Tune as an Experiment

1. Identify the limiting evidence, not merely a low FPS number.
2. Propose one change with its expected benefit, visual cost, restart requirement, and rollback path.
3. Prefer changing the setting in iRacing. If an INI edit is required, preview it first:

   ```powershell
   scripts/update-renderer.ps1 -RendererPath <path> -Section 'Graphics Options' -Set 'Key=Value' -ExpectedHash <sha256>
   ```

4. Show the preview. Apply only within the user's requested tuning scope by adding `-Apply`.
5. Restart when required and repeat the exact baseline scenario for the same duration and at the same session state. Reset the session or use an A/B/A comparison when simulated time, shadows, weather, or track state can drift.
6. Compare before and after ranges against the established natural-variance envelope. Prefer `scripts/compare-runs.ps1` on captured windows; otherwise compare hand-read ranges. Treat overlapping ranges and small shifts as inconclusive unless the result repeats.
7. Keep the change only when a repeatable improvement advances the selected goal without an unacceptable trade-off.
8. Revert a repeatable regression. For an inconclusive renderer change, restore the last measured-good profile rather than accumulating unproven changes.
9. Continue with the next single lever only after recording the result as `keep`, `revert`, or `inconclusive`.

## Finish with Evidence

Report the display path, objective, active renderer, driving and replay separation, required background software, test scenario and duration, baseline and final FPS/frame-time ranges, natural variance, bottleneck evidence, changes kept, changes reverted, inconclusive tests, and intentional visual trade-offs. State that the target is achieved only when the lower end of the measured range satisfies it in the representative in-session comparison; otherwise report the result as provisional.
