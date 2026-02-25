# Hardware test plan

This test answers four questions that unit tests can't. Allow about 15 minutes.

**Setup**
- Build and open the app by following the [README](../README.md).
- Connect your AirPods to the Mac, not your phone, and put them in.
- Pause any music.

## 1. Do stem presses reach the app?

1. Turn on **Listen for stem presses**, and leave **Send arrow keys** off.
2. With PodPointer in front, press a stem once, twice, and three times. Check **Presses received**.
3. Open a slide deck in PowerPoint or Keynote and start the slideshow.
4. Press a stem 10 times, then return to PodPointer and check the count.
5. Turn on **Send arrow keys**, allow Accessibility access, and repeat with the slideshow in front.

**Passes if** all 10 presses arrive and the slides change.

Try again with Spotify or Apple Music open, because another media app may take the presses.

## 2. Is the pointer good enough to present with?
