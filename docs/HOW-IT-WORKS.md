# How it works

## Getting motion from the case

The case has no motion data that apps can read, but the AirPods inside it do. PodPointer reads them through Apple's public [`CMHeadphoneMotionManager`](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager.md) API, available on macOS 14 and later.

According to [PodMouse's README](https://github.com/0xCodez/PodMouse), this works with the lid open and Automatic Ear Detection off. With ear detection on, AirPods stop sending motion when they leave your ears, and closing the lid disconnects them. PodPointer has confirmed this on AirPods Pro 2. Other models are untested, which is why it's the first thing [setup](TESTING.md) checks.

No Shortcut, AppleScript command, or public API was found that changes Automatic Ear Detection, so you have to turn it off yourself. The app can't read the setting either, so it checks the result instead: if motion stops once the AirPods are in the case, the setting is probably still on.

## Calibration

The AirPods sit at an unknown angle in your hand, so the sensor's axes don't match the screen. Calibration has these steps:

1. **Hold still:** measures the gyroscope's resting error and the normal sensor noise.
2. **Sweep side to side:** finds the axis most of the rotation happened around.
3. **Turn right and stop:** sets which way along that axis is right, using the total angle turned.
4. **Sweep up and down:** does the same for vertical movement, then removes any overlap with the sideways axis.
5. **Tilt up and stop:** sets which way is up.
6. **Tap five times:** sets the tap threshold at 60% of your typical tap strength, within a fixed range so hard taps here don't make lighter taps stop counting later. Motion that doesn't look like a tap is ignored here too.

Each step waits for your hand to stop first, so motion left over from the previous step can't affect it. If a direction still comes out reversed, there are flip switches during the aiming test and under **Advanced**.

## Pointing

Rotation speed around the two calibrated axes moves the pointer, like a mouse. PodPointer then:

- ignores very slow rotation, which is usually hand tremor
- speeds up fast movements, up to 1.6 times
- smooths the position with a [One Euro filter](https://gery.casiez.net/1euro/)
- eases the pointer between samples so it draws smoothly at a high frame rate

This doesn't depend on an absolute direction, so drift doesn't build up the way it can with absolute orientation. If your aim and the pointer get out of line, push the pointer against a display edge.

## Tapping

Moving or shaking the case can cause jolts larger than a tap, so size alone can't tell them apart. A jolt counts as a tap only if all of these are true:

- **It's strong enough:** it's above your calibrated threshold, and stands out from any shake left by an earlier tap.
- **The case was calm before it:** it wasn't turning quickly, accelerating, or jolting. Later taps in a group skip this check, because the shake from earlier taps is expected.
- **It was brief and sharp:** over the next 140 ms, the case barely turned and the acceleration appeared suddenly instead of building up.

A tap group only counts once the case stops jolting, so shaking the case doesn't trigger a gesture even if some jolts look like taps.

The pointer waits while a jolt is being checked. A tap then puts the pointer back where it was just before the tap and holds it briefly. If the jolt was the hand moving, which usually shows within a few samples, the pointer catches up and no movement is lost.

Hard knocks that swing the case look just like moving it, so they don't count. Tap lightly with one finger while holding the case steady.

A single tap waits 0.4 seconds in case another tap follows. That's the delay you'll notice before the next slide appears, and you can adjust it with **Time between taps**. A triple tap waits 0.3 seconds.

The AirPods bounce inside the case, so one real tap can show up as two jolts up to about 100 ms apart. Jolts closer than 140 ms count as one tap, and so does a much weaker jolt within 250 ms.

These values were tuned on two setup recordings from one person using AirPods, plus simulated shaking. The recordings are saved as tests in `Tests/PodPointerCoreTests/Fixtures`. Setup records raw motion locally so they can be tuned against more real taps.

## Open questions

- Which other AirPods models send motion from the open case?
- Do the tap limits work for other people's hands and tap styles?
- Does motion stay on one AirPod? The two AirPods sit at different angles, so a switch needs a new calibration.
- Does the laser dot stay above full-screen slideshows?
- How quickly does this use battery with the lid open?
