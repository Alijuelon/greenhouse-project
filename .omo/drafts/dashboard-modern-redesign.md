---
slug: dashboard-modern-redesign
status: drafting
intent: clear
review_required: false
pending-action: write .omo/plans/dashboard-modern-redesign.md
approach: Token-first modernization of the Flutter dashboard (AppColors/AppTextStyles/AppSpacing/AppRadius/AppShadows + new motion/surface tokens), then a rebuilt dashboard composition (glanceable health header, one on-brand climate hero, token-based nutrient/substrate card, responsive accessible actuator grid), shell insets derived from tokens, and a fake-data + golden-test harness so every UI state is provable without the live API.
---

# Draft: dashboard-modern-redesign

## Affected user and ideal state

Affected users:
- **Operator greenhouse (primary)** — petani/pengelola yang membuka app di Android mid-range, di dalam greenhouse, satu tangan, sering pakai sarung tangan, layar kena cahaya matahari. Hari ini ia harus membaca angka 9–12px di kartu bento dan menebak apakah datanya masih segar.
- **Maintainer aplikasi (secondary)** — programmer yang menambah layar berikutnya; hari ini ia harus menyalin gradient/radius/warna hardcoded karena token belum lengkap.

| id | property of the ideal state | reason |
|---|---|---|
| IS-1 | Dalam <3 detik setelah buka Dashboard, operator tahu: greenhouse sehat/abnormal, aktuator mana yang menyala, dan kapan data terakhir masuk. | Monitoring adalah pekerjaan utama; sekarang status tersebar di 3 kartu kecil 9–12px dan tidak ada penanda kesegaran data. |
| IS-2 | Semua teks terbaca di luar ruangan: label ≥12px, nilai ≥24px, kontras teks memenuhi WCAG AA di atas surface masing-masing. | Cahaya matahari + sarung tangan; sekarang ada `fontSize: 9`, `white38`, `white54`. |
| IS-3 | Kontrol aktuator aman & satu tangan: target sentuh ≥48dp, status ON/OFF tidak ambigu, relay terlindungi menjelaskan alasannya, tidak ada toggle tak sengaja. | Konsekuensi fisik (dosing pupuk, pH up/down); sekarang switch 44×24 dengan ikon 14px dan `GestureDetector` tanpa ripple. |
| IS-4 | Loading / offline / data basi ditampilkan jujur: skeleton → error + tombol coba lagi + timestamp terakhir; nilai 0 tidak pernah menyamar sebagai pembacaan nyata. | API produksi saat ini membalas HTTP 500 untuk `/dashboard/live`; app menampilkan 0.0°C/0% seolah valid. |
| IS-5 | Satu bahasa visual: seluruh Dashboard hanya memakai token (warna, tipografi, radius, elevation, spacing, motion) sehingga tidak bentrok dengan tab lain. | Sekarang ada 4 varian gradient biru→hijau dan puluhan warna hardcoded. |
| IS-6 | Layout utuh dari 360dp phone sampai tablet/landscape, tanpa overflow pada text scale 1.3×. | Row 3 kolom non-wrapping + tinggi tetap 120/160/176 dan tanpa `LayoutBuilder`. |
| IS-7 | Setiap state UI dapat dirender di test tanpa jaringan, dan redesign terbukti tidak meregresi tab lain. | Dashboard tidak bisa di-pump: network di `initState` + `Timer.periodic` tak dibatalkan. |
| IS-8 | Motion halus 150–300ms, hanya untuk menjelaskan perubahan status, dan tidak memaksa animasi saat reduce-motion. | "Modern" mudah jatuh jadi animasi dekoratif; status relay berubah setiap 5 detik. |

