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
- Confirm whether recording, streaming, telemetry, overlays, simulator-support/control software, hardware utilities, or communication software must remain active in the target setup. For SimHub or similar software, record the required outputs such as dashboards, bass shakers, belt tensioners, motion, wind, LEDs, and telemetry consumers.

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
- Verify that a feature's prerequisites and effective capability are exposed in the active path before tuning its settings. A saved, enabled, or allowed value is not proof that the feature is available or operating.
- Inspect configuration or profile backups semantically before restoring them. Restore only the smallest understood set of values, preserve per-value rollback, and retest the original trigger; never import an opaque backup wholesale.
- Never terminate, disable, or reconfigure external software merely because it is present. Explain why each candidate may matter and ask whether it is intentional for the target scenario.
- Preserve required capture, streaming, telemetry, communication, and peripheral software across every comparison; optimize around it as part of the system.
- Treat SimHub and similar simulator-support software as part of the rig when it controls required physical or telemetry outputs. Keep the application and required outputs active for every baseline and retest. Investigate optional plugins, overlays, polling, or outputs individually instead of proposing that the entire application be closed. Never alter a belt tensioner, motion system, or other actuator without explicit authorization and a safe rollback path.
- Do not keep or revert a change because of an isolated one- or two-FPS movement or a few tenths of a millisecond. Use ranges and repeated evidence.
- Treat system-wide input, audio, video, or device stalls as a platform problem first. Pause renderer tuning until the symptom is isolated.
- Identify an unfamiliar driver, virtual display, or device by process path, publisher, hardware IDs, and active resource use before proposing action. Prefer a reversible test; uninstall only with explicit authorization and a rollback path.
- Do not claim a single cause when one operation changed multiple variables. Record that the combined intervention resolved or changed the symptom and leave individual causality unproven unless isolating it would affect the next decision.
- Before a reboot or disruptive system change, record a checkpoint with the current state, evidence, pending outcomes, exact rollback, and the first post-change trigger. Resume from the newest checkpoint instead of restarting diagnosis.

## Control Diagnostic Cost and Stop Loops

- Keep a decision ledger for each outcome: current hypothesis, causal layer, supporting evidence, proposed test, predicted distinguishing results, and the decision each result would change.
- Run a test only when at least one plausible result changes the next action. Before asking for a manual test, explain briefly why it is not redundant.
- Prefer automated, read-only inspection before manual interaction, application launches, configuration changes, or reboots.
- When two sufficiently separated operating points produce the same invariant result despite a predicted relationship, stop that parameter sweep. Test a third point only for a distinct boundary or mechanism hypothesis.
- When evidence excludes or materially weakens one causal layer, move to the next plausible layer instead of trying neighboring settings from the same hypothesis family.
- Track independent outcomes separately, such as tool stability, capability exposure, effective operation, physical behavior, and performance certification. Never use success in one as proof of another.
- Label evidence as `documented`, `observed`, `inferred`, or `unverified`. Do not present an inference as a confirmed root cause.
- Stop when remaining tests have low information value, disproportionate risk, or cannot change the practical decision. Report the outcome honestly as resolved, unavailable in the active path, unsupported, not reproduced, inconclusive, or provisional.

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
7. Review every entry in `Processes.PerformanceRelevant` before changing graphics. For each entry, state the observed software, its category and rationale, then ask whether it must remain active. Do not infer that a recorder, overlay, telemetry tool, simulator-support application, browser, or peripheral utility is unnecessary.
8. If software must remain active, record only the workload details relevant to the observed symptom and keep the required setup active for every baseline and retest. For SimHub, distinguish required hardware/telemetry outputs from optional overlays or plugins before proposing any isolated test.
9. When a symptom extends beyond iRacing or correlates with an external program, device, or recent system change, stop graphics tuning, rank plausible causes, and isolate that branch with reversible one-variable tests. Resume renderer tuning only after resolving or excluding it.
10. Before testing an optional feature, confirm its documented prerequisites, exposure in the active path, and observable state. If this capability gate fails, skip setting and parameter sweeps and diagnose the missing layer instead.
11. Establish natural variance with repeated baseline windows in the agreed scenario. Record FPS, `R`, `G`, and `T` as ranges rather than single values. Treat GPU-utilization snapshots and process presence as supporting evidence only.

## Tune as an Experiment

1. Identify the limiting evidence and causal layer, not merely a low FPS number.
2. Propose one change with its expected benefit, visual cost, restart requirement, rollback path, predicted observable result, and the decision that result would change.
3. Prefer changing the setting in iRacing. If an INI edit is required, preview it first:

   ```powershell
   scripts/update-renderer.ps1 -RendererPath <path> -Section 'Graphics Options' -Set 'Key=Value' -ExpectedHash <sha256>
   ```

4. Show the preview. Apply only within the user's requested tuning scope by adding `-Apply`.
5. Restart when required and repeat the exact baseline scenario for the same duration and at the same session state. Reset the session or use an A/B/A comparison when simulated time, shadows, weather, or track state can drift.
6. Compare before and after ranges against the established natural-variance envelope. Treat overlapping ranges and small shifts as inconclusive unless the result repeats.
7. Keep the change only when a repeatable improvement advances the selected goal without an unacceptable trade-off.
8. Revert a repeatable regression. For an inconclusive renderer change, restore the last measured-good profile rather than accumulating unproven changes.
9. Continue with the next single lever only after recording the result as `keep`, `revert`, or `inconclusive`. Do not continue within the same hypothesis family after its stopping rule is met.

## Finish with Evidence

Report the display path, objective, active renderer, driving and replay separation, required background software, test scenario and duration, baseline and final FPS/frame-time ranges, natural variance, evidence labels, independently tracked outcomes, stopping rules reached, changes kept, changes reverted, inconclusive tests, and intentional visual trade-offs. State that the target is achieved only when the lower end of the measured range satisfies it in the representative in-session comparison; otherwise report the result as provisional.
