# PodPointer

Use your AirPods as a hands-free slide clicker and laser pointer for your Mac.

Turn your head to move a laser dot over your slides. Press an AirPods stem to change slides.

> **Status: early test app.** This release exists to find out whether the idea holds up on real hardware. Motion and stem-press behavior have not been confirmed on AirPods yet, and [you can help test it](docs/TESTING.md).

## What it does

| Your AirPods | Your Mac |
|---|---|
| Turn or tilt your head | Moves a laser dot or the mouse cursor |
| Press the stem once | Next slide (Right Arrow) |
| Press the stem twice | Recenter the pointer |
| Press the stem three times | Previous slide (Left Arrow) |

The app also shows live motion measurements and can copy a test report to paste into an issue.

**The AirPods case isn't part of this.** I found no developer access to motion data from the case, so it can't work as a mouse. See [feasibility notes](docs/FEASIBILITY.md).

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
