# dashboard-modern-redesign - Work Plan

## TL;DR (For humans)

**Who this is for and what changes for them:** Pengelola greenhouse yang membuka aplikasi di dalam greenhouse, satu tangan, layar kena matahari. Setelah perubahan ini ia tahu kondisi greenhouse, aktuator yang menyala, dan kesegaran data dalam sekali pandang — dengan angka besar yang terbaca di luar ruangan.

**What you'll get:** Dashboard yang benar-benar dirancang ulang, bukan tambalan: satu bahasa visual hijau botanikal, ringkasan status yang terbaca, kartu iklim dan nutrisi yang jujur soal data kosong atau basi, kontrol aktuator yang aman disentuh dan mengaku kalau perintahnya gagal — plus tangkapan layar otomatis untuk setiap keadaan sebagai bukti.

**Why this approach:** Fondasi (warna, huruf, jarak, bayangan, animasi) dirapikan dulu supaya tampilan baru tidak diulang-ulang dengan nilai acak, lalu dashboard dibangun ulang di atasnya. Semua keadaan (memuat, galat, data basi, sensor kosong) dibuat bisa dirender tanpa jaringan karena server produksi saat ini membalas galat 500 — jadi desain dibuktikan dengan data uji, bukan harapan.

**What it will NOT do:** Tidak mendesain ulang tab Analitik, AI Dosing, Otomasi, Pengaturan, atau Splash — hanya dipastikan tetap jalan. Tidak menambah mode gelap, fitur baru, atau mengubah server/firmware. Tidak mengklaim tiga halaman lain yang masih memakai gradien salinan ikut diperbaiki.

**Effort:** Large
**Risk:** Medium - menyentuh token global dan tata letak shell, jadi kesalahan bisa merembes ke tab lain; diredam snapshot sebelum mulai + gerbang analyze/test per gelombang.
**Decisions to sanity-check:** (1) font Plus Jakarta Sans + Inter dibundel ke aplikasi (bukan diunduh saat runtime), (2) ambang "data basi" 15 detik mengikuti ambang `is_online` server, (3) tiga kartu bento diganti satu strip ringkas yang membungkus saat huruf diperbesar.

Your next move: mulai eksekusi di sesi worker (`$ulw-execute dashboard-modern-redesign`), atau minta high-accuracy review dulu. Detail lengkap di bawah.

---

> TL;DR (machine): Large/Medium — 13 implementation todos in 4 waves (tokens+fonts → cards → frame → goldens), rebuilds dashboard on a new botanical token layer with injectable data + 8 golden states; no other tab redesigned, no new deps beyond bundled fonts.

## Scope

### Affected user and ideal state

**Affected user:** (1) **Operator greenhouse** — membuka app di Android mid-range, di dalam greenhouse, satu tangan, sering bersarung tangan, layar kena matahari langsung; pekerjaannya memantau dan mengoreksi aktuator. Hari ini ia membaca angka 9–12px, tidak tahu data masih segar atau tidak, dan tidak diberi tahu ketika perintah relay gagal. (2) **Maintainer aplikasi** — programmer yang menambah layar berikutnya; hari ini ia menyalin gradient/radius/warna hardcoded karena token tidak lengkap.

| Row | Statement | Reason |
| --- | --- | --- |
| IS-1 | Dalam <3 detik setelah membuka Dashboard, operator tahu status greenhouse (optimal/perlu perhatian/offline), berapa aktuator menyala, dan kapan data terakhir masuk. | Monitoring adalah pekerjaan utama; sekarang status tersebar di 3 kartu 9–12px, "Optimal" hardcoded, dan tidak ada penanda kesegaran. |
| IS-2 | Semua teks terbaca di luar ruangan: label ≥12px, nilai metrik ≥22px, rasio kontras teks ≥4.5:1 (teks besar ≥3:1) pada surface masing-masing. | Cahaya matahari + sarung tangan; sekarang ada `fontSize: 9`, `white38`, dan `textMuted` 2.54:1. |
| IS-3 | Kontrol aktuator aman & satu tangan: target sentuh ≥48dp, status ON/OFF tidak ambigu (termasuk beda "diperintahkan" vs "aktual"), relay terlindungi menjelaskan alasannya, tidak ada toggle tak sengaja. | Konsekuensi fisik (dosing pupuk, pH up/down); sekarang switch 44×24, ikon 14px, `GestureDetector` tanpa ripple/Semantics. |
| IS-4 | Loading / offline / data basi ditampilkan jujur: skeleton → error + tombol coba lagi, data lama tetap tampil dengan label "basi" + waktu terakhir; nilai tidak tersedia tampil "—", bukan 0. | API produksi membalas HTTP 500; app menampilkan 0.0°C/0% dan badge LIVE seolah valid. |
| IS-5 | Seluruh Dashboard hanya memakai token (warna, tipografi, radius, elevation, spacing, motion); tidak ada nilai visual hardcoded baru di subtree dashboard. | Sekarang 4 varian gradient dan puluhan warna hardcoded; token yang ada justru tidak dipakai. |
| IS-6 | Layout utuh pada 360dp, 600dp, dan 840dp lebar, portrait & landscape, pada text scale 1.0 dan 1.3 — tanpa `RenderFlex overflowed`. | Row 3 kolom non-wrapping, tinggi tetap 120/160/176, nol `LayoutBuilder`. |
| IS-7 | Setiap state UI (loading, data, basi, error dingin, sensor kosong, payload cacat) dapat dirender di test tanpa jaringan, dan hasilnya bisa dilihat sebagai PNG. | Dashboard tidak bisa di-pump: network di `initState` + `Timer.periodic` tanpa guard; hanya ada 1 smoke test. |
| IS-8 | Motion hanya 150–320ms dan hanya untuk menjelaskan perubahan status; dimatikan saat sistem meminta reduce-motion. | Status relay berubah tiap 5 detik; animasi dekoratif akan mengganggu. |
| IS-9 | Perintah aktuator tidak pernah berbohong: jika server menolak, UI kembali ke status sebenarnya dan memberi tahu pengguna. | `toggleRelay` mengembalikan bool yang diabaikan, sehingga UI bisa menampilkan ON padahal pompa dosing OFF. |
| IS-10 | Polling berhenti saat app di background atau saat tab lain aktif, dan setiap request punya batas waktu. | `Timer.periodic(5s)` terus jalan di `IndexedStack` → ~720 request/jam tanpa timeout. |
| GAP-1 | Hero dashboard memakai gradient biru→hijau + 4 orb dekoratif + sparkline statis palsu, bukan identitas hijau AgriSense. | `climate_hero_card.dart:21-46, 50-113, 278-282, 391-419`. | 
| GAP-2 | Ringkasan atas = 3 kartu bento teks 9–12px, tanpa wrap, label status "Optimal" hardcoded, dan membaca `data['ai_mode']` yang tidak ada di payload. | `dashboard_page.dart:207-317` (literal `'Optimal'` di :221); backend mengirim `ai.mode` (`flask_agrisense/app.py:346-351`). |
| GAP-3 | Kartu nutrisi bergantung foto latar + teks `white38`/`white54`; hanya semua-nol yang dianggap "tidak terdeteksi", sehingga `null`/sebagian kosong tampil sebagai 0 + alarm palsu ("⚠ Rendah"). | `npk_7_in_1_card.dart:13-24, 26-79, 118-152, 242, 272, 405-430`. |
| GAP-4 | Relay: switch hand-rolled 44×24 tanpa Semantics, ikon 14px, `minHeight: 120`, grid 2 kolom manual, warna aksen ditebak dari nama. | `relay_control_card.dart:36-45, 143-144, 238-284`; `dashboard_page.dart:558-608`. |
| GAP-5 | Tidak ada indikator kesegaran; galat poll setelah data sukses tetap menampilkan angka lama dengan badge LIVE; galat dingin mengganti seluruh halaman. | `dashboard_page.dart:44-66, 150-171`; `npk_7_in_1_card.dart:111, 295-336`. |
| GAP-6 | Dashboard tidak dapat diuji: `ApiService` statis, `Timer.periodic` tanpa guard, tidak ada fixture. | `dashboard_page.dart:30-36, 46`; `api_service.dart:49-60`; `test/widget_test.dart:7-12`. |
| GAP-7 | Shell memakai angka magis 64/64 yang salah 16dp (atas) dan 22dp (bawah); tiap halaman menambal sendiri. | `main.dart:71-75`; `app_bar_widget.dart:14, 59, 65`; `bottom_nav_bar.dart:29, 35`; `analytics_page.dart:117`. |
| GAP-8 | Nol `Semantics` di `lib/`, nol penanganan text scale, beberapa target sentuh <48dp. | grep `Semantics` = 0; `relay_control_card.dart:143-144`; `timer_bottom_sheet.dart:82-89, 110-113`. |
| GAP-9 | `StatusBannerCard` dan `SensorMetricCard` adalah dead code (hanya mereferensikan dirinya sendiri). | grep di `lib/` + `test/`. |
| GAP-10 | Token tidak lengkap (tanpa motion, radius 20/24/28, elevation untuk kartu dashboard) dan `textMuted` gagal kontras AA (≈2.54:1). | `app_radius.dart:5-8`; `app_colors.dart:83`; `app_shadows.dart:20-31`. |
| GAP-11 | `ApiService.toggleRelay` mengembalikan bool dan tidak pernah melempar; pemanggil mengabaikannya → status optimistis ON permanen saat gagal. | `api_service.dart:62-74`; `dashboard_page.dart:68-90`. |
| GAP-12 | Polling jalan terus di tab lain & background, tanpa timeout request. | `main.dart:54-60, 76-79`; `dashboard_page.dart:33`; grep `AppLifecycleState`/`timeout` = 0. |
| GAP-13 | Payload `target_relays` tidak divalidasi panjangnya → `RangeError` bila <6; `relays` (aktual) tidak pernah dipakai. | `dashboard_page.dart:53-55, 570`; `flask_agrisense/app.py:343-344`. |
| GAP-14 | `TimerBottomSheet` hanya membangun 3 dari 5 durasi (30 & 60 menit tak terjangkau), chip 40dp, copy "blok hidroponik melon" hardcoded. | `timer_bottom_sheet.dart:26, 95, 103, 110-113`. |

