# RELEASE NOTES v1.0.3

Tanggal: 2026-03-11

## Ringkasan
Patch ini menambahkan mode tenang (no popup), panel ringkasan kesehatan device, dan guard validasi sebelum apply massal.

## Perubahan Utama
- Safe Mode default ON: tanpa popup spam, refresh manual, realtime socket dimatikan.
- Device Health Summary panel (online/offline, cache ready, last seen, missing media).
- Batch Apply Validation Guard sebelum apply playlist/flash sale massal.

## Dampak
- Popup tidak mengganggu saat CMS dibuka.
- Operator cepat cek kesiapan device dari satu panel.
- Menghindari apply ke device yang cache-nya belum siap.
