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

## Latest Updates (2026-02-13)
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
3. Select target devices.
4. Use `Tayangkan Sekarang` or `Jadwalkan Flashsale`.
5. Optional: use `Cek Sinkron Media Device` before publish.

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
