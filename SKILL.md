---
name: configure-iracing-performance
description: Diagnose and tune iRacing monitor or VR graphics for a requested stable FPS target. Use when a driver asks to improve iRacing FPS, match monitor refresh rate, investigate a frame-rate cap, tune triple-monitor performance, or optimize graphics after a hardware or display change.
---

# iRacing Performance Configuration

Use this workflow to reach a repeatable, stable FPS target while preserving the user's preferred image quality.

## Guardrails

- Ask first: `Will this run on 1 monitor, 3 monitors, or VR?` Do not diagnose or edit until the display path is known.
- Do not edit a renderer file while `iRacingUI` or an iRacing simulation process is running. The UI can overwrite external edits.
- Inspect first. Back up the exact renderer file before the first change.
- Change one performance lever per test. Record the measured FPS, scene, and whether the GPU or CPU is saturated.
- Do not claim a target is achieved from a file setting alone. Require an in-session measurement in the same car, track, weather, and grid size.
- Treat 1–2 FPS below a configured cap as effectively capped when frame time is stable.
- Preserve output resolution, monitor topology, and FOV unless the driver explicitly accepts a change.

## Choose the Display Path

1. Ask the driver to select **1 monitor**, **3 monitors**, or **VR**.
2. For 1 or 3 monitors, ask the target FPS and monitor refresh rate. Confirm the output resolution and monitor count before tuning.
3. For VR, ask headset model, connection type when relevant, selected runtime (OpenXR, OpenVR, or Oculus), native refresh-rate target, and whether reprojection/motion smoothing is enabled. Do not treat synthetic/reprojected frames as native performance.
4. Use the matching renderer: `rendererDX11Monitor.ini` for monitors, `rendererDX11OpenXR.ini`, `rendererDX11OpenVR.ini`, or `rendererDX11Oculus.ini` for VR. Never transfer a monitor profile wholesale to VR.

## Diagnose

1. Run `scripts/diagnose.ps1 -DisplayMode <monitor|openxr|openvr|oculus>` to collect active iRacing processes, renderer file, graphics options, display refresh rate, and NVIDIA load when available.
2. Confirm the selected renderer file matches the launch display mode.
3. Verify actual Windows refresh rate, `VerticalSync`, `LimitFrameRate`, and `DesiredFPSLimit`. Do not assume `RefreshRate` matters in windowed mode.
4. Establish a baseline in a repeatable session. Read the in-sim FPS meter and note GPU/CPU bars.

## Interpret the Result

| Evidence | Interpretation | First response |
| --- | --- | --- |
| FPS matches a configured cap | Intentional limiter | Set the requested cap only if it is safe for the display and desired by the driver. |
| GPU is near 95–100% | GPU-bound | Reduce GPU effects, then use FSR progressively. |
| CPU bar is saturated while GPU is not | CPU-bound | Reduce cars, mirrors, shadows, and object/event detail; do not expect FSR to help. |
| FPS varies greatly by grid or track | Scene-bound | Test with the target race conditions and tune cars, mirrors, and LOD. |
| Renderer settings revert | UI overwrote the file | Close all iRacing processes before editing and verify the saved file afterward. |

## Tune Monitor Rendering

Work in this order and retest after each change:

1. Disable costly effects first: full-resolution SSR, SSAO, dynamic shadows, excessive particle quality, and unnecessary cubemaps.
2. For CPU pressure, reduce `MaxCarsToDraw`, `MaxCarsToDrawInMirrors`, crowd/pit/event detail, and mirror detail. Keep enough cars for the driver's race use case.
3. For a GPU-bound triple-monitor setup, retain the desktop output resolution and use iRacing FSR (`ResolutionScaling`) only after simpler changes. Ensure AA remains enabled: MSAA, FXAA, or SMAA.
4. Use FSR in order: `0` off, `1` Ultra, `2` Quality, then higher modes only if the driver accepts lower image quality. Restart the simulator after changing it.
5. Keep `LimitFrameRate=1`, `DesiredFPSLimit=<target>`, and `VerticalSync=0` only when the driver prefers a fixed cap without V-Sync. Do not alter adaptive-sync or NVIDIA settings without inspecting them and obtaining user approval.

## Tune VR Rendering

1. Set a target equal to the headset's native refresh cadence. Evaluate stable frame time and headset smoothness, not the desktop mirror's FPS alone.
2. Keep the chosen OpenXR/OpenVR/Oculus runtime fixed during a test. Do not switch runtimes, iRacing settings, and headset software settings in one iteration.
3. Reduce CPU-bound settings first when the CPU frame time is limiting: cars, mirror draw count/detail, pit/event/crowd objects, and dynamic shadows.
4. For GPU-bound VR, test one lever at a time: iRacing FSR (`ResolutionScaling`), the runtime render resolution, then VR-specific stereo efficiency. Record visual quality at the center and edges.
5. For supported NVIDIA/OpenXR headsets, consider SPS or foveated rendering only after a baseline. Use fixed or eye-tracked foveation only when the headset/runtime reports support; do not hand-edit foveation values without a backup and a restart.
6. Treat `ResolutionScalePct` in the OpenXR renderer as a separate control from iRacing FSR. Change only one of them per test.
7. If wireless VR is used, separately diagnose network/encoding latency. A smooth GPU frame time does not rule out streaming stutter.

## Apply and Validate

1. With iRacing fully closed, make the smallest selected change.
2. Verify the changed keys immediately after writing.
3. Launch iRacing, restart the simulation when a graphics setting requires it, and retest the same scenario.
4. If FPS regresses, revert only the last tested change and preserve the last measured-good profile.
5. Report the active renderer path, target cap, observed FPS, bottleneck, and every intentional visual trade-off.

## Triple-Monitor Notes

- A 7680×1440 triple-monitor layout renders over 11 million output pixels. A high-end GPU can still be GPU-bound in dense sessions.
- Separate views per monitor improve geometry but cost performance. Do not disable them unless the driver accepts the visual and geometric compromise.
- Do not compare FPS from different tracks, time of day, weather, or car grids as a configuration regression.

## VR Notes

- Prefer OpenXR as the first runtime to test when the headset supports it. Fall back only for compatibility or a measured regression.
- Restart the simulation after changes that iRacing marks as requiring a restart, including resolution scaling and VR mode changes.
- Save VR and monitor profiles independently. A performance result is valid only for the tested headset, runtime, refresh rate, and render resolution.
