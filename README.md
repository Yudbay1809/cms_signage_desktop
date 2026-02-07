# CMS Signage Desktop

Desktop CMS berbasis Flutter untuk operasional digital signage:
upload media, buat playlist, atur schedule, dan kontrol banyak device sekaligus.

## Fitur Utama
- Manajemen media (upload, preview, delete)
- Playlist builder + urutan konten drag-and-drop
- Schedule editor (create/edit/delete)
- Multi-device assignment playlist
- Device management (orientation, delete, bulk delete)
- Auto-discovery server + retry network
- Pagination media agar server lebih ringan

## Alur Operasional
1. Set `Base URL` backend (auto detect tersedia)
2. Upload media (gambar/video)
3. Buat playlist dari media
4. Atur schedule
5. Apply playlist ke device yang dipilih

## UI Preview
> Simpan screenshot di `docs/screenshots/` lalu update nama file berikut.

![Dashboard](docs/screenshots/dashboard.png)
![Playlist Builder](docs/screenshots/playlist-builder.png)
![Schedule & Grid Preset](docs/screenshots/schedule-grid.png)
![Device Management](docs/screenshots/devices.png)

## Jalankan Project
```bash
flutter pub get
flutter run -d windows
```

## Build Release
```bash
flutter build windows --release
```
