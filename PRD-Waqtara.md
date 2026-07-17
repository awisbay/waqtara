# PRD — Waqtara

**Aplikasi Pengingat Waktu Sholat untuk macOS**

| | |
|---|---|
| Nama Produk | Waqtara |
| Platform | macOS 13 (Ventura) ke atas |
| Versi Dokumen | 1.0 — 17 Juli 2026 |
| Referensi | Shollu v3.10 (Windows) oleh Ebta Setiawan — analisis langsung dari source code |
| Status | Draft untuk development |

---

## 1. Ringkasan Produk

Waqtara adalah aplikasi **menu bar macOS** yang mengingatkan pengguna Muslim akan waktu sholat. Aplikasi hidup diam-diam di menu bar (pojok kanan atas layar Mac), menampilkan hitung mundur menuju waktu sholat berikutnya, lalu memutar azan dan menampilkan notifikasi saat waktunya tiba.

Waqtara terinspirasi langsung dari **Shollu** — aplikasi Windows legendaris buatan Indonesia — namun hanya mengambil fitur intinya: **reminder sholat yang andal**. Fitur-fitur sampingan Shollu (shutdown PC otomatis, task scheduler umum, konverter kalender, pembuat jadwal cetak) sengaja tidak dibawa agar aplikasi tetap ringan, fokus, dan mudah dirawat.

**Filosofi produk:** *"Set once, trust forever."* Pengguna mengatur lokasi sekali, lalu Waqtara bekerja tanpa perlu disentuh lagi — akurat, tepat waktu, tidak mengganggu di luar waktunya.

---

## 2. Latar Belakang

### Masalah
Pengguna Mac di Indonesia tidak punya padanan Shollu yang memuaskan. Aplikasi sejenis di App Store (Prayer Times, PrayerTime, Prayer Bar, Guidance, iPray) umumnya:
- Berorientasi pasar global, dukungan metode Kemenag Indonesia sering absen atau tidak akurat
- Tidak punya model reminder bertingkat khas Shollu (pengingat *sebelum* azan → azan → pengingat *sesudah* azan)
- Terlalu banyak fitur (tracking ibadah, streak, statistik) yang tidak dibutuhkan

### Mengapa Shollu sebagai referensi
Dari analisis source code Shollu v3.10, model interaksinya terbukti matang untuk pekerja kantoran:

1. **Reminder 3 fase** — pesan persiapan N menit sebelum azan, azan penuh saat waktu tiba, dan pengingat N menit sesudahnya bagi yang menunda
2. **Kalkulasi mandiri (offline)** — formula astronomis (deklinasi matahari + equation of time) berjalan lokal, tidak bergantung API/internet
3. **Kustomisasi per-waktu-sholat** — file suara azan bisa berbeda per waktu (Shubuh punya azan khusus), koreksi menit per waktu sholat (ikhtiyati)
4. **Kehadiran pasif** — hidup di system tray, tidak makan perhatian

Waqtara mengadopsi keempat prinsip ini ke paradigma macOS (menu bar + Notification Center).

---

## 3. Sasaran & Non-Sasaran

### Sasaran (Goals)
- G1. Pengguna **tidak pernah melewatkan waktu sholat** karena lupa saat bekerja di depan Mac
- G2. Waktu sholat **akurat untuk Indonesia** (metode Kemenag: Fajr 20°, Isya 18°) — selisih maksimal ±1 menit dari jadwal resmi
- G3. Aplikasi terasa **native macOS** — ringan (<30 MB RAM), hemat baterai, mengikuti idiom Apple (menu bar, Notification Center, dark mode)
- G4. **Offline-first** — setelah setup awal, tidak butuh internet sama sekali
- G5. Setup awal selesai **dalam waktu kurang dari 1 menit**

### Non-Sasaran (Non-Goals) — fitur Shollu yang TIDAK dibawa
- Shutdown / hibernate / minimize-all otomatis (tidak wajar di macOS, butuh permission berbahaya)
- Task scheduler umum (pengingat non-sholat) — di macOS sudah ada Reminders.app
- Schedule maker (ekspor jadwal ke HTML/CSV) — ditunda ke fase P2
- Konverter Masehi–Hijriyah sebagai fitur mandiri (tanggal Hijriyah tetap *ditampilkan*, tapi tanpa tool konversi)
- Skin/tema warna kustom (ikut appearance sistem: light/dark)
- Moving text effect & efek animasi notifikasi (pakai Notification Center standar)
- Multi-bahasa di v1 (Indonesia dulu; English menyusul di P2)
- Versi iOS/iPadOS, widget, sinkronisasi antar-perangkat

