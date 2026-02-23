# RELEASE NOTES v1.0.2

Tanggal: 2026-02-23

## Ringkasan
Patch ini menambahkan observability Smart Sync di tab Devices agar operator CMS bisa memantau progress queue sinkronisasi media per-device.

## Perubahan Utama
- API client desktop ditambah endpoint:
  - fetch `GET /devices/{device_id}/sync-status`
- UI Devices ditingkatkan:
  - tombol `Cek Sync Queue`
  - panel status queue per-device
  - badge status queue + progress per row device
- Alur existing download-request tetap dipertahankan.

## Dampak
- Monitoring sinkronisasi media menjadi lebih jelas dari sisi operator.
- Troubleshooting device yang belum ready jadi lebih cepat.
