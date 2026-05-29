# How it works

## Getting motion from the case

The case has no motion data that apps can read, but the AirPods inside it do. PodPointer reads them through Apple's public [`CMHeadphoneMotionManager`](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager.md) API, available on macOS 14 and later.

According to [PodMouse's README](https://github.com/0xCodez/PodMouse), this works with the lid open and Automatic Ear Detection off. With ear detection on, AirPods stop sending motion when they leave your ears, and closing the lid disconnects them. PodPointer hasn't confirmed this on hardware yet, which is why it's the first item in the [test plan](TESTING.md).

## Calibration
