# mac-mod

Desktop ricing untuk macOS: **clean minimal × dashboard pilot Gundam**.

Palet graphite dan cyan redup, tipografi tipis, schematic RX-78-2, jam WIB, serta telemetry Mac. Ruang tengah tetap lapang untuk bekerja. Ilustrasi SVG dibuat khusus untuk tema ini; proyek fan-made, tidak berafiliasi dengan pemilik Gundam.

## Isi tema

- Latar desktop dinamis dengan panel kokpit dan ilustrasi teknis RX-78-2.
- Jam dan tanggal Asia/Jakarta, callsign `KOHRYAN`.
- Persentase baterai, sumber daya, load average 1 menit, logical CPU cores, dan RAM terpasang.
- Dock auto-hide, ukuran 36, recent apps disembunyikan.
- Backup pengaturan Dock dan perintah restore. Wallpaper asli tidak diubah.

Load average adalah jumlah rata-rata pekerjaan yang menunggu atau memakai CPU, bukan persentase CPU. RAM yang ditampilkan adalah kapasitas terpasang. Data yang tidak tersedia ditampilkan sebagai `N/A`. Telemetry diperbarui setiap 10 detik dan tidak dikirim ke jaringan.

## Pasang

Memerlukan macOS 12+, [Homebrew](https://brew.sh/), dan Python 3. Node.js hanya diperlukan untuk menjalankan tes parser.

```sh
git clone https://github.com/kohryan/mac-mod.git
cd mac-mod
brew bundle --file=Brewfile
python3 scripts/desktop.py apply
```

Buka **Übersicht** dari Applications. Tema langsung muncul di desktop. Di menu Übersicht, gunakan **Open Widgets Folder** bila ingin melihat lokasi widget. Aktifkan **Open at login** di preferensi Übersicht bila ingin tema muncul setelah login.

Widget dipasang sebagai symlink ke repo ini. Simpan folder repo di lokasi tetap; perubahan file widget akan dimuat ulang oleh Übersicht. Script akan menolak menimpa widget atau backup yang sudah ada.

## Kembali ke tampilan sebelumnya

```sh
python3 scripts/desktop.py restore
```

Perintah ini melepas widget dan mengembalikan nilai Dock sebelum pemasangan, termasuk preferensi yang sebelumnya belum disetel. Backup lokal berada di `~/Library/Application Support/mac-mod/`; backup tidak masuk Git. Übersicht tetap terpasang dan bisa dihapus terpisah dengan `brew uninstall --cask ubersicht` bila tidak dipakai widget lain.

## Kustomisasi

Edit `config/uebersicht/mac-mod.widget/index.jsx`:

- `KOHRYAN`: callsign pilot.
- `#8ed4d9`: warna aksen cyan.
- `Asia/Jakarta`: zona waktu jam.
- `.left`, `.right`, `.blueprint`: posisi panel.
- `refreshFrequency`: interval telemetry dalam milidetik.

Übersicht mendeteksi perubahan otomatis. Pilih **Refresh All Widgets** di menu aplikasi bila perubahan belum terlihat. Tata letak ditujukan untuk desktop landscape dengan lebar setidaknya 1024 px.

## Tool mod macOS

| Bagian desktop | Tool | Status dalam repo |
| --- | --- | --- |
| Widget dan latar kokpit | [Übersicht](https://tracesof.net/uebersicht/) | Digunakan tema ini |
| Menu bar kustom | [SketchyBar](https://felixkratz.github.io/SketchyBar/setup) | Pilihan pengembangan |
| Window tiling | [AeroSpace](https://nikitabobko.github.io/AeroSpace/guide) | Pilihan pengembangan |

Übersicht menjalankan widget berbasis JavaScript/JSX di desktop; ini pendekatan yang dekat dengan konsep skin Rainmeter. Tema ini memakai perintah bawaan macOS `pmset`, `uptime`, dan `sysctl`. Menu bar dan window manager tetap memakai bawaan macOS pada preset awal ini.

## Verifikasi

```sh
npm test
python3 -m unittest discover -s tests -p 'test_*.py'
```

Tes mencakup pembacaan telemetry, nilai kosong, dan siklus apply/restore dengan preferensi tiruan. Tes tidak mengubah pengaturan desktop.

Referensi implementasi: [dokumentasi widget Übersicht](https://github.com/felixhageloh/uebersicht#writing-widgets), [katalog Homebrew Übersicht](https://formulae.brew.sh/cask/ubersicht).
