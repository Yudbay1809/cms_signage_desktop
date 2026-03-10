# CMS Signage Desktop

[![Flutter CI](https://github.com/Yudbay1809/cms_signage_desktop/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/Yudbay1809/cms_signage_desktop/actions/workflows/flutter-ci.yml)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-success)
![Flutter](https://img.shields.io/badge/Flutter-3.38.x-blue)
![License](https://img.shields.io/badge/license-MIT-informational)

Desktop CMS built with Flutter for digital signage operations: upload media, build playlists, schedule content, manage devices, and configure Flash Sale campaigns.

## Final Release Notes
- Final validation passed for analyze, tests, release build, and app startup smoke.
- CMS is aligned with backend final contract and websocket realtime refresh behavior.
- Recommended production setup uses static backend base URL on LAN.

## Latest Updates (2026-03-11)
- Safe Mode (default ON): tanpa popup spam, refresh manual saja, realtime socket dimatikan untuk server yang sibuk.
- Device Health Summary panel: ringkasan online/offline, cache ready, last seen, missing media.
- Batch Apply Validation Guard: sebelum apply massal, CMS validasi cache readiness agar tidak memaksa device yang belum siap.
- `Kelola Playlist` is now global:
  - playlist list can be opened without selecting device first.
  - dropdown includes source context (`device/screen`) to avoid ambiguity.
- `Apply ke semua device terpilih` now ignores Flash Sale playlist templates:
  - prevents accidental Flash Sale UI trigger when applying regular playlists.
  - if selected name is Flash Sale-only, CMS shows warning and blocks mass-apply.
- Flash Sale scheduler now supports optional date range (`Tanggal mulai` - `Tanggal selesai`) for non-recurring campaigns.
  - If date range is set, campaign will only run inside that period.
  - If date range is empty, recurring day-based schedule remains available.
- Runtime panel now provides per-device actions:
  - `Muat & Edit` to load latest stored Flash Sale config into form.
  - `Hapus` to hard delete Flash Sale draft/runtime on selected device.
- Flash Sale delete semantics:
  - `Nonaktifkan Flash Sale` = disable runtime only.
  - `Hapus` (runtime panel) = clear saved draft/runtime data from backend.
- Flash Sale scheduler UX simplified:
  - time input now focused on `HH:MM`
  - quick presets + time picker
  - clearer 2-step schedule flow (day -> time)
- Devices tab now includes **Cek Download Media** to verify per-device cache completeness from backend.
- Startup/background snackbar notification spam is disabled by default; manual toggle available (`Popup Notif: ON/OFF`).
- Previous updates:
- Central playlist apply mode: assigning playlist to other devices now references source playlist directly (no automatic clone per device).
- Auto refresh toggle removed to reduce background load; refresh now relies on realtime events and manual refresh.
- Playlist validation hardened in UI: photo + video cannot be mixed in the same playlist.
- Media tab now supports checkbox multi-select + bulk delete (`Hapus Terpilih`) for faster cleanup.

## Features
- Media management (upload, preview, delete)
- Bulk media cleanup with multi-select checkbox in Media tab
- Playlist builder with ordering
- Schedule management (create, edit, delete)
- Device management (orientation and cleanup)
- Backend server auto-discovery support
- Paginated media listing for large catalogs
- Flash Sale campaign editor (note, countdown, products + media)
- Apply Flash Sale now/scheduled directly per device (no playlist binding)
- Flash Sale media sync checker for selected target devices
- Device media download completeness checker (`Cek Download Media`) via backend cache status API

## Tech Stack
- Flutter / Dart
- `http`, `dio`
- `file_picker`, `desktop_drop`
- `video_player`

## Production Base URL Recommendation
- Use fixed backend URL (example: `http://192.168.x.x:8000`) for stable operations.
- Keep desktop and player pointed to the same backend environment (prod vs staging).

## Run Locally
```bash
flutter pub get
flutter run -d windows
```

## Quality Checks
```bash
flutter analyze
flutter test
```

## Build Release
```bash
flutter build windows --release
```

Output:
- `build/windows/x64/runner/Release/cms_signage_desktop.exe`

## Flash Sale Workflow
1. Open `Flash Sale` tab.
2. Fill `Note`, `Countdown`, and product rows (`name/brand/price/stock/media`).
3. Optional: set `Tanggal mulai` and `Tanggal selesai` to limit campaign window.
4. Select target devices.
5. Use `Tayangkan Sekarang` or `Jadwalkan Flashsale`.
6. Optional: use `Cek Sinkron Media Device` before publish.

## Final Smoke Checklist
1. Connect to backend and ensure device list loads.
2. Upload media and verify preview works.
3. Create playlist and assign to target screen.
4. Create schedule and confirm no overlap errors.
5. Trigger Flash Sale now/schedule and verify status update via websocket.

## Screenshots
Store screenshots in `docs/screenshots/` and keep references updated:
- `docs/screenshots/dashboard.png`
- `docs/screenshots/playlist-builder.png`
- `docs/screenshots/schedule-grid.png`
- `docs/screenshots/devices.png`

## Maintainer
- Yudbay1809

## Security
Report vulnerabilities privately as defined in `SECURITY.md`.

## Contributing
See `CONTRIBUTING.md`.

## License
MIT License. See `LICENSE`.