### Must have

- Token dashboard yang lengkap dan dipakai: warna surface/kartu/aksen, radius 20/24/28, elevation kartu, motion, ukuran shell, dan skala tipografi metrik (angka tabular).
- Font dibundel di aplikasi (Plus Jakarta Sans 400–800, Inter 400–700) sehingga render deterministik di test dan tanpa unduhan runtime.
- `DashboardPage` dengan sumber data yang dapat diinjeksi, interval polling opsional, batas waktu request, gating lifecycle/tab, `lastSuccessAt`, dan perilaku "pertahankan data lama + tandai basi".
- Header status + strip ringkasan yang menggantikan 3 kartu bento 9–12px.
- `ClimateHeroCard` dan `Npk7In1Card` dibangun ulang penuh di atas token, termasuk state data-tidak-tersedia.
- `RelaySpec` sebagai satu sumber kebenaran (nama, ikon, aksen, terlindungi, deskripsi) + kartu relay aksesibel + grid responsif.
- Shell (`main.dart`, `AgriAppBar`, `AgriBottomNavBar`) memakai token ukuran, Semantics, dan injeksi untuk test.
- Fixture payload nyata (sesuai `app.py:326-352`) + widget test semua state + 8 golden PNG (4 state × 2 lebar).
- `flutter analyze` 0 issue dan `flutter test` hijau.

### Must NOT have (guardrails, anti-slop, scope boundaries)

- **Jangan** mendesain ulang `analytics_page.dart`, `ai_performance_page.dart`, `ai_recommendation_page.dart`, `automation_page.dart`, `settings_page.dart`, `splash_screen.dart`. Ketiganya masih memakai gradient salinan (`ai_recommendation_page.dart:271-274`, `automation_page.dart:639-642`, `settings_page.dart:253-256`) dan itu **ditunda**, bukan diklaim selesai. Kriteria "tidak rusak" untuk file itu = `flutter analyze` bersih + smoke test `MainShell` hijau.
- **Jangan** menambah mode gelap, `shared_preferences`/state management, paket UI/chart baru, atau mengganti `fl_chart`.
- **Jangan** mengubah endpoint/backend Flask, skema DB, atau firmware; jangan mengubah signature publik `ApiService` yang dipakai halaman lain (boleh menambah parameter opsional/`timeout`).
- **Jangan** menambah fitur: notifikasi, penjadwalan, multi-greenhouse, login, riwayat tren baru (tidak ada endpoint tren untuk hero — sparkline palsu dihapus, bukan diganti data karangan).
- **Jangan** menambah folder platform `web/` atau `linux/` (keputusan user: bukti visual = golden PNG).
- **Jangan** `git init` (keputusan user); rollback memakai snapshot pra-gelombang.
- **Jangan** memakai animasi dekoratif yang tidak terikat perubahan status; jangan memakai `fontSize:` mentah di subtree dashboard.
- **Jangan** menghapus file di luar `status_banner_card.dart` dan `sensor_metric_card.dart` (dua dead code yang disetujui).

## Verification strategy

- **Test decision:** tests-after (bukan TDD), framework `flutter_test` + `matchesGoldenFile`. Tanpa paket mock baru: fetcher disuntik sebagai fungsi.
- **Gerbang wajib setiap todo:** `cd Green_House_App && flutter analyze` (harus `No issues found!`) dan `flutter test <file terkait>` hijau.
- **Bukti:** `.omo/evidence/dashboard-modern-redesign/task-<N>-dashboard-modern-redesign.<ext>` (teks untuk perintah+output, `.png` untuk golden). Semua verifikasi dijalankan agent; tidak ada langkah manual manusia.
- **Golden** hanya di-*generate* di todo 12 (`flutter test --update-goldens test/dashboard/dashboard_golden_test.dart`), lalu diverifikasi ulang tanpa `--update-goldens` dan PNG-nya dibuka/diperiksa (agent bisa membaca gambar).
- **Ambang "basi":** 15 detik, sama dengan ambang `is_online` server (`flask_agrisense/app.py:324`).
- **Baseline terukur hari ini:** `flutter analyze` → `No issues found!`; `flutter test` → 1 test lulus (dengan log `Failed to fetch settings for app bar`).

## Execution strategy

### Parallel execution waves

- **Wave 0 (pre-flight, bukan todo):** snapshot rollback `tar -czf /tmp/opencode/dashboard-pre-redesign-$(date +%Y%m%d-%H%M).tar.gz lib test pubspec.yaml` dari `Green_House_App`, catat path-nya di `.omo/evidence/`.
- **Wave 1 - fondasi (paralel):** T1 font, T2 token+kontras, T3 model data.
- **Wave 2 - kartu & state (paralel):** T4 state machine, T8 hero, T9 nutrisi, T10 relay, T11 timer sheet.
- **Wave 3 - frame (paralel):** T5 header+ringkasan, T6 grid aktuator, T7 shell.
- **Wave 4 - bukti & bersih-bersih:** T12 golden, T13 cleanup + sapuan akhir.
- **Final verification wave:** F1–F4 paralel setelah semua todo.

### Dependency matrix

