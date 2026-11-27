# trmnl-menubar

A macOS menu bar app that shows the screen your [TRMNL](https://trmnl.com) device is currently displaying. Click the icon to see the image.

It reads `GET /api/current_screen`, so it never advances your playlist. The image refreshes every 5 minutes and each time you open the popover.

## Install

Needs macOS 14+ and the Xcode command line tools.

```bash
make install
```

```bash
open /Applications/TRMNL.app
```

On first launch, click the menu bar icon and paste your device API key (TRMNL → Devices → your device → API Key). The key is stored in your macOS Keychain, never in this repo or in a file.

The build is ad-hoc signed, so after a rebuild macOS asks once whether the new build may read the key; choose "Always Allow".

## Develop

```bash
make run
```

```bash
make test
```
