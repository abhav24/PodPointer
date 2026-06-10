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

1. Connect your AirPods to your Mac and select them as the sound output.
2. Open the AirPods section of System Settings and turn off **Automatic Ear Detection**. You can turn it back on when you're done.
3. Put the AirPods in the case and **keep the lid open**. Closing the lid disconnects them.
4. Open PodPointer and allow motion access.
5. Select **Calibrate** and follow the steps while holding the case the way you'll use it.
6. Choose **Presenter** or **Mouse**. Taps only appear in the log until you turn on **Send keys and clicks** and allow Accessibility access.

If you use Mouse mode, moving a real mouse or trackpad pauses the case until you stop.

## Permissions and privacy

| Permission | Why it's needed | When |
|---|---|---|
| Motion & Fitness | Reads motion from your AirPods | At launch |
| Accessibility | Sends arrow keys and clicks | Only if you turn on sending |

PodPointer has no network code. It saves your calibration and settings on your Mac only. Test reports are copied to your clipboard only when you ask, and they leave out your AirPods' name.

## Known limits

## Project layout

| Path | Contents |
|---|---|
| `Sources/PodPointerCore` | Tested logic: filtering, pointer mapping, timing, and press handling |
| `Sources/PodPointer` | The Mac app: motion, media commands, key sending, overlay, and window |
| `Tests/PodPointerCoreTests` | Unit tests |
| `docs` | Feasibility notes and the hardware test plan |

## Contributing

Hardware test results are the most useful contribution right now. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)

PodPointer is an independent project and isn't affiliated with or endorsed by Apple Inc. AirPods, Mac, and macOS are trademarks of Apple Inc.
