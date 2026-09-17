# How it works

## Getting motion from the case

The case has no motion data that apps can read, but the AirPods inside it do. PodPointer reads them through Apple's public [`CMHeadphoneMotionManager`](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager.md) API, available on macOS 14 and later.

According to [PodMouse's README](https://github.com/0xCodez/PodMouse), this works with the lid open and Automatic Ear Detection off. With ear detection on, AirPods stop sending motion when they leave your ears, and closing the lid disconnects them. PodPointer hasn't confirmed this on hardware yet, which is why it's the first thing [setup](TESTING.md) tests.

No Shortcut, AppleScript command, or public API was found that changes Automatic Ear Detection, so you have to turn it off yourself. The app can't read the setting either, so it checks the result instead: if motion stops once the AirPods are in the case, the setting is probably still on.

## Calibration

The AirPods sit at an unknown angle in your hand, so the sensor's axes don't match the screen. Calibration has these steps:

1. **Hold still:** measures the gyroscope's resting error and the normal sensor noise.
2. **Sweep side to side:** finds the axis most of the rotation happened around.
3. **Turn right and stop:** sets which way along that axis is right, using the total angle turned.
4. **Sweep up and down:** does the same for vertical movement, then removes any overlap with the sideways axis.
5. **Tilt up and stop:** sets which way is up.
6. **Tap five times:** sets the tap threshold at 60% of your typical tap strength, and above the noise.

Each step waits for your hand to stop first, so motion left over from the previous step can't affect it. If a direction still comes out reversed, there are flip switches during the aiming test and under **Advanced**.

## Pointing

Rotation speed around the two calibrated axes moves the pointer, like a mouse. PodPointer then:

- ignores very slow rotation, which is usually hand tremor
- speeds up fast movements, up to 1.6 times
- smooths the position with a [One Euro filter](https://gery.casiez.net/1euro/)
- eases the pointer between samples so it draws smoothly at a high frame rate

This doesn't depend on an absolute direction, so drift doesn't build up the way it can with absolute orientation. If your aim and the pointer get out of line, push the pointer against a display edge.

## Tapping

A tap is a sudden change in acceleration between two samples that:

- is above your calibrated threshold
- stands out from recent movement
- isn't explained by the fading shake from an earlier tap
- doesn't happen during fast rotation, unless it's part of a tap group

Following the shake as it fades lets quick double and triple taps through, while the shake itself doesn't count as extra taps.

Tapping also shakes the case, so the pointer jumps back to where it was just before the tap and stays there briefly.

A single tap waits 0.4 seconds in case another tap follows. That's the delay you'll notice before the next slide appears, and you can adjust it with **Time between taps**.

The AirPods bounce inside the case, so one real tap can show up as two jolts up to about 100 ms apart. Jolts closer than 140 ms count as one tap.

These values were tuned on one recording from one person using AirPods Pro, which is saved as a test in `Tests/PodPointerCoreTests/Fixtures`. Setup records raw motion locally so they can be tuned against more real taps.

## Open questions

- Does motion arrive reliably from the open case, on which AirPods models?
- Can taps be told apart from hand movement at the motion rate the AirPods provide?
- Does motion stay on one AirPod? The two AirPods sit at different angles, so a switch needs a new calibration.
- Does the laser dot stay above full-screen slideshows?
- How quickly does this use battery with the lid open?
