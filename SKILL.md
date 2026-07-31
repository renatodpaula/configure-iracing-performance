---
name: configure-iracing-performance
description: Diagnose, test, and safely tune iRacing driving and replay graphics for single-monitor, triple-monitor, or VR systems. Use when a driver wants visual immersion, the best image quality at a stable FPS target, maximum consistency and low latency, help with stutter or reprojection, an explanation for an FPS cap, renderer-file tuning, or optimization after a hardware or display change.
---

# iRacing Performance Configuration

Treat every recommendation as a measured experiment. Prefer the best image quality that satisfies the driver's chosen goal; never accept a preset or documentation recommendation when a same-scenario test performs or feels worse.

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
- Define the repeatable test: car, track, session type, time, weather, grid size, and the demanding scene to compare.

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

## Diagnose

1. Read [references/metrics.md](references/metrics.md).
2. Read [references/monitor.md](references/monitor.md) for one or three monitors, or [references/vr.md](references/vr.md) for VR.
3. Run:

   ```powershell
   scripts/diagnose.ps1 -DisplayMode <monitor|openxr|openvr|oculus> -OutputFormat Json
   ```

4. Confirm `Renderer.MatchesDisplayMode`, inspect `Processes.Blocking`, and use `Config.DrivingGraphics` for the driving diagnosis. Treat `Config.ReplayGraphics` as an independent high-quality profile.
5. Establish the in-session baseline in the agreed scenario. Record FPS plus iRacing `R`, `G`, and `T` frame times. Treat GPU-utilization snapshots as supporting evidence only.

## Tune as an Experiment

1. Identify the limiting evidence, not merely a low FPS number.
2. Propose one change with its expected benefit, visual cost, restart requirement, and rollback path.
3. Prefer changing the setting in iRacing. If an INI edit is required, preview it first:

   ```powershell
   scripts/update-renderer.ps1 -RendererPath <path> -Section 'Graphics Options' -Set 'Key=Value' -ExpectedHash <sha256>
   ```

4. Show the preview. Apply only within the user's requested tuning scope by adding `-Apply`.
5. Restart when required and repeat the exact baseline scenario.
6. Compare before and after. Keep the change only when it improves the selected goal without an unacceptable trade-off.
7. If FPS, frame time, smoothness, latency, stability, or perceived quality regresses, restore the generated backup with `scripts/restore-renderer.ps1` and retain the last measured-good profile.
8. Continue with the next single lever only after recording the result.

## Finish with Evidence

Report the display path, objective, active renderer, driving and replay separation, test scenario, baseline and final FPS/frame times, bottleneck evidence, changes kept, changes reverted, and intentional visual trade-offs. State that the target is achieved only after an in-session comparison; otherwise report the result as provisional.
