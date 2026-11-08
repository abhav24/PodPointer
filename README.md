# PodPointer

Point your AirPods case at the screen and tap it. PodPointer turns the case into a presentation remote and air mouse for your Mac.

> **Status: early and not yet proven on real hardware.** The logic has unit tests, but the full experience hasn't been confirmed with AirPods. [Help test it](docs/TESTING.md).

## How it works

The AirPods inside the case have motion sensors. When you move the case, they move with it, so PodPointer reads their motion through Apple's public `CMHeadphoneMotionManager` API.

- **Pointing:** rotating the case moves a pointer, the way moving a mouse moves the cursor.
- **Tapping:** a short jolt while your hand is steady counts as a tap.
- **Calibration:** the AirPods can sit at any angle in your hand, so a short setup learns which movement means right and up, and how hard you tap.

Read more in [how it works](docs/HOW-IT-WORKS.md).

## Controls

| Case | Presenter mode | Mouse mode |
|---|---|---|
| Rotate | Moves a laser dot | Moves the cursor |
| Tap | Next slide | Click |
| Double-tap | Previous slide | Double-click |
| Triple-tap | Turns the laser dot on or off | Pauses or resumes the cursor |

## Requirements

- macOS 14 or later
- AirPods that support head tracking, such as AirPods Pro
- Swift 5.10 or later, from Xcode or the Command Line Tools

## Build and run

```bash
git clone https://github.com/abhav24/PodPointer.git
cd PodPointer
scripts/build-app.sh
open build/PodPointer.app
```

Use the script rather than `swift run`, because macOS only shows the motion permission to a real app bundle.

## Set up

Open the app and follow the steps on screen. Setup takes about 5 minutes and covers:

1. Connecting your AirPods
2. Turning off **Automatic Ear Detection**, which you need to do yourself because no Shortcut or public API can change it
3. Putting the AirPods in the case with the **lid open**
4. Calibrating for your grip
5. Scored tests for tapping, single, double, and triple taps, false taps, and aiming
6. Trying real slides

You can run setup again from **Advanced**.

## Permissions and privacy

| Permission | Why it's needed | When |
|---|---|---|
| Motion & Fitness | Reads motion from your AirPods | At launch |
| Accessibility | Sends arrow keys and clicks | Only if you turn on sending |

PodPointer has no network code. It saves your calibration and settings on your Mac only. Test reports are copied to your clipboard only when you ask, and they leave out your AirPods' name.

During setup, PodPointer also records raw motion to `~/Library/Application Support/PodPointer/last-setup-motion.csv` so tap detection can be tuned against real taps. Each setup run replaces that file, and it stays on your Mac unless you share it.

## Known limits

- The lid has to stay open, and open-lid battery use hasn't been measured.
- Automatic Ear Detection has to be off.
- Calibration applies to one AirPod and one grip. If motion moves to the other AirPod, or you change your grip, calibrate again.
- A closed-lid mode would need a private Bluetooth channel, so it isn't included.

## Related projects

[PodMouse](https://github.com/0xCodez/PodMouse) and [AirPointer](https://github.com/oscarcreatess/airpointer) also turn an AirPods case into a pointer. PodPointer focuses on presenting.

## Contributing

Results from real AirPods are the most useful contribution right now. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)

PodPointer is an independent project and isn't affiliated with or endorsed by Apple Inc. AirPods, Mac, and macOS are trademarks of Apple Inc.
