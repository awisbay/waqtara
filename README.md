# Waqtara

Aplikasi menu bar macOS pengingat waktu sholat. Lihat [PRD-Waqtara.md](PRD-Waqtara.md).

## Status

- ✅ **Milestone 1 — Inti kalkulasi**: `WaqtaraCore` (adhan-swift, preset Kemenag Fajr 20°/Isya 18°, custom angle, madhab, offset ikhtiyati, pembulatan) + `waqtara-cli`. Akurasi tervalidasi ≤1 menit vs jadwal Kemenag (fixture 5 kota × 5 tanggal 2026, sumber api.myquran.com/bimasislam).
- ✅ **Milestone 2 — Menu bar shell**: `WaqtaraApp` (MenuBarExtra + panel jadwal + countdown + Hijriyah + Settings lokasi/metode/offset), database ~90 kota (`cities.json`).
- ✅ **Milestone 3 — Mesin reminder**: notifikasi 3 fase via UNNotificationRequest (pra-azan, azan dengan tombol [Stop Azan], pasca-azan), toggle per waktu sholat, notifikasi ringkas untuk waktu terlewat saat sleep, rekalkulasi tengah malam + wake, tombol Uji Notifikasi, bundling `.app` (`Scripts/make-app.sh` → `dist/Waqtara.app`, ad-hoc signed).
- ✅ **Milestone 4 — Azan & polesan**: AVAudioPlayer dengan 2 audio azan bawaan (public domain/CC0 dari Internet Archive), pemutaran tepat waktu via timer presisi (tidak diputar jika telat >60 dtk, mis. habis sleep), Stop dari notifikasi/panel/Settings, volume independen, mode senyap, ikon menu bar berubah saat azan, launch at login (SMAppService), onboarding 3 langkah (deteksi lokasi CoreLocation / pilih kota + izin notifikasi + uji azan).
- ⏭️ **Milestone 5 — Rilis v1.0** (ikon app, Developer ID signing + notarization, .dmg, landing page, uji 7 hari).

## Kalibrasi Kemenag

Ikhtiyati default hasil kalibrasi terhadap bimasislam: Shubuh +2, Terbit −4, Dzuhur +3, Ashar +2, Maghrib +3, Isya +2, dengan pembulatan **ke atas** — berbeda dari asumsi awal PRD (Dzuhur/Maghrib +2 saja).

## Build & jalankan

```bash
swift test                 # unit test termasuk akurasi Kemenag
swift run waqtara-cli      # jadwal Jakarta hari ini
swift run waqtara-cli -7.25 112.75 Asia/Jakarta Surabaya 2026-06-01
./Scripts/make-app.sh && open dist/Waqtara.app   # app menu bar (notifikasi butuh .app bundle)
```

Butuh Xcode penuh (bukan hanya Command Line Tools) untuk milestone selanjutnya (bundle, signing, notarization).

## Audio azan bawaan

| File | Sumber | Lisensi |
|---|---|---|
| `azan-standard.mp3` | [AzanNaifIshaAzan](https://archive.org/details/AzanNaifIshaAzan) | Public domain |
| `azan-shubuh.mp3` | [MakkahAzan_20171111](https://archive.org/details/MakkahAzan_20171111) | CC0 |

Catatan: belum ditemukan rekaman azan Shubuh (dengan tarji') berlisensi bebas; slot Shubuh
sementara diisi azan Makkah CC0. Ganti file di `Sources/WaqtaraApp/Resources/` bila menemukan
yang lebih tepat (nama file tetap).

Keterbatasan diketahui: audio ducking system-wide tidak tersedia di macOS (API-nya khusus iOS),
jadi acceptance criteria "aplikasi lain di-duck" diganti volume azan independen.
