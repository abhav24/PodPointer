# Hardware test plan

These tests answer what unit tests can't. Allow about 15 minutes. Follow the order, because each test depends on the one before it.

**Setup:** build and open the app, then follow the setup steps in the [README](../README.md).

## 1. Does motion arrive from the open case?

Check that **Motion** says **Arriving**, then move the case and watch **Jolt** change.

If motion doesn't arrive, try these one at a time:
- Select the AirPods as the sound output again.
- Turn on **Keep audio connection active**.
- Close the lid, open it again, and wait a few seconds.

Try again with Spotify or Apple Music open, because another media app may take the presses.

## 2. Is the pointer good enough to present with?

1. Set **Pointer** to **Laser dot**.
2. Look at the middle of your display and select **Recenter**.
3. Point at titles, bullets, and chart labels on a real slide.
4. Adjust **Turn range**, **Tilt range**, and **Filter cutoff**.
5. Keep using it for 5 minutes, and notice how far the center drifts.
6. Record the **Rate**, **p95 interval**, and **Longest gap**.

**Passes if** you can hold the dot on a line of slide text, and drift is fixed by an occasional recenter.

If the dot moves the wrong way, turn on an invert option and tell us in your report.

## 3. Does the laser dot appear over a slideshow?

Start a full-screen slideshow in PowerPoint and in Keynote, with the laser dot on. If you can, also try an external display, using **Display** to select it.

**Passes if** the dot stays visible over the slides.

## 4. When does motion keep working?

Watch **Samples**, **Sensor**, and the log during each of these:

- Both AirPods in
- One AirPod in, then the other
- One AirPod held in your hand, like a remote
- Both AirPods back in the case
- Spatial Audio turned on, then off (watch for sudden jumps in yaw)

**Passes if** you can tell which setups keep producing samples. This decides whether a handheld clicker is possible.

## Share your results

Select **Copy Test Report** and paste it into a [test report issue](https://github.com/abhav24/PodPointer/issues/new?template=test-report.md).
