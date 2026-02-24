# Feasibility notes

Research from November 2026. Items marked "not verified" still need testing with the [test plan](TESTING.md).

| Idea | Status | Notes |
|---|---|---|
| Head-controlled pointer | Expected to work | [`CMHeadphoneMotionManager`](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager.md) is available on macOS 14+. [PodsControlMac](https://dev.to/sumionochi/podscontrolmac-1fff) describes the same approach. |
| Slide clicker using stem presses | Not verified | Depends on whether macOS delivers stem presses to this app as media commands. |
| Case as a mouse | Not possible as far as I can find | I found no developer access to motion data from the case. |
| Case lid as a trigger | Not pursued | Bluetooth broadcasts reportedly include a [lid-open counter](https://dev.to/lifeart/inside-apple-airpods-auto-switching-bluetooth-continuity-aap-python-packet-sniffing-jf6). It's undocumented and could change with a firmware update. |
| Nod or shake gestures | Possible later | I found no public gesture API, but these could be detected from the motion data. |
