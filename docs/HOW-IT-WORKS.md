# How it works

## Getting motion from the case

The case has no motion data that apps can read, but the AirPods inside it do. PodPointer reads them through Apple's public [`CMHeadphoneMotionManager`](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager.md) API, available on macOS 14 and later.

According to [PodMouse's README](https://github.com/0xCodez/PodMouse), this works with the lid open and Automatic Ear Detection off. With ear detection on, AirPods stop sending motion when they leave your ears, and closing the lid disconnects them. PodPointer hasn't confirmed this on hardware yet, which is why it's the first item in the [test plan](TESTING.md).

## Calibration

The AirPods sit at an unknown angle in your hand, so the sensor's axes don't match the screen. Calibration has four steps:

1. **Hold still:** measures the gyroscope's resting error and the normal sensor noise.
2. **Sweep sideways:** finds the axis most of the rotation happened around. Your first movement is to the right, which sets the direction.
3. **Sweep up and down:** does the same for vertical movement, then removes any overlap with the sideways axis.
4. **Tap five times:** sets the tap threshold at 60% of your typical tap strength, and above the noise.

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
- starts while the hand has been steady for the last quarter of a second
- ends within 0.16 seconds, because longer jolts are usually hand movements

Tapping also shakes the case, so the pointer jumps back to where it was just before the tap and stays there briefly.

A single tap waits 0.35 seconds in case a second tap follows. That's the delay you'll notice before the next slide appears.

## Open questions

- Does motion arrive reliably from the open case, on which AirPods models?
- Can taps be told apart from hand movement at the motion rate the AirPods provide?
- Does motion stay on one AirPod? The two AirPods sit at different angles, so a switch needs a new calibration.
- Does the laser dot stay above full-screen slideshows?
- How quickly does this use battery with the lid open?