| Todo | Depends on | Blocks | Can parallelize with |
| --- | --- | --- | --- |
| T1 fonts | - | T2 (typography), T8, T9, T12 | T2, T3 |
| T2 tokens | - | T4, T5, T6, T8, T9, T10, T11, T12 | T1, T3 |
| T3 model | - | T4, T5, T6, T9, T12 | T1, T2 |
| T4 state machine | T3 | T5, T6, T12 | T8, T9, T10, T11 |
| T8 hero | T1, T2 | T12 | T4, T9, T10, T11 |
| T9 nutrisi | T1, T2, T3 | T12 | T4, T8, T10, T11 |
| T10 relay | T2, T3 | T12 | T4, T8, T9, T11 |
| T11 timer sheet | T2 | T12 | T4, T8, T9, T10 |
| T5 header/ringkasan | T2, T3, T4 | T12 | T6, T7 |
| T6 grid aktuator | T2, T3, T4 | T12 | T5, T7 |
| T7 shell | T2 | T12 | T5, T6 |
| T12 goldens | T4, T5, T6, T7, T8, T9, T10, T11 | T13 | - |
| T13 cleanup | T12 | F1-F4 | - |

## Todos

- [x] 1. Bundel font Plus Jakarta Sans + Inter dan lepaskan ketergantungan runtime `google_fonts`
  What to do / Must NOT do: Unduh 9 TTF statis ke `assets/fonts/` (`PlusJakartaSans-Regular/Medium/SemiBold/Bold/ExtraBold.ttf`, `Inter-Regular/Medium/SemiBold/Bold.ttf`) memakai Google Fonts CSS API dengan UA lama (hanya UA ini yang mengembalikan `.ttf`, UA IE6 mengembalikan EOT): `UA='Mozilla/5.0 (Linux; U; Android 2.2; en-us; Nexus One Build/FRF91) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1'; curl -sA "$UA" 'https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700'` → ambil tiap `src: url(...ttf)` sesuai blok `font-weight`. Verifikasi tiap file dengan `xxd -l4` = `0001 0000` (bukan `wOFF`/EOT) dan ukuran 40–200 KB. Daftarkan di `pubspec.yaml` blok `flutter: fonts:` (family `PlusJakartaSans` & `Inter`, masing-masing dengan `weight:` yang benar). Ubah `lib/core/theme/app_text_styles.dart` agar memakai `TextStyle(fontFamily: 'PlusJakartaSans' | 'Inter', ...)` lewat dua helper privat; hapus `import 'package:google_fonts/google_fonts.dart'` dan hapus `google_fonts` dari `dependencies`. Must NOT: jangan mengubah ukuran/weight/letterSpacing/height yang sudah ada; jangan menyentuh file lain.
  Closes: (prasyarat IS-2, IS-5; tidak menutup GAP sendiri)
  Parallelization: Wave 1 | Blocked by: - | Blocks: T2, T8, T9, T12
  References (executor has NO interview context - be exhaustive): `lib/core/theme/app_text_styles.dart:1-89` (satu-satunya pemakai `GoogleFonts.` di `lib/`, 12 pemanggilan); `pubspec.yaml:12-24` (dependencies) dan `:33-38` (blok `flutter:`); `lib/core/theme/app_theme.dart:81-95` (memetakan style ke `TextTheme`).
  Acceptance criteria (agent-executable): `cd Green_House_App && flutter pub get && flutter analyze` → `No issues found!`; `grep -rn "google_fonts" lib pubspec.yaml` → 0 hasil; `ls assets/fonts | wc -l` → 9; `xxd -l4 assets/fonts/PlusJakartaSans-Bold.ttf` → `0001 0000`.
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/widget_test.dart` lulus tanpa baris log font error; failure — hapus sementara satu entri `weight: 700` di pubspec lalu `flutter pub get && flutter analyze` harus gagal/kembali ditolak, lalu pulihkan (bukti bahwa blok font benar-benar divalidasi). Evidence `.omo/evidence/dashboard-modern-redesign/task-1-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: quick - unduh aset + satu file tema, mekanis.

- [x] 2. Tambah token dashboard (warna, radius, elevation, motion, ukuran shell, tipografi metrik) + perbaiki kontras `textMuted`
  What to do / Must NOT do: Di `lib/core/theme/app_colors.dart` **tambahkan** (jangan ubah nilai lama kecuali `textMuted`): `canvas = 0xFFF4F7F2`, `card = 0xFFFFFFFF`, `cardMuted = 0xFFEFF4EC`, `cardBorder = 0xFFE2E8DE`, `accent = 0xFF2FA36B`, `accentSoft = 0xFFE3F5EA`; ubah `textMuted` dari `0xFF9CA3AF` → `0xFF5F6B5C` (≥4.5:1 di atas putih); ganti nilai `heroGradient` (saat ini tidak dipakai siapa pun) menjadi 3 stop `0xFF0A3F12 → 0xFF14601F → 0xFF1C7A2B` topLeft→bottomRight. Di `app_radius.dart` tambah `xl2 = 20`, `xl3 = 24`, `xl4 = 28` + `radiusXl2/radiusXl3/radiusXl4`. Di `app_shadows.dart` tambah `cardXs` (`0x08000000`, blur 4, offset (0,1)), `cardRaised` (`0x14000000`, blur 12, offset (0,4)), `hero` (`0x330D631B`, blur 24, offset (0,10), spread -6). Buat `lib/core/theme/app_motion.dart` dengan `fast=150ms`, `base=220ms`, `slow=320ms`, `standard=Curves.easeOutCubic`, `emphasized=Curves.easeInOutCubic`, dan `static bool reduceMotion(BuildContext c) => MediaQuery.maybeOf(c)?.disableAnimations ?? false;`. Di `app_spacing.dart` tambah `appBarHeight=64`, `appBarOuterHeight=80`, `navBarHeight=66`, `navBarOuterHeight=86`, `minTapTarget=48`, `pageTopGap=12`. Di `app_text_styles.dart` tambah `metricHero` (34/40 w700), `metricLg` (28/34 w700), `metricMd` (22/28 w700) — ketiganya `fontFeatures: [FontFeature.tabularFigures()]` — plus `sectionLabel` (11/14 w600, letterSpacing 1.2), `bodyStrong` (14/20 w600), `caption` (11/14 w500). Must NOT: jangan mengubah nilai token lama lain, jangan mengubah `app_theme.dart` selain yang diperlukan untuk memakai font baru.
  Closes: GAP-10
  Parallelization: Wave 1 | Blocked by: T1 (untuk file tipografi) | Blocks: T4, T5, T6, T8, T9, T10, T11, T12
  References (executor has NO interview context - be exhaustive): `lib/core/theme/app_colors.dart:1-84` (palet + `textMuted` di :83, `heroGradient` :16-20); `lib/core/theme/app_radius.dart:1-20`; `lib/core/theme/app_shadows.dart:1-39`; `lib/core/theme/app_spacing.dart:1-22`; `lib/core/theme/app_text_styles.dart:1-89`; pemakaian nyata radius besar: `dashboard_page.dart:103, 259, 444`, `npk_7_in_1_card.dart:29`, `climate_hero_card.dart:32`.
  Acceptance criteria (agent-executable): `flutter analyze` → `No issues found!`; `flutter test test/theme/contrast_test.dart` hijau. File baru `test/theme/contrast_test.dart` menghitung `(L1+0.05)/(L2+0.05)` untuk pasangan: `textPrimary/card`, `textSecondary/card`, `textMuted/card`, `onPrimary/primary`, `onPrimary/accent`, `error/card`, `success/card`, `warning/card`, `info/card`, `onSurface/canvas`, `onSurface/cardMuted`; semua ≥4.5 (≥3.0 hanya untuk teks ≥24px yang ditandai eksplisit di test).
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/theme/contrast_test.dart` → semua pasangan lulus; failure — sementara kembalikan `textMuted` ke `0xFF9CA3AF` lalu jalankan test yang sama, harus GAGAL dengan rasio ≈2.54 (bukti test benar-benar mengukur), lalu pulihkan. Evidence `.omo/evidence/dashboard-modern-redesign/task-2-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: quick - penambahan konstanta + satu unit test murni.

