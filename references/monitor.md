# Monitor Tuning

Use this guide only after establishing the objective and baseline in [metrics.md](metrics.md).

## Preserve topology first

- Confirm one or three monitors, actual Windows refresh rate, output resolution, windowed or exclusive-fullscreen path, and adaptive-sync/V-Sync state.
- For triples, distinguish borderless/windowed spanning from NVIDIA Surround or AMD Eyefinity.
- Preserve `NumMonitors`, `RenderViewPerMonitor`, physical dimensions, bezel geometry, angles, curvature, viewing distance, and FOV unless the driver explicitly requests a geometry change.
- Do not assume the renderer `RefreshRate` controls a windowed session; verify Windows Advanced Display.

## Tune the driving profile

Work only in `[Graphics Options]`. Keep `[Replay Graphics]` independent and high quality by default.

For renderer/CPU pressure (`R`):

1. Reduce cars and pit objects drawn, especially in mirrors, while preserving enough situational information for the race.
2. Reduce mirror detail or mirror count.
3. Reduce dynamic shadows, shadow-casting lights, crowd, event, grandstand, pit, and object detail.
4. Align dynamic LOD target with the stable driving target and test dense-grid behavior.
5. Retest before using resolution scaling; FSR does not reduce CPU load.

For GPU pressure (`G`):

1. Reduce full-resolution SSR, SSAO, high shadow resolution/filtering, full-resolution particles, cubemaps, heat haze, distortion, and excessive AA.
2. Preserve output resolution when possible.
3. Test iRacing FSR progressively only after simpler changes. Keep a supported AA mode enabled and restart the simulator.
4. Compare image quality while driving, including fences, distant cars, cockpit text, rain, and night lighting.

For frame-time spikes with acceptable average FPS:

1. Test the cap and `MaxPreRenderedFrames` one at a time.
2. Check thermal/power throttling, overlays, Auto HDR, background hardware utilities, USB resets, and replay spooling.
3. Re-run the same scene after each isolated test.

## Protect replay quality

- Do not reduce `[Replay Graphics]` while solving driving FPS.
- Prefer maximum cars, trackside detail, shadows, reflections, particles, depth of field, and other cinematic options when the system can reproduce the replay acceptably.
- Accept lower replay FPS when the purpose is reviewing an incident or rendering a take.
- If the driver records replay in real time, collect output resolution, encoder, capture FPS, camera, and acceptable frame pacing before tuning replay.

## Official references

- [Setting Up Three Monitors](https://support.iracing.com/support/solutions/articles/31000171395-setting-up-three-monitors)
- [Connection Type & Max Cars](https://support.iracing.com/support/solutions/articles/31000149355-connection-type-max-cars)
- [iRacing Setup: A Beginner's Guide](https://support.iracing.com/support/solutions/articles/31000168572)
