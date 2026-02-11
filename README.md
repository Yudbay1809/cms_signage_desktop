# CMS Signage Desktop

[![Flutter CI](https://github.com/Yudbay1809/cms_signage_desktop/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/Yudbay1809/cms_signage_desktop/actions/workflows/flutter-ci.yml)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-success)
![Flutter](https://img.shields.io/badge/Flutter-3.38.x-blue)
![License](https://img.shields.io/badge/license-MIT-informational)

Desktop CMS built with Flutter for digital signage operations: upload media, build playlists, schedule content, manage devices, and configure Flash Sale campaigns.

## Features
- Media management (upload, preview, delete)
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

## Flash Sale Workflow
1. Open `Flash Sale` tab.
2. Fill `Note`, `Countdown`, and product rows (`name/brand/price/stock/media`).
3. Select target devices.
4. Use `Tayangkan Sekarang` or `Jadwalkan Flashsale`.
5. Optional: use `Cek Sinkron Media Device` before publish.

## Screenshots
Store screenshots in `docs/screenshots/` and keep references updated:
- `docs/screenshots/dashboard.png`
- `docs/screenshots/playlist-builder.png`
- `docs/screenshots/schedule-grid.png`
- `docs/screenshots/devices.png`

## Security
Report vulnerabilities privately as defined in `SECURITY.md`.

## Contributing
See `CONTRIBUTING.md`.

## License
MIT License. See `LICENSE`.