- [x] 3. Buat model `DashboardSnapshot` + mapper toleran (null, relay <6, `ai.mode`)
  What to do / Must NOT do: Buat `lib/features/dashboard/domain/dashboard_snapshot.dart` berisi kelas immutable `DashboardSnapshot` dengan field `double? airTemp, airHum, soilTemp, soilMoisture, ph, ec, n, p, k`, `bool isOnline`, `DateTime? lastSeen`, `String aiMode`, `bool soilOk`, `List<bool> targetRelays` (selalu panjang 6), `List<bool> actualRelays` (selalu panjang 6), dan `factory DashboardSnapshot.fromJson(Map<String, dynamic> json)`. Aturan parsing: angka boleh `num` atau `String` numerik → `double.tryParse`, selain itu `null` (JANGAN `?? 0.0`); `aiMode` dibaca dari `json['ai']?['mode'] ?? json['ai_mode'] ?? 'auto'` lalu `.toString()`; relay dipetakan dari `target_relays`/`relays` dengan padding `false` sampai 6 dan `take(6)` bila lebih; `lastSeen` dari `last_seen` (ISO-8601, abaikan `Z` dengan `DateTime.tryParse`), `isOnline` dari `is_online` (default `false`). Buat juga `lib/features/dashboard/domain/dashboard_status.dart` dengan `enum GreenhouseStatus { optimal, attention, offline }` dan fungsi murni `GreenhouseStatus resolveStatus(DashboardSnapshot s, {required DateTime now, Duration staleAfter = const Duration(seconds: 15)})` serta `List<String> attentionReasons(DashboardSnapshot s)`: offline bila `!isOnline` atau `lastSeen == null` atau `now.difference(lastSeen) > staleAfter`; attention bila suhu di luar 24–30°C, RH di luar 60–80%, pH di luar 5.5–6.5, EC < 300, kelembapan tanah < 40, atau `soilOk == false`; selain itu optimal. Must NOT: jangan menambah dependensi, jangan menyentuh UI.
  Closes: GAP-13, GAP-2 (bagian `ai_mode`), GAP-3 (bagian null vs 0)
  Parallelization: Wave 1 | Blocked by: - | Blocks: T4, T5, T6, T9, T12
  References (executor has NO interview context - be exhaustive): payload nyata `flask_agrisense/app.py:317-352` (`sensors{air_suhu, air_hum, tanah_suhu, tanah_lembap, ph, ec, n, p, k, soil_ok}`, `relays`, `target_relays`, `ai{mode, phase, ec_setpoint, model_version}`, `is_online` dihitung `last_seen < 15s` di :324); pemakaian sekarang `dashboard_page.dart:53-55, 174, 208-211, 570`; `npk_7_in_1_card.dart:13-24`.
  Acceptance criteria (agent-executable): `flutter analyze` bersih; `flutter test test/dashboard/dashboard_snapshot_test.dart` hijau dengan minimal 5 kasus: payload penuh (nilai terbaca benar), payload `{}` (semua `null`, relay 6×false, `aiMode == 'auto'`), `target_relays` panjang 3 (hasil panjang 6, elemen 3-5 `false`), `target_relays` panjang 8 (hasil 6), angka berbentuk String (`"28.4"`) → `28.4`, dan `ai.mode` menang atas `ai_mode`. Plus `test/dashboard/dashboard_status_test.dart`: offline saat `lastSeen` 20 detik lalu, attention saat pH 4.9, optimal saat semua dalam rentang.
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/dashboard/dashboard_snapshot_test.dart test/dashboard/dashboard_status_test.dart` → semua lulus; failure — suapkan `{'target_relays': [true]}` lalu assert tidak ada exception dan `targetRelays.length == 6` (kasus `RangeError` lama). Evidence `.omo/evidence/dashboard-modern-redesign/task-3-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: unspecified-high - model + aturan parsing + dua unit test.

- [x] 4. Tulis ulang state `DashboardPage`: fetcher injectable, polling bergerbang, timeout, data basi dipertahankan
  What to do / Must NOT do: Ubah `DashboardPage` menjadi `DashboardPage({super.key, this.isActive = true, this.fetcher = ApiService.getDashboardLive, this.pollInterval = const Duration(seconds: 5)})` dengan `final Future<Map<String, dynamic>> Function() fetcher;` dan `final Duration? pollInterval;` (`null` = tanpa polling). State: `DashboardSnapshot? _snapshot`, `bool _isLoading`, `String? _error`, `DateTime? _lastSuccessAt`, `bool _isRefreshing`. Perilaku: (a) `_fetchData()` memanggil `widget.fetcher().timeout(const Duration(seconds: 4))`, sukses → set `_snapshot` + `_lastSuccessAt = DateTime.now()` + `_error = null`; gagal/timeout → set `_error` TAPI `_snapshot` dipertahankan; (b) timer hanya aktif bila `widget.isActive && pollInterval != null && lifecycle == resumed`, dikelola lewat `AppLifecycleListener` (`onStateChange`) dan `didUpdateWidget` saat `isActive` berubah — `dispose()` wajib membatalkan timer dan listener; (c) `_toggleRelay(index, currentState)` memeriksa hasil bool: `final ok = await ApiService.toggleRelay(index, !currentState); if (!ok) throw Exception('Perintah relay ditolak server');` lalu revert state + `SnackBar`; hormati `ApiService.isHapticFeedbackEnabled` sebelum `HapticFeedback.lightImpact()`; (d) hapus pembacaan `data['ai_mode']` dan `List<bool>.from(data['target_relays'])` mentah — semua lewat `DashboardSnapshot.fromJson`; (e) `build` merender: `_isLoading && _snapshot == null` → skeleton; `_snapshot == null && _error != null` → state galat dingin (ikon + pesan + tombol "Coba Lagi" 48dp); `_snapshot != null` → konten + `StaleBanner` bila `_error != null` (teks "Gagal memperbarui • data X lalu" + tombol coba lagi). Must NOT: jangan memakai `setState` setelah `await` tanpa cek `mounted`; jangan memanggil `widget.fetcher()` saat widget tidak mounted; jangan mengubah `ApiService` di todo ini.
  Closes: GAP-5, GAP-6, GAP-12, GAP-2 (bagian status palsu)
  Parallelization: Wave 2 | Blocked by: T3 | Blocks: T5, T6, T12
  References (executor has NO interview context - be exhaustive): `dashboard_page.dart:20-90` (state sekarang, timer, optimistic toggle), `:144-205` (build + skeleton), `:92-142` (skeleton); `api_service.dart:49-60` (GET tanpa timeout), `:62-74` (toggle mengembalikan bool); `flask_agrisense/app.py:324` (ambang online 15s); `app_spacing.dart` token baru dari T2.
  Acceptance criteria (agent-executable): `flutter analyze` bersih; `flutter test test/dashboard/dashboard_page_test.dart` hijau untuk: skeleton saat fetcher belum selesai; konten saat fetcher sukses; galat dingin saat fetcher gagal tanpa data; `StaleBanner` muncul saat sukses lalu gagal (data lama tetap terlihat); tidak ada `Timer` pending saat `pollInterval: null` (`tester.pumpAndSettle()` tanpa error "A Timer is still pending"); `isActive: false` tidak memanggil fetcher kedua kali setelah 6 detik (`tester.pump(const Duration(seconds: 6))` lalu hitung pemanggilan fetcher == 1).
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/dashboard/dashboard_page_test.dart --plain-name "state"`; failure — fetcher yang melempar `TimeoutException` harus menghasilkan `StaleBanner` (bukan layar putih) dan tombol "Coba Lagi" memicu pemanggilan fetcher berikutnya (assert `calls == 2`). Evidence `.omo/evidence/dashboard-modern-redesign/task-4-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: unspecified-high - lifecycle/timer/timeout + 5 skenario widget test.