---

## 4. Pengguna Sasaran

**Persona utama — "Pekerja layar penuh":** Profesional Muslim Indonesia yang bekerja 8+ jam sehari di depan Mac (engineer, desainer, penulis, freelancer). Sering memakai headphone dan mode fokus, sehingga tidak mendengar azan dari masjid sekitar. Butuh pengingat yang menembus fokus kerja tanpa merusaknya.

**Persona sekunder:** Pengguna Mac Muslim global yang butuh app azan ringan tanpa langganan/iklan.

---

## 5. Arsitektur & Teknologi

### Stack yang direkomendasikan

| Komponen | Pilihan | Alasan |
|---|---|---|
| Bahasa & UI | **Swift + SwiftUI** | Native, ringan, `MenuBarExtra` API (macOS 13+) membuat menu bar app jadi sederhana |
| Kalkulasi waktu sholat | **Library `adhan-swift`** (Batoul Apps, MIT license) | Battle-tested, mendukung custom angle (bisa set Fajr 20°/Isya 18° ala Kemenag), madhab Syafi'i/Hanafi, high-latitude rules. Lebih aman daripada porting manual formula Pascal Shollu |
| Notifikasi | **UserNotifications framework** | Notifikasi native, bisa punya action button ("Stop Azan") |
| Audio azan | **AVFoundation (AVAudioPlayer)** | Playback MP3/M4A, kontrol stop/volume |
| Penjadwalan | **Timer in-app + recalculate on wake** (`NSWorkspace.didWakeNotification`) | Meniru main-timer loop Shollu, tapi sadar sleep/wake — kelemahan timer polos adalah mati saat Mac sleep |
| Penyimpanan setting | **UserDefaults** | Padanan registry `HKEY\Software\Shollu3` di Windows |
| Login item | **ServiceManagement (SMAppService)** | Padanan "Auto start with Windows" Shollu |
| Lokasi | **CoreLocation (opsional)** + database kota bawaan | Auto-detect sekali saat onboarding; fallback ke pilihan kota manual |
| Distribusi | **Direct download (.dmg), signed & notarized** | Di luar App Store dulu — lebih cepat rilis; App Store menyusul |

### Catatan arsitektur penting (pelajaran dari Shollu)

1. **Jangan pakai polling per-detik gaya Shollu.** Shollu membandingkan string `HH:mm:ss` setiap detik lewat timer. Di macOS ini boros baterai dan **gagal saat Mac sleep**. Ganti dengan: hitung 5 waktu sholat hari ini → jadwalkan `UNNotificationRequest` untuk setiap event → dengarkan event wake untuk rekalkulasi. Timer ringan (per 30 detik) hanya untuk update teks countdown di menu bar saat menu terbuka/terlihat.
2. **Rekalkulasi harian:** Shollu update data tiap lewat tengah malam (`NextUpdate = 86400`). Waqtara: jadwalkan ulang semua notifikasi setiap 00:00 + setiap wake-from-sleep + setiap perubahan setting.
3. **Perbandingan waktu pakai detik-presisi** menimbulkan bug jika sistem lag; gunakan penjadwalan berbasis `Date`, bukan perbandingan string.

---

## 6. Fitur

Prioritas: **P0** = wajib ada di v1.0 (MVP), **P1** = menyusul cepat (v1.x), **P2** = backlog.

### F1 — Kalkulasi Waktu Sholat [P0]

Menghitung 6 waktu harian secara lokal/offline: **Shubuh, Terbit (Syuruq), Dzuhur, Ashar, Maghrib, Isya**. (Terbit ditampilkan sebagai info, bukan waktu sholat — tidak ada azan/reminder untuknya.)

**Parameter (mengikuti model Shollu):**
- Koordinat: latitude, longitude, altitude (ketinggian), timezone
- Metode kalkulasi (preset):
  - **Kemenag RI (default untuk Indonesia)** — Fajr 20°, Isya 18°
  - Muslim World League
  - Univ. of Islamic Sciences Karachi
  - ISNA
  - Umm al-Qura
  - Egyptian General Authority
  - **Custom** — pengguna isi sendiri sudut Fajr (Gd) & Isya (Gn), seperti fitur "Customize degree" Shollu
