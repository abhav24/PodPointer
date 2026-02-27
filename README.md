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

