# Waqtara

A macOS menu bar app that reminds you of Islamic prayer times — offline, accurate
(Kemenag/Indonesia by default), bilingual (English/Indonesian). Focused on one thing:
a reliable prayer reminder. See [PRD-Waqtara.md](PRD-Waqtara.md) for the full product
spec (in Indonesian).

## Features

- **Offline prayer time calculation** — computed locally with
  [adhan-swift](https://github.com/batoulapps/adhan-swift). Kemenag Indonesia preset by
  default (Fajr 20°, Isha 18°), plus Muslim World League, Karachi, ISNA, Umm al-Qura,
  Egyptian, and a custom-angle option. Selectable Asr madhab, per-prayer precaution
  (ihtiyati) offsets, and rounding. No network required, ever.
- **Menu bar presence** — an icon with a live countdown ("Asr −00:42"), a dropdown panel
  with today's six times, the Gregorian + Hijri date, and the active location.
- **Three-phase reminders** — a pre-adhan heads-up, the adhan itself (with a *Stop Adhan*
  notification action), and a post-adhan follow-up. Each phase and each prayer can be
  toggled independently.
- **Friday prayer reminders** — on Fridays, extra notifications 2 hours and 1 hour before
  Dhuhr to prepare for Jumu'ah.
- **Custom reminder messages** — add your own line to the before/after-adhan reminders,
  **per prayer** (e.g. after Fajr "Read 5 verses of Quran", after Dhuhr "Exercise for 1
  minute"); it shows in both the notification and the center pop-up.
- **Center-screen pop-up** — an optional in-app alert drawn in the middle of the screen at
  prayer time (and Friday reminders), to cut through focus mode. Standard macOS
  notifications can only appear top-right; this is a window the app draws itself.
- **Adhan playback** — bundled audio, played precisely on time; skipped if it would fire
  late (e.g. right after the Mac wakes). Independent volume, silent mode, stop from the
  notification / panel / Settings.
- **~1,700 cities** worldwide (all Indonesian cities + major world cities and capitals),
  bundled offline. Optional one-time location auto-detect via CoreLocation.
- **Launch at login**, a 3-step onboarding, and full **English / Indonesian** UI
  (English is the default).

## Build & run

Requires a full Xcode install (not just Command Line Tools).

```bash
swift test                 # unit tests, incl. Kemenag accuracy check
swift run waqtara-cli      # print today's schedule for Jakarta
swift run waqtara-cli -7.25 112.75 Asia/Jakarta Surabaya 2026-06-01

./Scripts/make-app.sh      # assemble dist/Waqtara.app (notifications require an .app bundle)
./Scripts/make-dmg.sh      # build a distributable dist/Waqtara-<version>.dmg
open dist/Waqtara.app
```

`make-app.sh` produces a **universal binary** (Apple Silicon + Intel), so it runs on any
Mac with macOS 13 Ventura or later. For a faster single-arch dev build:
`WAQTARA_ARCH=--arch\ arm64 ./Scripts/make-app.sh`.

## Installing locally (no App Store)

Waqtara ships outside the App Store — the macOS equivalent of a Windows `.exe` is the
`.app` bundle, distributed via a `.dmg` (or zip) you can share over Drive, etc.

- **On your own Mac:** just copy it in — `cp -R dist/Waqtara.app /Applications/` — then
  launch once. With *Launch at login* on (default), it starts itself thereafter.
- **On someone else's Mac:** because the app is only ad-hoc signed (not yet notarized by
  Apple), Gatekeeper warns on first open. They clear it once via **System Settings →
  Privacy & Security → Open Anyway** (or `xattr -d com.apple.quarantine
  /Applications/Waqtara.app`). Wider, warning-free distribution needs an Apple Developer
  ID + notarization — still no App Store required.

## Accuracy & the city database

Prayer times are computed offline from each city's coordinates, so accuracy depends on
those coordinates matching Kemenag's reference point. The default precaution offsets were
calibrated against the official bimasislam schedule (Fajr +2, Sunrise −4, Dhuhr +3,
Asr +2, Maghrib +3, Isha +2, rounding **up**).

- For the five calibration cities (Jakarta, Surabaya, Medan, Makassar, Tangerang Selatan)
  the result is within **≤1 minute** of Kemenag on the tested dates (see the unit test).
- Across the broader bundled database, spot checks land within **~1–5 minutes**. Users can
  fine-tune any city with the per-prayer ihtiyati offsets in Settings.

### Method preset by region

Picking a city applies a sensible method automatically, while keeping your Asr madhab
choice untouched (madhab is a fiqh choice, not geography):

- **Indonesia** → Kemenag (Fajr 20°/Isha 18°) with the calibrated ihtiyati offsets.
- **Everywhere else** → Muslim World League with no offsets — this matches common
  international schedules (e.g. Google) to within ~1 minute for Rio de Janeiro, Auckland,
  and Johannesburg. Cities in countries with their own authority (Turkey's Diyanet,
  like Indonesia's Kemenag) may differ by a few minutes; switch method manually if needed.

Note: Google's international times use the **Hanafi** Asr; Waqtara defaults to **Shafi**
(the majority choice for its Indonesian audience). Set madhab to Hanafi in Settings to
match Google's Asr exactly.

The city database (`Sources/WaqtaraCore/Resources/cities.json`) is generated from the
[GeoNames](https://www.geonames.org/) `cities15000` dataset (licensed CC BY 4.0):

```bash
# dev-time only; the produced JSON is bundled so the app stays fully offline
curl -sL -o cities15000.zip https://download.geonames.org/export/dump/cities15000.zip
unzip cities15000.zip
python3 Scripts/generate-cities.py cities15000.txt Sources/WaqtaraCore/Resources/cities.json
```

## Bundled adhan audio

`Sources/WaqtaraApp/Resources/azan-standard.mp3` and `azan-shubuh.mp3` hold the adhan
played at prayer times (Fajr uses the `-shubuh` file, other prayers use `-standard`).
Replace either file in place (keep the names) to use your own recording.

## Known limitations

- System-wide audio ducking is not available on macOS (that API is iOS-only), so the
  adhan plays at an independent volume rather than lowering other apps.
- The app is ad-hoc signed; notarization is pending (Milestone 5).

## Attribution

- Prayer time engine: [adhan-swift](https://github.com/batoulapps/adhan-swift) (MIT)
- City coordinates: [GeoNames](https://www.geonames.org/) (CC BY 4.0)
- Kemenag accuracy reference: [api.myquran.com](https://api.myquran.com) / bimasislam

Licensed under the [MIT License](LICENSE).