- Madhab Ashar: Syafi'i (default) / Hanafi
- **Koreksi menit per waktu sholat (ikhtiyati):** offset −15…+15 menit untuk masing-masing Shubuh/Dzuhur/Ashar/Maghrib/Isya — padanan `Add_Dhuhur`, `Add_Maghrib`, dst. di Shollu. Default: Dzuhur +2, Maghrib +2 (kebiasaan jadwal Indonesia), lainnya 0
- Pembulatan: normal / selalu ke atas / selalu ke bawah (padanan `Pembulatan` di Shollu)

**Acceptance criteria:**
- [ ] Untuk Jakarta (−6.2, 106.85, UTC+7, metode Kemenag), hasil selisih ≤1 menit dari jadwal resmi bimasislam.kemenag.go.id pada 5 tanggal uji yang tersebar sepanjang tahun
- [ ] Perhitungan berjalan tanpa koneksi internet
- [ ] Perubahan metode/offset langsung memicu rekalkulasi dan penjadwalan ulang notifikasi

### F2 — Kehadiran di Menu Bar [P0]

- Ikon Waqtara permanen di menu bar. Mode tampilan ikon (dipilih di Settings):
  1. Ikon saja
  2. Ikon + countdown ("Ashar −00:42")
  3. Ikon + nama & jam sholat berikutnya ("Ashar 15:11")
- Klik ikon membuka **panel dropdown** berisi:
  - Tanggal hari ini (Masehi + **Hijriyah**, dengan koreksi Hijriyah manual −2…+2 hari seperti `HijriyahDiff` Shollu)
  - Daftar 6 waktu hari ini; waktu yang sedang aktif di-highlight; waktu berikutnya diberi penanda countdown
  - Nama lokasi aktif
  - Tombol: Settings, Stop Azan (muncul hanya saat azan berbunyi), Quit
- Saat azan berbunyi, ikon menu bar berubah state (mis. berdenyut/berwarna) — padanan "Green menu bar text while audio is playing" di Guidance/Shollu

**Acceptance criteria:**
- [ ] Countdown di menu bar akurat dan berganti ke waktu berikutnya tepat setelah azan
- [ ] Panel mengikuti dark/light mode sistem
- [ ] RAM idle < 30 MB

### F3 — Mesin Reminder 3 Fase [P0] ⭐ *fitur inti*

Meniru model pesan Shollu (`Message1` / azan / `Message2`):

**Fase 1 — Pra-azan (persiapan):**
- Notifikasi "**N menit lagi waktu {sholat}**" — N dapat diatur global 5–30 menit (default 10), bisa dimatikan
- Bunyi notifikasi pendek standar, bukan azan

**Fase 2 — Saat azan:**
- Notifikasi "**Telah masuk waktu {sholat} untuk wilayah {kota}**"
- Memutar **file azan penuh** (lihat F4)
- Notifikasi memiliki tombol aksi: **[Stop Azan]**

**Fase 3 — Pasca-azan (susulan):**
- Notifikasi "**Waktu {sholat} telah lewat N menit**" — N dapat diatur 10–60 menit (default 15), bisa dimatikan
- Tujuan: menyelamatkan pengguna yang menunda karena tanggung kerjaan

**Kontrol per-waktu-sholat:** setiap waktu (Shubuh…Isya) punya toggle on/off reminder sendiri — mis. matikan reminder Shubuh karena sudah pakai alarm HP.

**Pengingat Jumat [P1]:** khusus hari Jumat, notifikasi "Persiapkan diri untuk sholat Jumat" pada jam yang dapat diatur (default 45 menit sebelum Dzuhur) — padanan `MJumat` Shollu. Saat aktif, fase 1–3 Dzuhur hari Jumat otomatis diganti oleh pengingat ini.

**Acceptance criteria:**
- [ ] Ketiga fase terkirim tepat waktu (toleransi ±5 detik) termasuk setelah Mac bangun dari sleep
- [ ] Jika Mac sleep melewati suatu waktu sholat lalu bangun, tampilkan satu notifikasi ringkas "Waktu {sholat} telah masuk pukul HH:mm" (tanpa memutar azan penuh yang telat)
- [ ] Notifikasi tetap muncul saat Do Not Disturb jika pengguna mengizinkan (dokumentasikan cara set "Allow notifications" per-app di onboarding)

### F4 — Pemutar Azan [P0]

