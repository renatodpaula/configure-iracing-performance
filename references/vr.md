# VR Tuning

Use this guide only after establishing the objective and baseline in [metrics.md](metrics.md).

## Fix the test environment

- Confirm headset, active OpenXR/OpenVR/Oculus runtime, wired or wireless connection, native cadence, runtime render resolution, and reprojection or motion smoothing.
- Prefer OpenXR as the first supported path, then use Oculus or OpenVR for compatibility or a measured improvement.
- Keep runtime, headset software, render resolution, iRacing settings, and connection method fixed during each comparison.
- Measure native and synthetic/reprojected frames separately. Do not present reprojection as native target performance.

## Remove known conflicts

- Check for OpenXR Toolkit. iRacing recommends uninstalling it because support ended and it can cause performance or display issues.
- Prefer iRacing's native fixed or dynamic foveated rendering when the headset, runtime, eye-tracking extension, and NVIDIA RTX hardware support it.
- Do not assume SteamVR exposes eye tracking correctly for every headset.

## Tune by evidence

For renderer/CPU pressure (`R`):

1. Reduce cars and pit objects drawn, mirror count/detail, dynamic shadows, shadow-casting lights, and event/crowd/object detail.
2. Keep the runtime resolution fixed.
3. Retest before applying GPU-only scaling.

For GPU pressure (`G`):

1. Test expensive effects and AA first.
2. Test iRacing FSR (`ResolutionScaling`) as a separate lever.
3. Test runtime resolution or OpenXR `ResolutionScalePct` as a separate lever from FSR.
4. Compare center and edge clarity, cockpit text, distant cars, shimmering, and latency.
5. Test SPS, fixed foveated, or dynamic foveated only when supported. Restart after changing VR render mode.

For wireless or streamed VR:

- Separate render latency, encode latency, network latency, decode latency, and reprojection.
- A smooth `R`/`G` result does not rule out Wi-Fi congestion, encoder saturation, or headset-side frame drops.

## Preserve profiles

- Keep the selected VR renderer independent from monitor and replay settings.
- Back up the exact VR renderer before edits.
- Do not transfer numeric foveation or resolution values between headsets or runtimes.

## Official references

- [What You Need to Play iRacing in VR](https://support.iracing.com/support/solutions/articles/31000173566-what-you-need-to-play-iracing-in-vr)
- [Notice Regarding OpenXR Toolkit](https://support.iracing.com/support/solutions/articles/31000177470-notice-regarding-openxr-toolkit)
- [2025 Season 4: Dynamic Foveated Rendering](https://support.iracing.com/support/solutions/articles/31000177148-2025-season-4-release-notes-2025-09-08-02-)
- [2026 Season 3: OpenXR ResolutionScalePct](https://support.iracing.com/support/solutions/articles/31000179016-2026-season-3-initial-release-notes-2026-06-09-01-)
