# Feasibility notes

Research from November 2026. Items marked "not verified" still need testing with the [test plan](TESTING.md).

| Idea | Status | Notes |
|---|---|---|
| Head-controlled pointer | Expected to work | [`CMHeadphoneMotionManager`](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager.md) is available on macOS 14+. [PodsControlMac](https://dev.to/sumionochi/podscontrolmac-1fff) describes the same approach. |
| Slide clicker using stem presses | Not verified | Depends on whether macOS delivers stem presses to this app as media commands. |
| Case as a mouse | Not possible as far as I can find | I found no developer access to motion data from the case. |
| Case lid as a trigger | Not pursued | Bluetooth broadcasts reportedly include a [lid-open counter](https://dev.to/lifeart/inside-apple-airpods-auto-switching-bluetooth-continuity-aap-python-packet-sniffing-jf6). It's undocumented and could change with a firmware update. |
| Nod or shake gestures | Possible later | I found no public gesture API, but these could be detected from the motion data. |
| AirPod held in the hand | Not verified | Motion data may stop once an AirPod leaves your ear. |

## Known risks

- **Drift and jumps:** developers have reported [yaw jumps when Spatial Audio turns on](https://developer.apple.com/forums/thread/844940). Recentering is part of the design for this reason.
- **Bluetooth load:** the constant motion stream [can make a Bluetooth mouse lag](https://github.com/Cogria-AI/HeadOrbit/wiki).
- **Compatible models:** [Apple's session](https://wwdcnotes.com/notes/wwdc23/10179) names AirPods Pro, and third-party packages also list [AirPods 3, AirPods Max, and Beats Fit Pro](https://pub.dev/documentation/flutter_airpods/1.0.4).
- **Now Playing:** another media app may take the stem presses.
- **Full-screen slideshows:** a slide app could cover the overlay window.

## Related projects

- [PodsControlMac](https://dev.to/sumionochi/podscontrolmac-1fff): cursor control, scrolling, and dictation using AirPods
- [HeadOrbit](https://github.com/Cogria-AI/HeadOrbit/wiki): head movements mapped to Mac actions
- [gazectl](https://github.com/AndreasInk/gazectl): head tracking to switch displays

PodPointer focuses on presenting.
