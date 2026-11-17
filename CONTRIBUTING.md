# Contributing

## Share test results

Results from real AirPods are the most useful contribution right now.

1. Follow the [test plan](docs/TESTING.md).
2. Select **Copy Test Report** in the app.
3. Paste it into a new [test report issue](https://github.com/abhav24/PodPointer/issues/new?template=test-report.md) and fill in the blanks.

## Change the code

```bash
scripts/test.sh
scripts/build-app.sh
open build/PodPointer.app
```

- Put logic that doesn't need hardware in `PodPointerCore`, with tests.
- Keep Apple framework code in the `PodPointer` app target.
- Test changes to motion, tapping, or the overlay on real AirPods, and say so in your pull request.
- Discuss anything that relies on undocumented AirPods Bluetooth data in an issue first.

## Publish a release

1. Set the version in `Resources/Info.plist`.
2. Add release notes at `docs/release-notes/v<version>.md`.
3. Commit, then push a matching tag, such as `v1`. GitHub Actions tests the code, builds the disk image, and publishes the release.
