# Touchpaddy
Cross-platform (wip) libinput touchpad gesture bindings for Linux, especially for KDE Plasma (6)!
## Features
### Two finger forward/back in web browsers
- A quick two-finger horizontal "scroll" should prompt back/forwards in Firefox, Edge, and Chromium-based web browsers. (X11 w/ xdotool)
### Three finger gestures
- swipe left-right to `Alt-Tab` between open windows
- swipe up to view the task view/present windows/grid display view like Windows + Tab on Windows
- swipe down to minimize all active windows (manually minimizes them with kwin, doesn't do the Meta + D Plasma keybind)
### Four finger gestures
- swipe left-right to quickly snap the active window to the left and right respectively
- swipe down to minimize the active window (conflicts with hardcoded Plasma 6 gestures in Wayland :/)
- swipe up to maximize the active window (conflicts with hardcoded Plasma 6 gestures in Wayland :/)

Gestures are defined in `./src/gestures.luau`; please feel free to add more gestures and if you have some good ones, PR them in! 

## Dependencies
1. The Lune runtime for Luau; requires the lune-process-stream PR: https://github.com/0x5eal/lune-process-stream
2. yad for gui dialogs
3. screen to run in background
3. kdotool (KDE Plasma 6)
4. ydotool (X11)

## Install
- clone and build [lunestream](https://github.com/0x5eal/lune-process-stream)
- add `lunestream` to your PATH
- run touchpaddy with `lunestream run path_to_touchpaddy` or `./path_to_touchpaddy/init.luau`, whichever works

Install script and QoL improvements forthcoming.
