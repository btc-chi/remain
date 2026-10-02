# Rootwork (codename)

A daily place to pray, read, write, and remember. Three rings for the Trinity: **Pray** (the Father), **Read** (the Son), **Write** (the Spirit). See [CONCEPT.md](CONCEPT.md) for the product thinking.

## Run it on your Mac

You need macOS with **Xcode 26** (for iOS 26 and Liquid Glass) and Homebrew.

```bash
git clone <your repo url> rootwork
cd rootwork/ios
brew install xcodegen
xcodegen
open Rootwork.xcodeproj
```

In Xcode: pick the **Rootwork** scheme and an **iPhone 17 Pro** simulator, then press **⌘R**.

### Running on your own iPhone

1. Xcode → Settings → Accounts → add your Apple ID.
2. Select the project → each target → Signing & Capabilities → choose your Team.
3. Plug in the phone, select it as the run destination, press ⌘R.

App rest (Screen Time) and the shared App Group need a **paid Apple Developer account** on a real device. The simulator runs everything else, but Screen Time authorization doesn't work there, so the "Rest your apps" row will just fail quietly. If signing complains about Family Controls on a free account, remove the `GateMonitor` and `GateShield` dependencies from `project.yml`, delete the `com.apple.developer.family-controls` lines, and run `xcodegen` again.

### After changing project.yml

Run `xcodegen` again. The `.xcodeproj` is generated, so don't edit it by hand.

## What's where

| Path | What |
|---|---|
| `ios/Rootwork/Views` | Today, Bible (+ walking guide), Pray, Journal, Sword, You, onboarding, the Rootwork flow |
| `ios/Rootwork/Shared` | Trinity rings and colors, widget bridge, Screen Time state (shared with extensions) |
| `ios/Rootwork/Resources` | Bundled content: verses (WEB), verse-of-the-day list, Sword moments, the walking guide |
| `ios/RootworkWidgets` | Home and Lock Screen widgets: rings and verse of the day |
| `ios/GateMonitor`, `ios/GateShield` | Re-rest apps at 4 AM; the "Abide first." shield |
| `ios/tools` | Scripts that rebuild the bundled content and seed data |
| `prototype/` | HTML previews (`today.html` is the current design) |

## Rebuilding content

```bash
python ios/tools/parse_guide.py ios/tools/walking-guide.html   # guide.json from the walking guide
python ios/tools/fetch_verses.py                              # verses.json (World English Bible)
python ios/tools/gen_seed.py                                  # SeedData.swift (your prayers, people)
```

Bible text is the World English Bible (public domain) from bible-api.com, cached on device after first read. Production plan: YouVersion Platform for NIV and other licensed versions.