- [x] 5. Buat `DashboardHeader` + `SummaryStrip` (pengganti 3 kartu bento)
  What to do / Must NOT do: Buat `lib/features/dashboard/presentation/widgets/dashboard_header.dart`: baris atas `sectionLabel('GREENHOUSE 01')` + status chip (`Optimal` hijau `successSurface`/`success`, `Perlu perhatian` `warningSurface`/`warning`, `Offline` `surfaceContainerLow`/`textSecondary`) + `IconButton` refresh 48dp (`Semantics(label: 'Muat ulang data')`); baris kedua `caption('Diperbarui X lalu')` memakai `resolveStatus` + `attentionReasons` (maks 2 alasan, dipisah " · "), dan chip "Basi" bila `status == offline` karena umur data. Buat `lib/features/dashboard/presentation/widgets/summary_strip.dart`: SATU kartu (`card`, border `cardBorder`, radius `xl2`, shadow `cardXs`, padding 16) berisi `Wrap(spacing: 16, runSpacing: 12)` dengan 3 `_InlineStat` (min width 92): Mode AI (`snapshot.aiMode.toUpperCase()`), Aktuator (`'$aktif / 6'` + label "menyala"), Tanah (`tanahSuhu` + `tanahLembap` atau "—"). Setiap stat: ikon 18 dalam kotak `accentSoft`, nilai `metricMd`/`headlineSm`, label `caption`, `Semantics(label: '<nama> <nilai>')`. Hapus `_buildBentoQuickStats`/`_bentoMiniCard` dari `dashboard_page.dart`. Must NOT: jangan memakai `Row` 3 `Expanded`; jangan hardcode "Optimal"; jangan `fontSize:` mentah.
  Closes: GAP-2, GAP-8 (bagian Semantics), GAP-5 (bagian penanda basi)
  Parallelization: Wave 3 | Blocked by: T2, T3, T4 | Blocks: T12
  References (executor has NO interview context - be exhaustive): `dashboard_page.dart:207-317` (bento lama + teks 9–12px), `:173-205` (urutan render); `dashboard_status.dart` (T3); token T2 (`canvas`, `card`, `cardBorder`, `cardXs`, `metricMd`, `caption`, `sectionLabel`, `minTapTarget`); `app_colors.dart:70-78` (semantic surface).
  Acceptance criteria (agent-executable): `flutter analyze` bersih; `flutter test test/dashboard/dashboard_header_test.dart` hijau: chip "Perlu perhatian" muncul saat pH 4.9; chip "Offline" saat `last_seen` 20 detik lalu; teks "Diperbarui" selalu ada; refresh button punya ukuran ≥48×48 (`tester.getSize`).
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/dashboard/dashboard_header_test.dart`; failure — set `textScaler: TextScaler.linear(1.3)` pada `MediaQuery` lalu render strip pada lebar 360; assert `tester.takeException() == null` dan tidak ada `RenderFlex overflowed`. Evidence `.omo/evidence/dashboard-modern-redesign/task-5-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: visual-engineering - komposisi UI + Semantics.

- [x] 6. Section aktuator + grid responsif (2/3 kolom) memakai `LayoutBuilder`
  What to do / Must NOT do: Di `dashboard_page.dart` ganti `_buildRelayHeader` dan `_buildRelayGrid`: header = `headlineSm('Kontrol Aktuator')` + chip `'$aktif / 6 aktif'` + tombol "Atur Durasi" (tinggi ≥48, radius `xl`, ikon `Icons.timer_outlined` 18, teks `labelLg`). Grid: `LayoutBuilder` → `final cols = constraints.maxWidth >= 600 ? 3 : 2; final gap = 12.0; final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;` lalu `Wrap(spacing: gap, runSpacing: gap, children: [...SizedBox(width: itemWidth, child: RelayControlCard(...))])`. Hapus `buildIntrinsicGrid`. Must NOT: jangan memakai `GridView` di dalam `SingleChildScrollView`; jangan menyisakan `SizedBox(width: 10)` hardcoded.
  Closes: GAP-4 (bagian grid), GAP-8 (bagian target sentuh tombol)
  Parallelization: Wave 3 | Blocked by: T2, T3, T4 | Blocks: T12
  References (executor has NO interview context - be exhaustive): `dashboard_page.dart:321-402` (header + tombol timer), `:558-608` (grid manual), `:406-556` (dialog konfirmasi relay terlindungi — pertahankan perilakunya, hanya ganti warna/radius ke token); token T2 (`xl`, `xl2`, `minTapTarget`, `cardBorder`).
  Acceptance criteria (agent-executable): `flutter analyze` bersih; `flutter test test/dashboard/dashboard_grid_test.dart` hijau: pada lebar 360 → 2 kolom (dua `RelayControlCard` pertama punya `top` sama); pada lebar 800 → 3 kolom; tidak ada overflow pada `TextScaler.linear(1.3)`; tombol "Atur Durasi" ≥48 tinggi.
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/dashboard/dashboard_grid_test.dart`; failure — render 6 kartu pada lebar 320 dengan textScale 1.3, assert `tester.takeException() == null` (tidak ada `RenderFlex overflowed`). Evidence `.omo/evidence/dashboard-modern-redesign/task-6-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: visual-engineering - layout responsif + tes ukuran.

- [x] 7. Selaraskan shell: token ukuran, inset benar, Semantics, dan injeksi untuk test
  What to do / Must NOT do: Di `main.dart` ganti `_pages` statis menjadi daftar yang dibangun di `build()` dengan `DashboardPage(isActive: _currentIndex == 0)` (halaman lain tetap `const`), dan ganti padding body menjadi `EdgeInsets.only(top: MediaQuery.of(context).padding.top + AppSpacing.appBarOuterHeight, bottom: AppSpacing.navBarOuterHeight + MediaQuery.of(context).padding.bottom)`. Di `app_bar_widget.dart`: tambah parameter opsional `final Future<Map<String, dynamic>> Function() settingsLoader;` (default `ApiService.getSettings`) dan `final ImageProvider? avatarImage;` (bila `null` pakai perilaku sekarang, dan bila `avatar_url` kosong pakai ikon); ganti `16`/`64` dengan `AppSpacing`; pakai `_PulsingDot` yang sekarang mati untuk titik status; tambah `Semantics(label: 'Profil <nama>')` pada avatar. Di `bottom_nav_bar.dart`: tinggi/radius dari token (`navBarHeight`, `xl3`), bungkus tiap item dengan `Semantics(button: true, selected: isActive, label: item.label)` dan `InkWell` (ripple) alih-alih `GestureDetector`, aksen aktif `accent`. Ubah `test/widget_test.dart` agar `MainShell` di-pump dengan `HttpOverrides` yang menolak semua request dan assert tidak ada exception (tidak lagi mencetak "Failed to fetch settings"). Must NOT: jangan mengubah tinggi visual AppBar (tetap 64) atau urutan item navigasi; jangan mengubah 5 halaman lain.
  Closes: GAP-7, GAP-8 (bagian shell), GAP-12 (bagian injeksi)
  Parallelization: Wave 3 | Blocked by: T2 | Blocks: T12
  References (executor has NO interview context - be exhaustive): `main.dart:43-88` (shell + padding magis :71-75, `_pages` :54-60); `app_bar_widget.dart:8-18` (preferredSize 84), `:56-66` (SafeArea+16+64), `:246-294` (`_PulsingDot` mati); `bottom_nav_bar.dart:26-73` (padding 18/20 + tinggi 66), `:87-152` (item + GestureDetector); token T2 (`appBarOuterHeight`, `navBarOuterHeight`, `navBarHeight`, `xl3`, `accent`).
  Acceptance criteria (agent-executable): `flutter analyze` bersih; `flutter test test/widget_test.dart test/shared/shell_layout_test.dart` hijau; test shell merakit `Scaffold(appBar: AgriAppBar(settingsLoader: fake), body: SizedBox.expand(), bottomNavigationBar: AgriBottomNavBar(...))` dan meng-assert `tester.getRect(find.byKey(const Key('shell-body-probe'))).top >= 80` serta `.bottom <= 800 - 86` pada permukaan 360×800.
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/shared/shell_layout_test.dart`; failure — set `MediaQuery.padding.top = 24` lalu assert konten tetap mulai ≥ `24 + 80` (inset tidak boleh memakai angka 64 lama). Evidence `.omo/evidence/dashboard-modern-redesign/task-7-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: unspecified-high - tiga file shell + tes geometri inset.