| id | gap between IS-n and today | reason | closed by |
|---|---|---|---|
| GAP-1 | Hero memakai gradient biru→hijau + 4 orb dekoratif, bukan identitas hijau AgriSense; gradient yang sama disalin ke 3 halaman lain. | `climate_hero_card.dart:21-46`; `ai_recommendation_page.dart:271-274`; `automation_page.dart:639-642`; `settings_page.dart:253-256`. | T3 |
| GAP-2 | Ringkasan atas = 3 kartu bento dengan teks 9–12px, tanpa wrap, status "Optimal" hardcoded. | `dashboard_page.dart:213-317` (status literal di :221). | T2 |
| GAP-3 | Kartu nutrisi bergantung pada foto latar + teks `white38`/`white54`; tidak ada state "sensor tidak terdeteksi" yang membedakan 0 nyata vs tidak ada data. | `npk_7_in_1_card.dart:38-79, 405-430, 118-152`. | T4 |
| GAP-4 | Relay: switch hand-rolled 44×24, ikon 14px, `minHeight: 120`, grid 2 kolom via `buildIntrinsicGrid`, tidak ada Semantics. | `relay_control_card.dart:238-284`; `dashboard_page.dart:585-607`. | T5 |
| GAP-5 | Tidak ada indikator "terakhir diperbarui"/stale; error mengganti seluruh halaman; error API 500 → layar error tanpa data terakhir. | `dashboard_page.dart:44-66, 150-171`. | T2, T6 |
| GAP-6 | Dashboard tidak dapat diuji: `ApiService` statis tanpa injeksi, `Timer.periodic(5s)` tanpa guard teardown; satu-satunya test hanya smoke `MainShell`. | `dashboard_page.dart:30-36, 46`; `api_service.dart:49-60`; `test/widget_test.dart:7-12`. | T6 |
| GAP-7 | Shell memakai angka magis 64/64 dan tiap halaman mengompensasi padding sendiri. | `main.dart:71-75`; `analytics_page.dart:117`; `settings_page.dart:229`. | T2 |
| GAP-8 | Nol `Semantics` di seluruh `lib/`, tidak ada penanganan text scale; beberapa ikon <48dp. | grep `Semantics` = 0 hits; `relay_control_card.dart:144`. | T2, T5 |
| GAP-9 | `StatusBannerCard` dan `SensorMetricCard` tidak dipakai siapa pun (dead code) padahal `SensorMetricCard` punya gauge/badge yang relevan. | grep hanya menemukan deklarasinya sendiri. | T7 |
| GAP-10 | Token belum lengkap: tidak ada token accent/elevation/motion, `AppRadius` maksimum 16 padahal UI memakai 16–28. | `app_radius.dart:5-8`; pemakaian `circular(20/24/28)`. | T1 |

## Components (topology ledger)

| id | outcome (one line) | status | evidence path |
|---|---|---|---|
| C1 | Design foundation: token warna/tipe/radius/elevation/motion lengkap dan dipakai lewat `ThemeData` | active | `lib/core/theme/*.dart` |
| C2 | Dashboard frame: IA baru (header status + kesegaran data), grid responsif, inset shell dari token | active | `dashboard_page.dart`, `main.dart:71-75` |
| C3 | Climate hero: kartu iklim on-brand, data-forward, kontras AA | active | `climate_hero_card.dart` |
| C4 | Nutrient & substrate: kartu NPK/pH/EC/suhu/kelembapan berbasis token + state tidak-terdeteksi | active | `npk_7_in_1_card.dart` |
| C5 | Actuator grid: tile responsif, target 48dp, switch bermakna, status terlindungi jelas | active | `relay_control_card.dart`, `dashboard_page.dart:558-608` |
| C6 | Verification harness: data dashboard dapat diinjeksi + golden/screenshot state (loading/error/data/empty) | active | `test/widget_test.dart`, `api_service.dart` |

## Open assumptions (announced defaults)

| assumption | adopted default | rationale | reversible? |
|---|---|---|---|
| Dark mode | Tidak menambah dark theme sekarang; token disusun agar dark theme bisa ditambahkan tanpa refactor | Permintaan tidak menyebut dark mode; menambahkannya menggandakan permukaan QA | Ya |
| Dependensi baru | Tidak menambah paket UI baru (tetap `fl_chart`, `google_fonts`); animasi pakai `AnimatedContainer`/`TweenAnimationBuilder` bawaan | Menjaga risiko & ukuran APK; pola yang sudah dipakai repo | Ya |
| Font | Tetap `google_fonts` (Plus Jakarta Sans + Inter) sesuai token sekarang | Identitas tipografi sudah ada; menggantinya bukan bagian permintaan | Ya |
| Test strategy | Widget test + golden test dengan payload palsu (tests-after, bukan TDD), tanpa paket mock baru | Satu-satunya cara memvalidasi state tanpa API; API produksi sedang 500 | Ya |
| Cakupan tab lain | Hanya Dashboard + chrome shell; tab lain tidak didesain ulang, hanya dipastikan tidak rusak | Permintaan spesifik "dashboard" | Ya |
| Data trend di hero | Tidak menambah endpoint baru; sparkline hanya jika data tersedia dari payload yang ada, jika tidak → hapus sparkline palsu | `climate_hero_card.dart:278-282` sekarang menggambar sparkline statis palsu | Ya |

