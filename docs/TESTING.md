# Testing with real AirPods

Testing is built into the app's setup, so you don't need to count anything or judge by feel.

## 1. Follow setup

Build and open the app by following the [README](../README.md). Setup starts by itself the first time. To run it again, open **Advanced** and select **Run Setup Again**.

It tests these in order:

| Test | What you do | Passes with |
|---|---|---|
| Motion | Put the AirPods in the open case and move it | Motion keeps arriving |
| Calibration | Hold still, sweep the case, and tap | Calibration finishes |
| Tapping | Tap once at each of 10 prompts | At least 8 taps counted, and no more than 1 extra |
| Tap groups | Do 9 single, double, and triple taps in a mixed order | At least 7 recognized correctly |
| False taps | Wave the case for 15 seconds without tapping | No more than 1 false tap |
| Pointing | Aim at 5 rings and tap on each | At least 4 rings hit |

If motion stops, the app explains what to try and continues by itself once motion returns.

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