- [x] 8. Bangun ulang `ClimateHeroCard` jadi hero botanikal data-forward (tanpa orb & sparkline palsu)
  What to do / Must NOT do: Tulis ulang `lib/features/dashboard/presentation/widgets/climate_hero_card.dart` sebagai `ClimateHeroCard({required double? temperature, required double? humidity, required GreenhouseStatus status, required String updatedLabel})`. Struktur: `Container` radius `xl3` (24), `gradient: AppColors.heroGradient`, `boxShadow: [AppShadows.hero]`, padding 20. Isi: (1) baris atas — logo 36 (`assets/images/greenhouse_logo.png`, `errorBuilder` → `Icons.eco`) + teks "Greenhouse 01" `labelLg` putih + "Mikroklimat" `caption` putih 70% + status chip (putih 14% bg, border putih 24%, titik status + teks `caption`); (2) dua tile metrik (bg putih 10%, border putih 18%, radius `xl`, padding 14): label `caption` putih 75%, nilai `metricHero` putih (atau "—" bila `null`), unit `caption` putih 70%, ikon 20; (3) footer tanpa gradient gelap: dua chip ambang "Ideal 24–30°C" dan "RH 60–80%" (`caption`, bg putih 10%) — TIDAK ADA sparkline. Hapus `_SparklinePainter` dan seluruh `Positioned(...)` orb. Semua teks memakai `AppTextStyles`, semua warna dari `AppColors`/putih-opacity, animasi nilai memakai `AppMotion.base` + `reduceMotion`. Must NOT: jangan memakai `Color(0x...)` literal, `fontSize:`, `Positioned(`, atau `Image.asset` selain logo.
  Closes: GAP-1, GAP-8 (bagian teks)
  Parallelization: Wave 2 | Blocked by: T1, T2 | Blocks: T12
  References (executor has NO interview context - be exhaustive): `climate_hero_card.dart:1-419` (versi lama: gradient 4 stop :21-46, orb :50-113, header :127-212, tile :294-389, footer + sparkline :247-285, `_SparklinePainter` :391-419); `app_colors.dart:16-20` (`heroGradient` baru), `:70-78` (semantic); `dashboard_status.dart` (T3); `app_motion.dart` (T2).
  Acceptance criteria (agent-executable): `flutter analyze` bersih; `grep -c "Positioned(" lib/features/dashboard/presentation/widgets/climate_hero_card.dart` → 0; `grep -c "Color(0x" ...` → 0; `grep -c "fontSize:" ...` → 0; `flutter test test/dashboard/climate_hero_test.dart` hijau: nilai `28.4` tampil, `temperature: null` menampilkan "—" tanpa exception, status `offline` menampilkan chip "Offline".
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/dashboard/climate_hero_test.dart`; failure — render dengan `temperature: null, humidity: null` dan `TextScaler.linear(1.3)` pada lebar 360; assert `tester.takeException() == null` dan tidak ada `RenderFlex overflowed`. Evidence `.omo/evidence/dashboard-modern-redesign/task-8-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: visual-engineering - hero visual penuh.

- [x] 9. Bangun ulang `Npk7In1Card` di atas token + state data-tidak-tersedia per metrik
  What to do / Must NOT do: Tulis ulang `lib/features/dashboard/presentation/widgets/npk_7_in_1_card.dart` sebagai `Npk7In1Card({required DashboardSnapshot snapshot})`. Latar: `AppColors.card`, border `cardBorder`, radius `xl3`, shadow `cardSm` — hapus `DecorationImage`/overlay/gradient gelap. Header: `headlineSm('Nutrisi & Substrat')` + `caption('Sensor 7-in-1')` + chip status (LIVE `accentSoft`/`accent` bila segar, "Basi" `warningSurface`/`warning` bila tidak). Baris NPK: 3 tile (`N` `success`, `P` `warning`, `K` `info`): badge huruf 32 radius `lg`, label `caption`, nilai `metricMd` atau "—", unit `caption`, progress bar 4px terhadap target (150/60/220) dan teks "Target 150". Grid sekunder: `LayoutBuilder` → 2 kolom (<600) / 4 kolom (≥600) via `Wrap`, tiap tile berisi ikon 18, label `caption`, nilai `metricMd`/headlineSm, chip status (`success`/`warning`/`textMuted`) atau "Tidak ada data". Aturan: `null` → nilai "—" dan chip "Tidak ada data" (bukan 0, bukan "⚠ Rendah"); semua `null` → panel kosong "Sensor 7-in-1 tidak terdeteksi" + `caption` panduan; `soilOk == false` → chip "Tanah bermasalah" `warning`. Must NOT: jangan memakai teks putih/`white38`/`white54` di atas kartu terang, jangan `?? 0.0`, jangan ambang alarm yang menghasilkan "⚠" untuk nilai kosong.
  Closes: GAP-3, GAP-8 (bagian teks), GAP-2 (bagian nilai palsu)
  Parallelization: Wave 2 | Blocked by: T1, T2, T3 | Blocks: T12
  References (executor has NO interview context - be exhaustive): `npk_7_in_1_card.dart:1-551` (versi lama: header :88-113, empty state :118-152, NPK row :155-199, metrik :220-276, `_NpkTile` :339-461, `_MetricTile` :463-551); payload `flask_agrisense/app.py:331-342` (`soil_ok`); `dashboard_snapshot.dart` (T3); token T2.
  Acceptance criteria (agent-executable): `flutter analyze` bersih; `grep -c "white38\|white54\|Color(0x" lib/features/dashboard/presentation/widgets/npk_7_in_1_card.dart` → 0; `flutter test test/dashboard/npk_card_test.dart` hijau: payload penuh menampilkan 3 huruf NPK + 4 metrik; `n: null` → "—" dan chip "Tidak ada data"; semua `null` → "Sensor 7-in-1 tidak terdeteksi"; `soilOk: false` → chip "Tanah bermasalah".
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/dashboard/npk_card_test.dart`; failure — payload dengan `ph: null, ec: null` harus TIDAK memunculkan teks "Rendah"/"Koreksi" (assert `find.textContaining('Rendah')` kosong) dan tidak melempar. Evidence `.omo/evidence/dashboard-modern-redesign/task-9-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: visual-engineering - kartu data padat + state per metrik.