## Findings (cited - path:lines)

- Dashboard saat ini: `DashboardPage` (609 baris) merangkai 3 kartu bento + `ClimateHeroCard` + `Npk7In1Card` + grid 6 relay (`dashboard_page.dart:173-204`).
- Hero: gradient 4-stop biru→hijau, 4 orb radial, glass tiles, footer sparkline statis (`climate_hero_card.dart:21-46, 50-113, 247-285, 391-419`).
- NPK: kartu berlatar `assets/images/greenhouse_bg.png` + overlay gelap; 3 tile NPK, 4 tile metrik; semua teks putih transparan (`npk_7_in_1_card.dart:26-79`).
- Relay: `_accentColor()` menebak warna dari nama relay (`relay_control_card.dart:36-45`); switch custom (`:238-284`); dialog konfirmasi untuk relay 0–3 (`dashboard_page.dart:410-556`).
- Polling 5 detik + optimistic update (`dashboard_page.dart:33, 68-90`).
- Shell: AppBar 64 + `padding.top + 64`, bottom 64 + inset (`main.dart:71-75`; `app_bar_widget.dart:65`).
- Token: `AppColors` 84 baris (ada `heroGradient` tapi tidak dipakai konsisten), `AppTextStyles` via google_fonts, `AppRadius` max 16, `AppShadows` 5 bayangan (`lib/core/theme/`).
- Lingkungan: Flutter 3.41.6 stable; device tersedia hanya Linux desktop + Chrome; **tidak ada folder `web/` atau `linux/`** (hanya `android/`, `ios/`); tidak ada emulator Android → QA visual interaktif butuh penambahan platform web (reversible) atau golden test.
- API produksi `GET /api/dashboard/live` → **HTTP 500** saat dicek (2026-11-05) → QA tidak boleh bergantung pada API live.
- Dead code: `StatusBannerCard`, `SensorMetricCard` tidak diimpor siapa pun.

## Decisions (with rationale)

- Token-first: semua perubahan visual lewat `lib/core/theme/*` + `ThemeData`, bukan hardcode baru. Alasan: GAP-1/GAP-10; mencegah drift yang sama terulang di tab lain.
- Data layer dibuat injectable (fungsi fetch + interval sebagai parameter opsional dengan default perilaku sekarang). Alasan: GAP-6, tanpa mengubah perilaku produksi.
- Tidak mengubah kontrak API / backend. Alasan: di luar permintaan; API sedang bermasalah, redesign tidak boleh menambah ketergantungan.

## Scope IN

- `lib/core/theme/*` (token + ThemeData), `lib/features/dashboard/**`, `lib/shared/widgets/app_bar_widget.dart` + `bottom_nav_bar.dart` (hanya koherensi inset/token), `lib/main.dart` (inset shell), `test/` (harness + golden).

## Scope OUT (Must NOT have)

- Tidak mendesain ulang Analytics, AI Recommendation, Automation, Settings, Splash (hanya dipastikan tetap compile & lolos test).
- Tidak menambah dark theme, tidak mengganti font, tidak menambah paket UI/state-management baru.
- Tidak mengubah endpoint/backend Flask, tidak mengubah skema DB, tidak mengubah firmware.
- Tidak menambah fitur baru (notifikasi, jadwal, multi-greenhouse, login).
- Tidak menambahkan animasi dekoratif yang tidak menjelaskan perubahan status.

## Open questions

Semua terjawab 2026-11-05 (user memilih opsi rekomendasi pada keempat fork):

- Q1 arah visual → **Botanical data-forward**: hijau AgriSense sebagai identitas, surface bertingkat, angka besar sebagai fokus, satu aksen, depth halus (border + shadow tipis), tanpa orb dekoratif.
- Q2 cakupan → **Dashboard + chrome shell** (AppBar/BottomNav/inset), tab lain hanya dijaga tidak rusak.
- Q3 IA → **boleh IA ringan**: header status + "terakhir diperbarui", ringkasan menggantikan 3 kartu bento 9–12px, hapus sparkline statis palsu, tampilkan state stale/offline/empty. Urutan besar tetap iklim → nutrisi → aktuator.
- Q4 verifikasi → **widget test + golden test** (4 state × 2 lebar), tanpa menambah folder platform `web/`.