- **2 audio azan bawaan** (bundle): azan standar (Makkah) + azan Shubuh (dengan tarji'/nada Shubuh)
- Otomatis: waktu Shubuh memakai azan Shubuh; waktu lain memakai azan standar
- **Custom per waktu sholat [P1]:** pengguna dapat memilih file audio sendiri (MP3/M4A/WAV) untuk masing-masing waktu — padanan `AdzanShubuh`, `AdzanDhuhur`, dst. di Shollu. Validasi file exists sebelum dipakai; fallback ke bawaan jika file hilang (Shollu menampilkan error "Adzan File not found")
- Kontrol: Stop dari notifikasi, Stop/volume dari panel menu bar
- Mode senyap: opsi "notifikasi saja, tanpa suara azan" (global atau per-waktu)
- Volume azan independen (slider di Settings), default mengikuti volume sistem

**Acceptance criteria:**
- [ ] Azan berhenti seketika saat tombol Stop ditekan dari notifikasi maupun panel
- [ ] Azan tidak berbunyi dobel jika notifikasi tertunda/dobel
- [ ] Aplikasi lain yang sedang memutar audio di-*duck* (volume turun) selama azan, lalu pulih — bukan dihentikan

### F5 — Lokasi [P0]

- **Onboarding:** dua jalur —
  1. "Deteksi otomatis" via CoreLocation (minta izin sekali) → reverse-geocode nama kota
  2. Pilih manual dari **database kota bawaan** (bundle JSON): ~500 kota/kabupaten Indonesia (nama, lat, long, altitude, timezone) + ~100 kota besar dunia — padanan file `placenames` Shollu
- Input koordinat manual (lat/long/altitude/timezone) untuk pengguna mahir — dengan validasi rentang seperti Shollu ("Invalid value for Latitude or Longitude")
- Lokasi tersimpan permanen; **tidak ada tracking berkelanjutan** — CoreLocation hanya dipakai saat pengguna menekan tombol deteksi

**Acceptance criteria:**
- [ ] Pencarian kota responsif (fuzzy search, hasil < 100 ms)
- [ ] Ganti kota langsung memperbarui jadwal & notifikasi terjadwal

### F6 — Pengaturan Umum [P0]

- Launch at login (default: on, via SMAppService) — padanan "Auto start with Windows"
- Format waktu 12/24 jam (default 24, mengikuti kebiasaan Indonesia)
- Toggle & durasi fase pra/pasca-azan (F3)
- Pilihan mode tampilan menu bar (F2)
- Koreksi Hijriyah (−2…+2 hari)
- Tombol "Uji Notifikasi & Azan" — memicu simulasi fase 2 agar pengguna yakin semuanya bekerja
- About: versi, kredit inspirasi Shollu, lisensi audio azan

### Fitur P1 (v1.x — setelah MVP stabil)
- Pengingat Jumat (detail di F3)
- Custom audio azan per waktu sholat (detail di F4)
- Arah kiblat (kompas statis berdasar koordinat — Shollu punya "Qibla Direction")
- Bahasa Inggris
- Launcher "Info berkala": notifikasi ringkas sisa waktu setiap N menit menjelang sholat (padanan `ShowInformation` Shollu) — off by default

### Fitur P2 (backlog)
- Ekspor jadwal bulanan ke CSV/PDF (padanan Schedule Maker Shollu)
- Widget Notification Center / desktop
- Mode Ramadhan: countdown imsak & berbuka
- Auto-update via Sparkle
- Publikasi Mac App Store

---

## 7. Pemetaan Fitur Shollu → Waqtara

Hasil audit source code Shollu v3.10, sebagai jawaban atas keputusan "tidak semua fitur dibawa":

| Fitur Shollu (dari source) | Status di Waqtara | Keterangan |
|---|---|---|
| Kalkulasi astronomis lokal (`GetPrayerTime`) | ✅ P0 | Diganti library adhan-swift, hasil setara |
| 5 metode kalkulasi + custom degree | ✅ P0 | Ditambah preset Kemenag sebagai default |
| Madhab Ashar Syafi'i/Hanafi | ✅ P0 | |
| Koreksi menit per waktu (`Add_*`) | ✅ P0 | |
| Pembulatan waktu (`Pembulatan`) | ✅ P0 | |
| Pesan sebelum azan (`Message1`, M1 menit) | ✅ P0 | Fase 1 |
| Notifikasi + azan saat waktu tiba (`onAdzanTiba`) | ✅ P0 | Fase 2 |
| Pesan sesudah azan (`Message2`, M2 menit) | ✅ P0 | Fase 3 |
| File azan berbeda per waktu (`AdzanShubuh` dst.) | ✅ P1 | v1 pakai 2 bawaan (Shubuh + standar) |
| Pesan Jumat (`MJumat`) | ✅ P1 | |
| Info berkala (`ShowInformation`) | ✅ P1 | Off by default |
| Tanggal & bulan Hijriyah + koreksi (`HijriyahDiff`) | ✅ P0 | Tampilan di panel |
| Tray icon + hint countdown (`UpdateHint`) | ✅ P0 | Jadi menu bar icon + countdown |
| Auto start with Windows (`REG_RUN`) | ✅ P0 | Jadi Login Item |
| Database nama kota (`placenames`) | ✅ P0 | Di-porting ke JSON |
| Jadwal kemarin/hari ini/besok di main window | ⚠️ Sebagian | Panel hanya hari ini; besok cukup implisit |
| Arah kiblat | ✅ P1 | |
| Skin warna (`Skin.RES`, `IndexColor`) | ❌ | Ikut light/dark sistem |
| Multi bahasa (`LANGUAGE.RC`) | ⚠️ P1 | Indonesia dulu, EN menyusul |
| Minimize all windows saat azan (`MMinimize`) | ❌ | Terlalu invasif untuk macOS |
| Shutdown/Hibernate PC (`MShutdown`, `SetSuspendMode`) | ❌ | Di luar filosofi produk |
| Task scheduler umum (`UTask`, task.dat) | ❌ | Sudah ada Reminders.app |
| Schedule maker ekspor HTML/CSV/TSV (`USchedule`, jadwal.tpl) | ❌ → P2 | |
| Konverter Masehi–Hijriyah (`UConvert`) | ❌ | |
| Moving text & efek animasi (`MAX_EFFECT`) | ❌ | |
| Doa setelah azan (`MpDua`) | ⚠️ P2 | Dipertimbangkan sebagai opsi audio lanjutan |

---

## 8. Alur Pengguna (UX Flows)

### 8.1 Onboarding (target < 1 menit)
1. Buka app pertama kali → jendela sambutan 3 langkah:
   - **Langkah 1 — Lokasi:** tombol "Deteksi Lokasi Saya" atau search kota. Preview jadwal hari ini langsung muncul di bawahnya sebagai konfirmasi visual
   - **Langkah 2 — Izin notifikasi:** penjelasan singkat kenapa dibutuhkan → trigger permission prompt macOS. Jika ditolak, tampilkan instruksi manual System Settings
   - **Langkah 3 — Selesai:** "Waqtara sekarang hidup di menu bar ↗" dengan panah animasi ke arah ikon; tombol "Uji Azan Sekarang"
2. Jendela onboarding menutup; sejak itu app hanya hidup di menu bar (tidak ada dock icon — `LSUIElement = true`)

### 8.2 Ritme harian
- Pengguna bekerja → menu bar menampilkan "Ashar −00:31"
- 10 menit sebelum: notifikasi persiapan (fase 1)
- Tepat waktu: azan berbunyi + notifikasi dengan [Stop Azan] (fase 2)
- Pengguna sholat. Jika tidak, 15 menit kemudian notifikasi susulan (fase 3)
- Tengah malam: rekalkulasi otomatis untuk hari baru

### 8.3 Edge cases yang wajib ditangani
| Kasus | Perilaku yang diharapkan |
|---|---|
| Mac sleep melewati waktu sholat | Saat wake: notifikasi ringkas "telah masuk pukul HH:mm", tanpa azan penuh; jadwal berikutnya dijadwalkan ulang |
| Mac sleep saat azan sedang berbunyi | Audio berhenti; tidak dilanjutkan saat wake |
| Pengguna pindah timezone (traveling) | Deteksi perubahan `TimeZone.current` → tawarkan update lokasi via notifikasi |
| Ganti setting di tengah countdown | Rekalkulasi & re-schedule seketika |
| Dua instance app | Cegah (single instance) — Shollu punya "instance has already running" |
| Notifikasi ditolak user | Menu bar tetap berfungsi (countdown tetap terlihat); banner peringatan di panel Settings |
| File azan custom terhapus | Fallback ke azan bawaan + notifikasi sekali |
| Pergantian hari saat app berjalan (00:00) | Panel & jadwal refresh otomatis |

---

## 9. Data & Privasi

- **Tidak ada server, tidak ada akun, tidak ada analytics, tidak ada iklan.**
- Semua data (setting, lokasi terpilih) tersimpan lokal di UserDefaults
- CoreLocation hanya diakses on-demand saat pengguna menekan tombol deteksi; koordinat tidak pernah meninggalkan perangkat
- App di-sandbox, signed, dan notarized

---

## 10. Metrik Keberhasilan

| Metrik | Target |
|---|---|
| Akurasi vs jadwal Kemenag (kota uji: Jakarta, Surabaya, Medan, Makassar, Tangerang Selatan) | Selisih ≤ 1 menit |
| Notifikasi fase 2 tepat waktu (uji 7 hari berturut, termasuk siklus sleep/wake) | ≥ 99% |
| RAM idle | < 30 MB |
| CPU idle | ~0% (no polling ketat) |
| Waktu onboarding sampai reminder aktif | < 60 detik |
| Crash-free sessions | > 99.5% |

---

## 11. Rencana Rilis (disesuaikan alur vibe coding)

**Milestone 1 — Inti kalkulasi (validasi dulu sebelum UI):**
Proyek Swift + integrasi adhan-swift + preset Kemenag + unit test membandingkan output dengan jadwal Kemenag untuk 5 kota × 5 tanggal. *Keluaran: CLI kecil yang mencetak jadwal hari ini.*

**Milestone 2 — Menu bar shell:**
MenuBarExtra + panel jadwal hari ini + countdown + Hijriyah + Settings dasar (lokasi manual dari JSON kota, metode, offset).

**Milestone 3 — Mesin reminder:**
Penjadwalan UNNotification 3 fase + handling sleep/wake + rekalkulasi tengah malam + tombol Uji.

**Milestone 4 — Azan & polesan:**
AVAudioPlayer + 2 audio bawaan + Stop action + audio ducking + launch at login + onboarding 3 langkah.

**Milestone 5 — Rilis v1.0:**
Ikon app, signing + notarization, .dmg, landing page sederhana, uji 7 hari di mesin sendiri.

*(P1 menyusul: Jumat reminder, custom adzan per waktu, kiblat, EN.)*

---

## 12. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Timer/notifikasi tidak fire saat Mac sleep | Reminder terlewat — fatal untuk produk ini | Gunakan UNNotificationRequest terjadwal (dikelola OS, tetap fire saat sleep ringan) + rekonsiliasi saat wake |
| Fokus/DND macOS menelan notifikasi | Reminder tak terlihat | Edukasi onboarding untuk mengizinkan app di mode Fokus; menu bar countdown sebagai lapisan cadangan yang selalu terlihat |
| Selisih hasil adhan-swift vs jadwal Kemenag di kota tertentu | Kepercayaan pengguna turun | Preset custom angle + offset ikhtiyati per waktu; uji 5 kota sejak Milestone 1 |
| Notarization/signing pertama kali rumit bagi vibe coder | Rilis tertunda | Alokasikan milestone khusus; pakai akun Apple Developer ($99/thn) + dokumentasi langkah-demi-langkah |
| Lisensi audio azan | Legal | Gunakan rekaman berlisensi bebas/CC atau rekam sendiri; catat sumber di About |

---

## Lampiran A — Referensi Teknis dari Source Shollu

Untuk keperluan implementasi, temuan kunci dari source v3.10:

- **Struktur waktu:** record `TSholat` berisi 6 field (tShubuh, tTerbit, tDhuhur, tAsar, tMaghrib, tIsya)
- **Loop utama:** `onMainTimer` (interval 1 detik) membandingkan string `HH:mm:ss`; rekalkulasi harian via counter `NextUpdate = 86400`
- **Kunci setting (registry `Software\Shollu3`)** yang relevan untuk dipetakan ke UserDefaults Waqtara: `Message1` (menit pra-azan), `Message2` (menit pasca), `MAdzan` (toggle azan), `MJumat` (jam pesan Jumat), `ShowInformation` (interval info), `AdzanShubuh`…`AdzanIsya` (path audio per waktu), plus `Add_*` (offset per waktu), `Pembulatan`, `HijriyahDiff`
- **Konstanta metode:** Karachi=1, ISNA=2, MWL=3, UmmulQura=4, Egypt=5 (Waqtara menambah Kemenag=0/default)
- **Template pesan (dari LANGUAGE.RC):** "Now is the time to pray %s", "%d minutes again time to sholah %s", "%d minutes has left from %s time", "Prepare your self for friday prayer" — jadikan acuan copywriting versi Indonesia