- [x] 10. Buat `RelaySpec` + bangun ulang `RelayControlCard` (aksesibel, jujur soal kegagalan)
  What to do / Must NOT do: Buat `lib/features/dashboard/domain/relay_spec.dart` berisi `class RelaySpec { final int index; final String name; final String shortName; final IconData icon; final Color accent; final bool isProtected; final String description; }` dan `const List<RelaySpec> relaySpecs` (6 entri, urutan ESP32): 0 Dosing Pupuk A (`Icons.colorize_rounded`, `success`, protected), 1 Dosing Pupuk B (`Icons.vaccines_rounded`, `info`, protected), 2 pH Up (`Icons.arrow_circle_up_rounded`, `accent`, protected), 3 pH Down (`Icons.arrow_circle_down_rounded`, `tertiary`, protected), 4 Exhaust Blower (`Icons.air_rounded`, `warning`, bebas), 5 Pompa Irigasi (`Icons.water_drop_rounded`, `secondary`, bebas) — deskripsi perlindungan disalin dari `dashboard_page.dart:424-427`. Tulis ulang `RelayControlCard({required RelaySpec spec, required bool isOn, required bool isPending, required VoidCallback onToggle})`: `Material(color: isOn ? accentSoft : card, borderRadius: xl2) > InkWell(onTap) > Padding(14) > Column`, isi: baris atas (kotak ikon 40 radius `lg` + `Switch` dengan `activeColor`/`activeTrackColor` dari `accent`), nama `labelMd`, baris status: chip "Aktif"/"Siaga"/"Terlindungi" + chip "Menunggu perangkat" bila `isPending`. Bungkus kartu dengan `Semantics(container: true, button: true, toggled: isOn, label: '<nama>, <status>', onTap: onToggle)` dan `ExcludeSemantics` pada `Switch`. Animasi `AppMotion.base`, hormati `AppMotion.reduceMotion`. Hapus `RelayData` dan `_accentColor()` (tebak warna dari nama). Must NOT: jangan memanggil `HapticFeedback` di dalam kartu (pemanggilan tetap di halaman, mengikuti setelan pengguna); jangan memakai `GestureDetector`; jangan `minHeight: 120` + konten yang bisa meluap.
  Closes: GAP-4, GAP-11, GAP-8 (bagian target sentuh/Semantics)
  Parallelization: Wave 2 | Blocked by: T2, T3 | Blocks: T12
  References (executor has NO interview context - be exhaustive): `relay_control_card.dart:1-285` (versi lama: `RelayData` :7-21, `_accentColor` :36-45, `GestureDetector` :51-55, `minHeight: 120` :59, switch :238-284); `dashboard_page.dart:406-556` (nama, ikon, warna, deskripsi, dialog konfirmasi), `:68-90` (toggle + haptic); `flask_agrisense/app.py:343-344` (`relays` aktual vs `target_relays`).
  Acceptance criteria (agent-executable): `flutter analyze` bersih; `grep -c "GestureDetector" lib/features/dashboard/presentation/widgets/relay_control_card.dart` → 0; `flutter test test/dashboard/relay_card_test.dart` hijau: tap kartu memanggil `onToggle` tepat sekali; `Semantics` node punya `toggled: true` saat `isOn`; `isPending: true` menampilkan "Menunggu perangkat"; ukuran kartu ≥48×48; `relaySpecs.length == 6` dan 4 pertama `isProtected == true`.
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/dashboard/relay_card_test.dart`; failure — render `isOn: false, isPending: true` dengan `TextScaler.linear(1.3)` pada lebar 160 (item grid tersempit), assert `tester.takeException() == null` dan teks nama tidak overflow (pakai `maxLines: 2` + ellipsis). Evidence `.omo/evidence/dashboard-modern-redesign/task-10-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: visual-engineering - komponen interaktif + Semantics.

- [x] 11. Perbaiki `TimerBottomSheet`: semua durasi terjangkau, target 48dp, copy netral
  What to do / Must NOT do: Ganti `List.generate(3, ...)` menjadi `List.generate(_durations.length, ...)`; naikkan tinggi chip pilihan durasi ke ≥48 dan bungkus dengan `Semantics(button: true, selected: ...)`; tombol tutup 48×48; ganti copy hardcoded "blok hidroponik melon" menjadi "Pompa Irigasi"; radius/padding memakai token T2 (`xl3`, `minTapTarget`). Must NOT: jangan mengubah signature `TimerBottomSheet.show(context)` (dipakai `dashboard_page.dart:352`); jangan mengubah nilai durasi.
  Closes: GAP-14, GAP-8 (bagian target sentuh sheet)
  Parallelization: Wave 2 | Blocked by: T2 | Blocks: T12
  References (executor has NO interview context - be exhaustive): `timer_bottom_sheet.dart:1-181` (`_durations` :26, copy :95, `List.generate(3` :103, chip `GestureDetector` :110-113, tombol tutup :82-89); pemanggil `dashboard_page.dart:350-371`.
  Acceptance criteria (agent-executable): `flutter analyze` bersih; `flutter test test/dashboard/timer_sheet_test.dart` hijau: 5 chip tampil ("5","10","15","30","60"), tap "60" mengembalikan `60`, tombol tutup ≥48×48, tidak ada teks "melon".
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/dashboard/timer_sheet_test.dart`; failure — buka sheet pada lebar 320 + `TextScaler.linear(1.3)`, assert tidak ada overflow dan semua chip tetap bisa di-tap. Evidence `.omo/evidence/dashboard-modern-redesign/task-11-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: quick - satu file, perubahan mekanis + tes kecil.

- [x] 12. Golden test: 4 state × 2 lebar + fixture payload nyata
  What to do / Must NOT do: Buat `test/support/fake_dashboard.dart` (builder payload sesuai `app.py:326-352`) dengan 4 varian: `healthyPayload()`, `stalePayload()` (tanggal `last_seen` 60 detik lalu), `emptySensorsPayload()` (semua sensor `null`), dan `partialPayload()` (`ph`/`ec` `null`, `target_relays` panjang 3). Buat `test/dashboard/dashboard_golden_test.dart`: untuk tiap state, render `MaterialApp(theme: AppTheme.light, home: Scaffold(body: DashboardPage(isActive: false, pollInterval: null, fetcher: fakeFetcher)))` pada permukaan 360×800 dan 800×1280 (`tester.view.physicalSize`, `devicePixelRatio = 1.0`, reset di `addTearDown`), dengan `setUpAll` memuat font via `FontLoader('PlusJakartaSans')..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'))` (idem `Inter`) supaya teks tidak menjadi kotak. Golden file: `test/dashboard/goldens/<state>_<width>.png` (8 file). Must NOT: jangan memakai `Image.network` di subtree golden (avatar AppBar tidak ikut di-render karena golden hanya body); jangan memakai tanggal "sekarang" tanpa di-inject (pakai `now` tetap: `DateTime(2026, 11, 5, 9, 0)`).
  Closes: GAP-6 (bukti visual), IS-7
  Parallelization: Wave 4 | Blocked by: T4, T5, T6, T7, T8, T9, T10, T11 | Blocks: T13
  References (executor has NO interview context - be exhaustive): `test/widget_test.dart:1-15` (satu-satunya test sekarang); payload `flask_agrisense/app.py:326-352`; `dashboard_page.dart` (kontrak baru dari T4); `app_theme.dart:8-79`; font hasil T1 di `assets/fonts/`.
  Acceptance criteria (agent-executable): `flutter test --update-goldens test/dashboard/dashboard_golden_test.dart` menghasilkan 8 PNG; lalu `flutter test test/dashboard` hijau tanpa `--update-goldens`; `ls test/dashboard/goldens | wc -l` → 8; setiap PNG >10 KB dan berdimensi sesuai lebar (dibuka dengan tool `read` untuk pemeriksaan visual).
  QA scenarios (name the exact tool + invocation): happy — `flutter test test/dashboard` → semua lulus termasuk 8 golden; failure — ubah sementara satu token warna (`AppColors.card` → `0xFFFFF0F0`) lalu jalankan `flutter test test/dashboard/dashboard_golden_test.dart`, harus GAGAL (golden mismatch), lalu pulihkan (bukti golden benar-benar mengunci tampilan). Evidence `.omo/evidence/dashboard-modern-redesign/task-12-dashboard-modern-redesign.png`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: unspecified-high - fixture + 8 golden + setup font.

