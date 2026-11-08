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

## 2. Try it with slides

The last setup step walks you through a real slideshow. This passes if the slides change and the dot stays visible. If you can, also try an external display, using **Display** on the home screen to select it.

## 3. Try Mouse mode

Choose **Mouse**, then move the cursor and tap a button. Move a real mouse too, and check that the case pauses until you stop.

This passes if clicks land where you aim.

## Share your results

On the home screen, open **Advanced** and select **Copy Test Report**, then paste it into a [test report issue](https://github.com/abhav24/PodPointer/issues/new?template=test-report.md).
