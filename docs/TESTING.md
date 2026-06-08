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

Adjust **Tap sensitivity** if needed.

**Passes if** at least 18 of 20 taps count, with no more than one false tap in the minute.

## 4. Is the pointer usable?

1. Choose **Presenter** and point at things on the screen.
2. Adjust **Range** and **Steadiness**.
3. Try holding the dot on one line of text.
4. Tap, and check that the dot stays where you aimed.

**Passes if** you can hold the dot on a line of text and tapping doesn't move it noticeably.

## 5. Does it work with slides?

1. Turn on **Send keys and clicks** and allow Accessibility access.
2. Start a full-screen slideshow in Keynote or PowerPoint.
3. Move through the slides with taps and double-taps, using the laser dot as you go.
4. If you can, repeat on an external display, using **Display** to select it.

**Passes if** the slides change and the dot stays visible.

## 6. Does Mouse mode work?

Choose **Mouse**, then move the cursor and tap a button. Move a real mouse too, and check that the case pauses until you stop.

**Passes if** clicks land where you aim.

## Share your results

Select **Copy Test Report** and paste it into a [test report issue](https://github.com/abhav24/PodPointer/issues/new?template=test-report.md).
