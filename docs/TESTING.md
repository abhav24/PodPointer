# Hardware test plan

These tests answer what unit tests can't. Allow about 15 minutes. Follow the order, because each test depends on the one before it.

**Setup:** build and open the app, then follow the setup steps in the [README](../README.md).

## 1. Does motion arrive from the open case?

Check that **Motion** says **Arriving**, then move the case and watch **Jolt** change.

If motion doesn't arrive, try these one at a time:
- Select the AirPods as the sound output again.
- Turn on **Keep audio connection active**.
- Close the lid, open it again, and wait a few seconds.

**Passes if** motion keeps arriving for 2 minutes. Note the **Rate** and **Longest gap**, and whether **Sending AirPod** changes.

## 2. Does calibration finish?

Select **Calibrate** and follow the steps.

**Passes if** it finishes within two tries.

## 3. Are taps reliable?

Leave **Mode** on **Off** and **Send keys and clicks** off.

1. Hold the case still and tap it 20 times, pausing between taps. Check **Taps detected**.
2. Try double-taps and triple-taps.
3. Move the case around for 1 minute without tapping, and count any false taps in the log.

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
