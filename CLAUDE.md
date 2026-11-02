# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is this

The iOS app for Chores (household chores — who did what, when). It looks and works like choresweb's phone layout (`../choresweb`) and talks to the same API (`../choresapi`).

**The three repos are one project.** An endpoint or DTO change in `../choresapi` usually needs the matching change in `Chores/API/Endpoints.swift` as well as in `../choresweb/src/api/`; a UI or behaviour change in choresweb usually belongs here too.

## Commands

```bash
open Chores.xcodeproj    # then run the Chores scheme
xcodebuild -project Chores.xcodeproj -scheme Chores -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build
```

The app talks to `https://chores.forstberg.net`. To use a local API instead, set the environment variable `CHORES_API_URL=http://127.0.0.1:5072` in the scheme (or `SIMCTL_CHILD_CHORES_API_URL` with `simctl launch`). Use `127.0.0.1`, not `localhost`: App Transport Security lets plain HTTP through to IP addresses only.

## Architecture

SwiftUI, iOS 17, no dependencies. The project uses a synchronized folder: every file under `Chores/` is part of the target without editing `project.pbxproj`.

- **Staying logged in** — `API/API.swift`. Login and register send `refreshToken: true`; the refresh token goes in the Keychain (`API/Keychain.swift`), the JWT (valid one day) only in memory. When the JWT is missing or a request gets 401, `refresh()` fetches a new one at `POST /api/auth/refresh`; concurrent requests share one refresh. Only a 401 from the refresh logs out — being offline never does. Logging out calls `POST /api/auth/logout`, which deletes the token server side. Changing the password sends the token along so this device stays logged in while the API logs out every other one.
- `API/Endpoints.swift` — models and calls, mirroring choresweb's `src/api/`.
- `Lib/Store.swift` — me, household and chores, shared by every screen and reloaded when the app comes to the foreground and on pull to refresh. Screens load their own claims and completions, keyed on `Store.revision`.
- `Lib/Week.swift`, `Lib/Members.swift` — ports of choresweb's `src/lib/week.ts` and `members.ts` (ISO weeks; members' initials and colours). Keep them in step.
- `Lib/L10n.swift` — `t("week.add")` looks up `Resources/sv.json`/`en.json`, copies of choresweb's locales (without `landing`, plus `common.retry` and `common.cancel`). Swedish when the phone's first language is Swedish, otherwise English.
- `Lib/Theme.swift` — choresweb's design tokens (light and dark) and the Familjen Grotesk font (`Resources/FamiljenGrotesk.ttf`, OFL, registered at launch).
- `Views/` — `WeekView` (choresweb's narrow day view: day strip, chore rows, chips, quota dots), `SummaryView`, `HistoryView`, `HouseholdView`, `AccountView`, `NoHouseholdView`, `AuthView` (login, register). `Components.swift` has the shared button styles, cards, fields, `FlowLayout` and `TwoInk` (the off-register pink and blue headline).

Signing: set your team under Signing & Capabilities before running on a device. Bundle id `net.forstberg.chores`.
