# mac-mod

**Clean minimal × Gundam cockpit**, dengan wallpaper gambar sungguhan dan widget native macOS berbahan kaca transparan.

![Gundam orbital hangar wallpaper](assets/wallpapers/gundam-hangar.png)

Wallpaper PNG diterapkan melalui pengaturan desktop macOS. Panel console, telemetry, dan kalender memakai SwiftUI/AppKit dan `NSVisualEffectView`; semuanya menerima klik, dapat digeser, dan berada di belakang jendela aplikasi biasa. Dock memakai bawaan macOS di bagian bawah layar.

## Widget yang berfungsi

- **Jam WIB** berdetik, diperbarui setiap detik.
- **Focus timer 25 menit**: Start, Pause, Resume, Reset, dan bunyi saat selesai. Timer memakai deadline waktu nyata sehingga tetap benar setelah Mac tidur.
- **Kalender kaca** dengan highlight hari ini, pilihan tanggal, navigasi bulan, Today, dan tombol membuka aplikasi Calendar. Kalender ini tidak membaca agenda pribadi.
- **Dock bawaan macOS** diposisikan di bawah. Ukuran dan perilakunya bisa diatur melalui System Settings → Desktop & Dock.
- **CPU usage nyata** dari delta counter Mach, grafik riwayat 60 sampel, diperbarui setiap detik.
- **RAM aktif + wired + compressed** dari statistik VM macOS, diperbarui setiap dua detik. Definisinya berbeda dari keseluruhan Memory Used di Activity Monitor.
- **Notch jadwal sholat**: hover atau klik untuk membuka lokasi, lima waktu sholat, dan hitung mundur jadwal berikutnya. Mendukung pergantian hari dan jadwal Subuh besok.
- **Baterai dan Wi-Fi di notch**: baterai melalui IOKit; koneksi dan sinyal Wi-Fi melalui Network/CoreWLAN. Jika macOS menyembunyikan nama jaringan, notch tetap menampilkan status koneksinya.

Seret bagian kosong panel untuk memindahkannya. Posisi disimpan oleh AppKit. Ikon CPU di menu bar menyediakan kontrol panel, wallpaper, dan Quit.

Notch memakai [AlAdhan](https://aladhan.com/prayer-times-api) dengan metode **Kemenag RI (20)** dan [IPWho](https://ipwhois.io/documentation) untuk perkiraan kota berdasarkan IP publik. Keduanya bisa dipakai tanpa API key. Lokasi IP dapat meleset saat memakai VPN atau jaringan operator; jadwal bukan feed resmi harian Kemenag. Hasil disimpan lokal, diperbarui setiap enam jam dan saat pergantian hari; kegagalan jaringan dicoba ulang setelah 15 menit. Nama Wi-Fi dan data baterai tetap lokal.

## Build dan pasang

Memerlukan macOS 13+, Xcode Command Line Tools (Swift compiler), dan Python 3 untuk script pengaturan Dock. Runtime widget tidak memakai dependency pihak ketiga.

```sh
git clone https://github.com/kohryan/mac-mod.git
cd mac-mod
bash scripts/install.sh
open ~/Applications/MacMod.app
```

Installer membuat `~/Applications/MacMod.app` dari source Swift. Saat pertama dibuka, aplikasi menyimpan backup wallpaper lalu memasang `assets/wallpapers/gundam-hangar.png` sebagai wallpaper desktop. Startup selanjutnya tidak memaksa wallpaper ulang. Installer hanya memindahkan posisi Dock ke bawah; ukuran, auto-hide, dan daftar aplikasi mengikuti pengaturan pengguna. Aplikasi ditandatangani ad hoc untuk penggunaan lokal.

**Start at Login aktif saat pertama dibuka**, memakai ServiceManagement macOS. Widget muncul kembali setelah Mac dinyalakan dan pengguna login. Opsi ini bisa dimatikan dari menu MacMod di menu bar atau System Settings → General → Login Items. Jika macOS meminta persetujuan, aktifkan MacMod pada panel Login Items yang terbuka.

## Kembali ke sebelumnya

```sh
python3 scripts/desktop.py restore
```

Script mengembalikan wallpaper, mematikan Start at Login, menutup widget, dan memulihkan nilai Dock sebelum pemasangan, termasuk posisi semula. Backup lokal berada di `~/Library/Application Support/mac-mod/` dan tidak masuk Git. Wallpaper dinamis macOS yang tidak memberikan URL gambar memiliki salinan pengaturan asli, tetapi pemilihannya kembali perlu dilakukan lewat System Settings.

**Restore Previous Wallpaper** di menu bar hanya mengganti wallpaper; panel tetap bisa dipakai di atas wallpaper lain. **Quit MacMod** menutup panel tanpa mengubah wallpaper.

Versi awal Übersicht telah diganti. Script apply melepas symlink overlay lama buatan proyek ini. Übersicht yang sudah terpasang dibiarkan tetap terpasang; aplikasi native ini tidak menggunakannya.

## Verifikasi

```sh
mkdir -p output
xcrun swiftc -swift-version 5 Sources/Metrics.swift Sources/CalendarModel.swift tests/SensorsCheck.swift -o output/metrics-tests
output/metrics-tests
xcrun swiftc -swift-version 5 Sources/PrayerTimes.swift tests/PrayerCheck.swift -o output/prayer-tests
output/prayer-tests
# Opsional: verifikasi endpoint live
output/prayer-tests --live
python3 -m unittest discover -s tests -p 'test_*.py'
```

Pemeriksaan mencakup sensor, timer, kalender, migrasi/restore Dock, parsing API, timezone, pergantian jadwal setelah Isya, cache, serta respons API yang tidak valid.

## Aset

- Wallpaper: `assets/wallpapers/gundam-hangar.png` (1586 × 992 PNG).
- Dibuat menggunakan built-in ImageGen; [prompt lengkap](assets/wallpapers/PROMPT.md).
- Proyek fan-made, tidak berafiliasi dengan pemilik Gundam.

Implementasi memakai [NSPanel](https://developer.apple.com/documentation/appkit/nspanel), [Mach host statistics](https://developer.apple.com/documentation/kernel/1502863-host_statistics64), dan [IOKit power sources](https://developer.apple.com/documentation/iokit/1523867-iopsgetpowersourcedescription).
