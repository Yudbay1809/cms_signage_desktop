# RELEASE NOTES v1.0.4

Tanggal: 2026-03-22

## Ringkasan
Patch ini menambahkan peringatan upload media ramah device 2GB di CMS agar operator tahu jika file terlalu besar sebelum dipakai.

## Perubahan Utama
- Validasi ukuran file upload di UI Media (warning jika melebihi rekomendasi).
- Validasi resolusi gambar (warning jika melebihi 1920x1080).
- Konfirmasi sebelum lanjut upload saat file terlalu besar.
- Indikator setelah upload bahwa device akan download via sync.

## Dampak
- Mengurangi risiko file berat masuk ke playlist.
- Operator langsung ingat untuk cek status download di Devices.
- Performa playback di device 2GB lebih stabil.
