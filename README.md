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
- AirPods with head tracking, such as AirPods Pro
- Swift 5.10 or later, from Xcode or the Command Line Tools

## Build and run

```bash
git clone https://github.com/abhav24/PodPointer.git
cd PodPointer
scripts/build-app.sh
open build/PodPointer.app
```

Use the script rather than `swift run`, because macOS only shows the motion permission to a real app bundle. The script signs with your Apple Development certificate if you have one. Otherwise it signs ad hoc, and macOS may ask for permissions again after each rebuild.

## Try it

1. Connect your AirPods to your Mac, put them in, and allow motion access.
2. Look at the middle of your display and select **Recenter**.
3. Set **Pointer** to **Laser dot** and turn your head.
4. Turn on **Listen for stem presses** and press a stem. The presses appear in the log.
5. To control slides, turn on **Send arrow keys to the front app** and allow Accessibility access. Then bring your slides to the front.

If you use **Mouse cursor** mode, moving a real mouse or trackpad turns head control off.

## Permissions and privacy

| Permission | Why it's needed | When |
|---|---|---|
| Motion & Fitness | Reads head motion from your AirPods | At launch |
| Accessibility | Sends arrow keys to your slide app | Only if you turn on sending keys |

PodPointer has no network code and doesn't save your data. A test report is only copied to your clipboard when you ask for one, and it leaves out your AirPods' name.

While it's listening for stem presses, PodPointer plays silent audio so it can act as the Mac's Now Playing app. That means stem presses won't control your music while listening is on.

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
