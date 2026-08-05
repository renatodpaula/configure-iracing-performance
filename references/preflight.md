# System Preflight

Run this preflight after establishing the objective and before the first baseline or renderer change.

## Review performance-relevant software

1. Run `scripts/diagnose.ps1` and inspect `Processes.PerformanceRelevant`.
2. Present every candidate to the driver with:
   - process and category;
   - observed instance count and memory;
   - why it can affect CPU, GPU, frame pacing, capture, or display presentation;
   - one direct question asking whether it is required in the target scenario.
3. Do not treat presence as proof of a bottleneck. Measure active utilization when possible.
4. Never close, kill, disable, or reconfigure a candidate without the driver's authorization.

Typical categories include:

- **Capture or streaming:** OBS, Streamlabs, XSplit, Medal, NVIDIA Overlay, and similar tools can consume render, copy, encode, memory, and disk resources.
- **Simulator support or control:** SimHub and similar tools may drive dashboards, bass shakers, belt tensioners, motion, wind, LEDs, or telemetry consumers. Treat required outputs as part of the rig, keep them active in every comparison, and isolate only optional plugins, overlays, polling, or outputs with authorization.
- **Overlay or telemetry:** Discord overlays, RTSS, Racelab, Crew Chief, and similar tools can hook the renderer or update frequently.
- **Hardware or RGB utilities:** peripheral, wheel, audio, cooling, and lighting software may use background resources but may also be required for driving.
- **Remote or virtual display:** remote-desktop, virtual-monitor, and display-sharing tools can alter the display path or consume GPU resources.
- **Browser or launcher:** many browser processes can collectively use meaningful CPU, GPU, and memory even when no single process looks large.

## Follow the evidence

Do not run every possible subsystem investigation. Start with the observed symptom and use the smallest relevant branch:

1. Classify whether the symptom is limited to iRacing or also affects input, audio, video, the desktop, or another application.
2. Record what action starts and stops it, when possible.
3. Review recent changes and the active software or hardware plausibly connected to that symptom.
4. Rank hypotheses by evidence and test one reversible change at a time.
5. Confirm the result with the same trigger. Do not mistake a coincidental improvement for a cause.
6. Return to iRacing graphics tuning only after the external cause is resolved or reasonably excluded.

If the evidence points to an external program, device path, driver, capture workload, overlay, or system service, read [external-troubleshooting.md](external-troubleshooting.md). Otherwise do not spend time on those branches.

## Establish the fixed software set

Before the baseline, record which candidates are:

- required and kept active;
- optional and intentionally closed with permission;
- not understood and awaiting the driver's decision.

Do not begin graphics tuning while required software is still changing between runs.
Do not classify SimHub as disposable overhead when it provides required simulator controls or feedback. Record those functions explicitly and optimize around them.