- [x] 13. Bersihkan dead code + sapuan akhir analyze/test
  What to do / Must NOT do: Hapus `lib/features/dashboard/presentation/widgets/status_banner_card.dart` dan `lib/features/dashboard/presentation/widgets/sensor_metric_card.dart` (keduanya tidak diimpor siapa pun; penggantinya `DashboardHeader`/`SummaryStrip`). Pastikan tidak ada `import` tersisa, tidak ada `_PulsingDot` yatim (sudah dipakai di AppBar oleh T7), dan tidak ada `Positioned(`/`Color(0x`/`fontSize:` mentah di subtree `lib/features/dashboard/**` selain nilai yang berasal dari token. Jalankan `dart format lib test`. Must NOT: jangan menghapus file lain; jangan memformat ulang file di luar `lib/features/dashboard/**`, `lib/core/theme/**`, `lib/shared/widgets/**`, `lib/main.dart`, `test/**`.
  Closes: GAP-9
  Parallelization: Wave 4 | Blocked by: T12 | Blocks: F1-F4
  References (executor has NO interview context - be exhaustive): `status_banner_card.dart:1-200` (dead); `sensor_metric_card.dart:1-253` (dead); `dashboard_page.dart:8-11` (import aktif hanya climate/npk/relay/timer); `app_bar_widget.dart:246-294` (`_PulsingDot`).
  Acceptance criteria (agent-executable): `grep -rn "status_banner_card\|sensor_metric_card" lib test` → 0 hasil; `flutter analyze` → `No issues found!`; `flutter test` → semua lulus; `grep -rn "fontSize:" lib/features/dashboard | grep -v "AppTextStyles"` → 0 hasil.
  QA scenarios (name the exact tool + invocation): happy — `cd Green_House_App && flutter analyze && flutter test`; failure — tambahkan sementara satu `fontSize: 9` di salah satu widget dashboard lalu jalankan grep di atas, harus menemukan 1 baris (bukti gerbang anti-hardcode bekerja), lalu hapus. Evidence `.omo/evidence/dashboard-modern-redesign/task-13-dashboard-modern-redesign.txt`
  Commit: N (no VCS - snapshot Wave 0 + gerbang analyze/test)
  Recommended task executor category: quick - penghapusan file + sapuan grep/format.

## Final verification wave

> Runs in parallel after ALL todos. ALL must APPROVE. Surface results and wait for the user's explicit okay before declaring complete.

- [x] F1. Plan compliance audit
  Verifikasi setiap todo 1–13 benar-benar dieksekusi sesuai "What to do / Must NOT do": baca diff nyata per file, jalankan ulang setiap acceptance command, dan tolak klaim tanpa output. Cek Must NOT have: tidak ada perubahan di 6 halaman tab lain, tidak ada `web/`/`linux/`, tidak ada `git init`, tidak ada dependensi baru selain penghapusan `google_fonts`. Evidence `.omo/evidence/dashboard-modern-redesign/F1-dashboard-modern-redesign.txt`
- [x] F2. Code quality review
  Review `lib/features/dashboard/**`, `lib/core/theme/**`, `lib/shared/widgets/**`, `lib/main.dart`: tidak ada `setState` setelah `await` tanpa `mounted`, semua `Timer`/`AppLifecycleListener` dibatalkan di `dispose`, tidak ada `?? 0.0` pada sensor, tidak ada `Color(0x`/`fontSize:` mentah di subtree dashboard, `dart format` bersih, `flutter analyze` 0 issue. Evidence `.omo/evidence/dashboard-modern-redesign/F2-dashboard-modern-redesign.txt`
- [x] F3. Real QA (tanpa perangkat)
  Jalankan `flutter test` penuh + buka 8 PNG golden dengan tool `read` dan periksa daftar: angka terbaca, tidak ada teks terpotong, tidak ada elemen tumpang tindih, chip status sesuai state, tidak ada kotak-kotak font. Jalankan juga `flutter run -d linux` **hanya bila** folder `linux/` ada; bila tidak, catat "tidak tersedia - bukti = golden PNG" dan lanjutkan. Evidence `.omo/evidence/dashboard-modern-redesign/F3-dashboard-modern-redesign.png`
- [x] F4. Ideal-state fidelity
  Petakan IS-1..IS-10 satu per satu ke bukti nyata (test name + golden + output perintah). Setiap kekurangan menjadi baris `- [ ] N.` baru di `## Todos`, bukan catatan. Evidence `.omo/evidence/dashboard-modern-redesign/F4-dashboard-modern-redesign.txt`

## Commit strategy

Tidak ada VCS di workspace ini (`git rev-parse` → `fatal: not a git repository`) dan user memilih tanpa `git init`. Karena itu:

- **Rollback:** satu snapshot sebelum Wave 1 — `tar -czf /tmp/opencode/dashboard-pre-redesign-$(date +%Y%m%d-%H%M).tar.gz lib test pubspec.yaml` dijalankan dari `Green_House_App`; path snapshot dicatat di `.omo/evidence/dashboard-modern-redesign/wave0-snapshot.txt`.
- **Checkpoint per todo:** `flutter analyze` + `flutter test` (file terkait) harus hijau sebelum todo berikutnya di gelombang yang sama dimulai.
- **Tidak ada commit** — setiap todo memakai `Commit: N`.

## Success criteria

| IS | Delivering todo(s) | Proving QA scenario | Evidence |
| --- | --- | --- | --- |
| IS-1 | T4, T5 | `dashboard_header_test.dart` (status + "Diperbarui") + golden `healthy_360.png` | `.omo/evidence/dashboard-modern-redesign/task-5-dashboard-modern-redesign.txt` |
| IS-2 | T1, T2, T9, T10 | `contrast_test.dart` semua pasangan ≥4.5 + golden `healthy_360.png` dibaca (label ≥12px) | `.omo/evidence/dashboard-modern-redesign/task-2-dashboard-modern-redesign.txt` |
| IS-3 | T6, T10 | `relay_card_test.dart` (Semantics `toggled`, tap sekali, "Menunggu perangkat") + `dashboard_grid_test.dart` (2/3 kolom, target ≥48) | `.omo/evidence/dashboard-modern-redesign/task-10-dashboard-modern-redesign.txt` |
| IS-4 | T3, T4, T9 | `dashboard_page_test.dart` (basi + galat dingin) + `npk_card_test.dart` (null → "—") + golden `stale_360.png`, `empty_sensors_360.png` | `.omo/evidence/dashboard-modern-redesign/task-9-dashboard-modern-redesign.txt` |
| IS-5 | T2, T8, T9, T10, T13 | `grep -c "Color(0x"`/`fontSize:` di subtree dashboard = 0 + `flutter analyze` | `.omo/evidence/dashboard-modern-redesign/task-13-dashboard-modern-redesign.txt` |
| IS-6 | T5, T6, T8, T10 | matriks 360/600/840dp × textScaler 1.0/1.3 tanpa `RenderFlex overflowed` di `dashboard_grid_test.dart` + `dashboard_header_test.dart` | `.omo/evidence/dashboard-modern-redesign/task-6-dashboard-modern-redesign.txt` |
| IS-7 | T3, T4, T12 | `flutter test test/dashboard` (4 state, 2 lebar) + 8 PNG golden dibuka | `.omo/evidence/dashboard-modern-redesign/task-12-dashboard-modern-redesign.png` |
| IS-8 | T2, T8, T10 | semua durasi animasi berasal dari `AppMotion` (`grep -c "Duration(milliseconds" lib/features/dashboard` = 0) + `reduceMotion` dipakai di hero/relay | `.omo/evidence/dashboard-modern-redesign/task-8-dashboard-modern-redesign.txt` |
| IS-9 | T10, T4 | `dashboard_page_test.dart` kasus toggle gagal: kartu kembali OFF + `SnackBar` tampil | `.omo/evidence/dashboard-modern-redesign/task-4-dashboard-modern-redesign.txt` |
| IS-10 | T4, T7 | `dashboard_page_test.dart`: `isActive: false` → fetcher dipanggil 1× setelah 6 detik; `pollInterval: null` → tanpa timer pending; `.timeout` terpasang | `.omo/evidence/dashboard-modern-redesign/task-4-dashboard-modern-redesign.txt` |

