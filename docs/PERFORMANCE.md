# Performance

Measured on 2026-09-22 using a release build, Apple silicon, and macOS 27.0. These are short process measurements on a desktop Mac, not a laptop battery discharge test.

## Results

The original and optimized apps ran the same saved 1-hour-45-minute timer and display settings side by side. Each background sample lasted 30 seconds. CPU percentages refer to one CPU core, matching Activity Monitor's convention.

| State | Average CPU | Physical memory footprint |
| --- | ---: | ---: |
| Original, timer running and menu closed | 6.963% | 46.0 MiB |
| Optimized, timer running before first menu opening | 0.067% | 13.2 MiB |
| Optimized, timer running after opening and closing the menu | 0.033% | 35.3 MiB |
| Optimized, timer menu visible (15-second sample) | 1.332% | 37.4 MiB |
| Optimized, paused and menu closed (20-second sample) | 0.100% | 36.6 MiB |

The warmed background sample used roughly 99% less CPU and 23% less physical memory than the original in this run. Cold startup is lighter because SwiftUI is not instantiated until the menu opens. Framework caches remain after closing the menu, so the warmed footprint does not return to the cold-start number.

The optimized process recorded a transient lifetime peak of 263.4 MiB after the first menu opening and 273.5 MiB after further interaction, compared with 379.4 MiB for the earlier process. Those peaks cover different interaction histories and are not a controlled comparison. Memory can rise temporarily when macOS loads interface resources; this change does not eliminate that peak.

## What changed

- The SwiftUI menu is created on demand and released after closing. Only lightweight input and tab state remain.
- Timer refreshes no longer publish an unchanged session to the entire view tree. A visible countdown publishes at most once per displayed second.
- The bar updates at the rate needed to move a physical pixel, bounded between one update every 60 seconds and four per second. A visible seconds counter limits that interval to at most one second.
- Screen geometry and layer colors are recalculated when configuration changes. Progress changes update only the filled width, and skip unchanged pixel widths.
- The status icon redraws on phase or percentage changes. Countdown text updates do not recreate its image.
- Idle and paused sessions have no scheduled timer callback. While displays sleep, only the actual completion deadline remains scheduled.
- Overlay windows are released when a timer stops or completes. Timer ticks do not write preferences.

For example, a 24-hour timer spanning 3,840 physical pixels needs a bar update about every 22.5 seconds. The completion callback is scheduled at the deadline even when it falls before the next visual update. Timer accuracy does not depend on the redraw frequency.

## Reproduce

Build in release mode, start a timer, close the menu, and let startup activity settle. Obtain its PID with `pgrep -x Timebar`; if multiple copies are running, identify the intended process before measuring.

```sh
python3 scripts/measure-resources.py PID --seconds 30 --label running-menu-closed
```

The script reads cumulative process CPU time before and after the interval and uses `vmmap -summary` for physical footprint. It also reports resident memory and lifetime peak; these are different metrics and should not be interchanged. CPU time has finite precision, so a rounded zero in a short idle sample does not prove that the app never consumes CPU.

Repeat with the menu open, after closing it, while paused, and while idle. Keep the timer duration, display setup, and menu countdown setting consistent. Longer samples on a MacBook, plus Instruments' Energy Log, are needed for a battery-life claim. Short timers, higher-resolution displays, and an open menu require more updates than a long background timer.