## Metis gap analysis (folded 2026-11-05)

Metis membaca draft + seluruh sumber yang dikutip dan mengembalikan 20 temuan; semuanya diverifikasi ulang. Yang diubah di rencana:

- **BLOCKER** "state sensor-tidak-terdeteksi sudah ada" → GAP-3 ditulis ulang menjadi *partial/null honesty* (`?? 0.0` di `npk_7_in_1_card.dart:13-19`), bukan "state belum ada".
- **BLOCKER** `toggleRelay` mengembalikan bool yang diabaikan (`api_service.dart:62-74`, `dashboard_page.dart:77`) → GAP-11 + IS-9 + T4/T10 menambah revert + SnackBar.
- **BLOCKER** tidak ada cara melihat UI (tanpa `web/`, tanpa emulator) → F3 didefinisikan ulang: bukti = 8 golden PNG yang dibuka dengan tool `read`; tidak ada klaim "manual QA di perangkat".
- **BLOCKER** Scope IN tidak memuat `api_service.dart` → T4 memakai injeksi di level widget (tanpa mengubah `ApiService`), sehingga tidak perlu masuk scope; `ApiService` hanya ditambah `timeout` di sisi pemanggil.
- **BLOCKER** tidak ada git → `## Commit strategy` diganti snapshot tar + gerbang analyze/test per todo; tidak ada `git init`.
- **IMPORTANT** "token-first" vs "tab lain tidak berubah" → C1 diturunkan: hanya token yang dipakai dashboard + perbaikan `textMuted`; nilai token lama lain tidak diubah; GAP-1 dibatasi ke hero dashboard, 3 halaman lain eksplisit ditunda di Must NOT have.
- **IMPORTANT** polling di `IndexedStack` + tanpa timeout → GAP-12, IS-10, T4 (`isActive` + `AppLifecycleListener` + `.timeout(4s)`), T7 (`isActive` dari `MainShell`).
- **IMPORTANT** inset shell salah 16dp/22dp (bukan hanya "angka magis") → GAP-7 + T7 + tes geometri.
- **IMPORTANT** `textMuted` 2.54:1 gagal AA → T2 mengubahnya ke `0xFF5F6B5C` + `contrast_test.dart`.
- **IMPORTANT** IS-6 tanpa QA → matriks 360/600/840dp × textScaler 1.0/1.3 masuk T5/T6/T8/T10 dan tabel Success criteria.
- **IMPORTANT** golden akan berisi kotak font → T1 membundel 9 TTF + `FontLoader` di T12.
- **IMPORTANT** AppBar non-hermetik (`getSettings` + `Image.network`) → T7 menambah `settingsLoader` + `avatarImage`.
- **IMPORTANT** payload relay <6 → `RangeError` → GAP-13 + T3 (padding/take 6) + state `partialPayload`.
- **IMPORTANT** kartu relay mengabaikan setelan haptic + tanpa Semantics → T10 (haptic dipindah ke halaman) + `Semantics(toggled:)`.
- **NOTE** `TimerBottomSheet` 3 dari 5 durasi, chip 40dp, copy hardcoded → GAP-14 + T11.
- **NOTE** GAP-9 tanpa penutup → T13.
- **NOTE** kriteria "terlihat modern" tak terukur → acceptance diganti grep/ukuran/test konkret.
- **NOTE** galat setelah data sukses tidak terlihat (bukan "seluruh halaman") → GAP-5 ditulis ulang + ambang basi 15s + state `stale`.
- **NOTE** Android back & offline-first cold start → keduanya dinyatakan **deferred** di Must NOT have (tidak diam-diam dihilangkan): tidak ada `PopScope`, tidak ada persistensi.
- **NOTE** "apakah token-first layak" → dijawab dengan menurunkan C1 (lihat di atas) alih-alih membatalkan; ~40% diff berkurang.

## Approval gate

status: plan-written
approval: user menjawab "okay" 2026-11-05 atas brief (arah botanikal, dashboard + shell, IA ringan, widget + golden).
review_required: false
plan_path: .omo/plans/dashboard-modern-redesign.md
plan_sha256: c227674dfd4eda5bf4eac41e2df860f210fc1b0afce0106474500a79ad1eb47a
pending-action: user memilih "mulai eksekusi sekarang" 2026-11-05. Eksekusi dijalankan di sesi worker via `$ulw-execute dashboard-modern-redesign`; planner berhenti.
