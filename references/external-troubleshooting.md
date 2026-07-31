# Conditional External Troubleshooting

Read only the section supported by the observed symptom or active setup. These are diagnostic branches, not a mandatory checklist.

## Preserve intentional workload

If software is part of the real use case, keep it active for every comparison and optimize around it. Examples include recording, streaming, telemetry, communication, overlays, and peripheral control.

Collect only details relevant to the suspected cost. For capture or streaming, these can include resolution, FPS, encoder, active scene, source types, filters, overlays, and whether recording or streaming is active.

When capture software is relevant:

- Compare the required scene with output stopped and active.
- Keep sources and unrelated quality settings fixed.
- Distinguish composition cost from scaling and encoding cost. Changing output resolution alone may leave the base composition workload mostly unchanged.
- Back up profiles or scene collections before structural changes and visually validate affected scenes afterward.

## Investigate device-path stalls

Use this branch only when input, audio, video, or the desktop stalls and the symptom correlates with a device or application becoming active.

1. Reproduce the correlation with the smallest safe A/B test.
2. Inventory only relevant devices and their connection ancestry, such as USB host controllers or root hubs. Physical port separation does not prove separate controllers.
3. Check for bandwidth, interrupt, power, driver, or wireless-interference contention involving active devices.
4. Move, disable, or reconfigure one device at a time using a reversible test.
5. Expect a moved device to acquire a new instance path. Rebind any application source that still points to the previous instance before judging the test.
6. Repeat the original trigger and validate both system responsiveness and the device's intended function.

Require temporal correlation and a repeatable improvement before naming the device path as the cause.

## Handle unfamiliar drivers or virtual devices

Use this branch only when inventory finds an unfamiliar component plausibly related to the symptom or consuming meaningful resources.

1. Identify its executable path, signer or publisher, installed package, hardware IDs, associated devices, startup mechanism, and observed activity.
2. Explain its likely function and ask whether that function is still needed.
3. Prefer a reversible stop or disable test when safe.
4. Uninstall only with explicit permission and a known recovery path.
5. Reboot when required, then confirm whether the process, device, and startup entry return.

## Interpret NVIDIA components

Use this branch only when NVIDIA capture, overlay, encode, or presentation behavior is relevant.

- Container processes are normally part of the driver and do not prove active recording.
- A loaded overlay stack does not prove Instant Replay is recording.
- Check encode activity and application logs when available.
- Do not disable G-SYNC, the display driver, or NVENC required by another application while testing an overlay.
