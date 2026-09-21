# PRD — Sistem Pencatatan Kedai (Kasir Sederhana)

> Dokumen ini adalah sumber acuan utama proyek. Baca seluruh dokumen sebelum menulis kode. Jika ada hal yang belum jelas, pilih solusi paling sederhana dan catat asumsinya di `docs/ASSUMPTIONS.md`.

---

## 1. Ringkasan

Aplikasi pencatatan penjualan sederhana untuk kedai UMKM yang menjual bandrek dan makanan lain. Penjual mencatat pesanan (menu + jumlah), harga terhitung otomatis, lalu transaksi tersimpan di database. Ada mode admin untuk melihat riwayat dan mengelola menu.

**Prinsip utama:** simpel, cepat dipakai, mobile only, tetap bisa mencatat saat internet mati.

| Item | Keputusan |
|---|---|
| Platform | PWA (Flutter Web), tampilan khusus mobile |
| Database | Supabase (PostgreSQL) |
| Login | Tidak ada. Mode admin dibuka dengan PIN |
| Offline | Offline-first untuk pencatatan transaksi (simpan lokal dulu, sinkron ke Supabase) |
| Pembayaran | Hanya dicatat (Tunai / QRIS), tidak ada proses pembayaran sungguhan |
| Bahasa UI | Bahasa Indonesia |
| Zona waktu | Asia/Jakarta (WIB) |
| Mata uang | Rupiah, format `Rp 12.000` |

---

## 2. Tujuan dan Non-Tujuan

### Tujuan
1. Penjual bisa mencatat satu transaksi dalam waktu kurang dari 15 detik.
2. Semua transaksi tersimpan dan bisa dilihat kembali di riwayat.
3. Pemilik bisa mengubah menu dan harga sendiri tanpa bantuan developer.
4. Tetap bisa dipakai saat sinyal hilang.

### Non-Tujuan (di luar versi 1)
- Login multi-user / multi-role
- Proses pembayaran sungguhan (payment gateway)
- Cetak struk / printer
- Stok barang, diskon, pajak
- Multi-cabang
- Ekspor laporan (CSV/PDF)
- Tampilan desktop/tablet (cukup tampil rapi di tengah layar)

---

## 3. Pengguna

| Peran | Deskripsi | Akses |
|---|---|---|
| Penjual (kasir) | Pemilik/penjaga kedai, mencatat pesanan | Halaman Kasir, tanpa login |
| Admin | Orang yang sama, masuk mode admin dengan PIN | Riwayat, kelola menu, kelola kategori, ubah PIN |

---

## 4. Tech Stack

| Bagian | Pilihan |
|---|---|
| Framework | Flutter (Web, build PWA) |
| State management | Riverpod |
| Backend / DB | Supabase (`supabase_flutter`) |
| Penyimpanan lokal | Hive (`hive_flutter`, jalan di web lewat IndexedDB) |
| Deteksi koneksi | `connectivity_plus` |
| ID unik | `uuid` (ID transaksi dibuat di sisi client) |
| Format angka & tanggal | `intl` (locale `id_ID`) |
| Hosting | Hosting statis dengan HTTPS (Vercel / Netlify / Cloudflare Pages) |

Konfigurasi Supabase (URL dan anon key) disimpan lewat `--dart-define`, jangan ditulis langsung di kode.

---

## 5. Fitur

### 5.1 Halaman Kasir (halaman utama, tanpa login)

**Deskripsi:** tempat penjual memilih menu dan mencatat transaksi.

**Kebutuhan:**
- Tampilkan menu aktif dalam bentuk grid kartu, dikelompokkan lewat tab/chip kategori (ada opsi "Semua").
- Setiap kartu menampilkan nama menu dan harga.
- Tap kartu = tambah 1 ke pesanan.
- Bar ringkasan di bagian bawah layar: jumlah item dan total harga, dengan tombol **Lihat Pesanan**.
- Halaman/bottom sheet **Pesanan**:
  - Daftar item, tombol `+` dan `−` untuk jumlah, dan tombol hapus (×) di setiap item yang langsung terlihat (jumlah 0 = item juga terhapus).
  - Tombol **Kosongkan Pesanan** untuk mengulang dari awal.
  - Total harga otomatis.
  - Pilihan **Metode Bayar**: `Tunai` atau `QRIS` (wajib dipilih, default `Tunai`).
  - Tombol **Simpan Transaksi**.
- Setelah simpan: pesanan dikosongkan, tampil notifikasi singkat "Transaksi tersimpan", siap untuk pesanan berikutnya.
- Indikator status sinkron di header: `Online` / `Offline` dan jumlah transaksi belum terkirim (contoh: "3 belum terkirim"). Tap indikator = coba kirim ulang.
- Tombol/ikon kecil untuk masuk **Mode Admin**.

**Kriteria diterima:**
- Total harga selalu = jumlah (harga × qty) semua item.
- Tombol Simpan nonaktif jika pesanan kosong.
- Simpan transaksi berhasil dan tidak memblokir layar walaupun offline.
- Menu nonaktif tidak muncul di halaman kasir.

### 5.1b Transaksi Hari Ini (koreksi cepat, tanpa PIN)

**Deskripsi:** tempat penjual memperbaiki salah catat dengan cepat, tanpa masuk Mode Admin.

**Kebutuhan:**
- Navigasi bawah di mode kasir punya 2 tab: **Kasir** dan **Hari Ini**.
- Tab **Hari Ini** menampilkan transaksi hari ini (WIB), terbaru di atas. Tiap baris: jam, ringkasan item, total, metode bayar, status. Di atas daftar ada total penjualan hari ini (ringkas).
- **Pintasan cepat:** setelah transaksi disimpan, notifikasi "Transaksi tersimpan" punya tombol **Ubah** dan **Batalkan** yang tampil sekitar 10 detik.
- Tap transaksi di daftar = buka detail dengan dua aksi: **Edit** dan **Batalkan**.
- **Edit:** membuka layar seperti Pesanan yang sudah terisi. Bisa ubah jumlah, hapus item, tambah item, dan ganti metode bayar. Tombol **Simpan Perubahan**.
  - Item lama tetap memakai harga saat transaksi terjadi. Item baru memakai harga menu saat ini.
  - Total dihitung ulang. Kolom `diedit_at` diisi.
- **Batalkan:** dialog konfirmasi, lalu status jadi `batal`.
- **Batas tanpa PIN:** hanya transaksi hari ini (WIB) yang bisa diedit atau dibatalkan dari sini. Transaksi hari sebelumnya hanya lewat Mode Admin.
- **Transaksi belum terkirim (`pending`):** diedit atau dibatalkan langsung di antrean lokal, boleh saat offline. Jika dibatalkan, transaksi dibuang dari antrean dan tidak pernah terkirim.
- **Transaksi sudah terkirim:** edit/batal butuh internet. Jika offline, tampilkan "Butuh internet untuk mengubah transaksi yang sudah terkirim".
- Di riwayat admin, transaksi yang pernah diedit diberi label **Diedit** supaya pemilik bisa melihat.

**Kriteria diterima:**
- Dari transaksi tersimpan sampai batal selesai maksimal 3 tap (lewat pintasan di notifikasi).
- Edit tidak mengubah harga item lama.
- Total penjualan dan rekap per metode bayar ikut menyesuaikan setelah edit atau batal.
- Transaksi kemarin tidak muncul di tab Hari Ini.

### 5.2 Mode Admin (masuk dengan PIN)

**Gerbang PIN:**
- Input PIN 6 digit (numpad).
- PIN dikirim ke RPC `verifikasi_pin`. Jika benar, server mengembalikan **token sesi** (berlaku 12 jam). Token itu dipakai di semua fungsi admin. PIN tidak disimpan di app setelah diverifikasi.
- Pembatasan percobaan dihitung di **server**: PIN salah 5 kali berturut-turut = dikunci 30 detik. Tampilkan sisa waktu kunci dan sisa percobaan dari respons server, dan nonaktifkan numpad saat terkunci.
- Token sesi hanya disimpan di memori. Menutup app atau menekan **Keluar Admin** (memanggil `admin_keluar`) = kembali ke mode kasir.
- Jika fungsi admin mengembalikan error `SESI_TIDAK_VALID` (sesi habis), arahkan kembali ke gerbang PIN.

**Halaman admin (bottom navigation, 3 tab):**

**a. Riwayat**
- Daftar transaksi, terbaru di atas. Tiap baris: jam, ringkasan item, total, metode bayar (Tunai/QRIS), status.
- Transaksi berstatus `batal` ditampilkan dengan tanda jelas (coret / label "Batal") dan tidak dihitung ke total.
- Filter tanggal (default hari ini). Boleh pilih tanggal lain.
- Kartu ringkasan di atas: **Total penjualan** (hanya status `selesai`), jumlah transaksi, dan total **per metode bayar** (Tunai dan QRIS).
- Tap transaksi = detail (semua item, qty, harga satuan, subtotal, metode bayar, waktu).
- Di detail: tombol **Batalkan Transaksi** dengan dialog konfirmasi. Setelah dibatalkan, status jadi `batal`, `dibatalkan_at` terisi. Pembatalan tidak bisa diurungkan di versi 1.
- Di detail juga ada tombol **Edit** (cara kerjanya sama seperti di tab Hari Ini, lihat 5.1b) untuk transaksi **tanggal berapa pun**. Transaksi yang pernah diedit diberi label "Diedit".

**b. Menu**
- Daftar semua menu (aktif dan nonaktif), dikelompokkan per kategori.
- Tambah menu: nama, harga, kategori.
- Ubah menu: nama, harga, kategori.
- Toggle **aktif/nonaktif**. Menu tidak dihapus permanen supaya riwayat aman.
- Validasi: nama wajib, harga bilangan bulat ≥ 0.

**c. Pengaturan**
- **Kelola kategori:** tambah, ubah nama, atur urutan. Kategori hanya bisa dihapus jika tidak punya menu.
- **Ubah PIN:** input PIN lama dan PIN baru (6 digit).
- Tombol **Keluar Admin**.

**Kriteria diterima:**
- Mengubah harga menu **tidak** mengubah harga di transaksi lama.
- Total penjualan tidak menghitung transaksi `batal`.
- Semua fitur admin butuh internet. Jika offline, tampilkan pesan jelas "Butuh koneksi internet untuk membuka fitur ini".

### 5.3 Offline dan Sinkronisasi

**Aturan:**
1. Saat pertama kali online, app menyimpan **cache daftar menu dan kategori** ke Hive. Saat offline, halaman kasir memakai cache ini.
2. Cache menu diperbarui setiap app dibuka dalam keadaan online, dan setiap kali admin mengubah menu.
3. Saat **Simpan Transaksi**, transaksi ditulis dulu ke Hive (box `antrean_transaksi`) dengan status `pending`. ID transaksi (UUID) dibuat di client saat itu juga.
4. Sinkronisasi berjalan otomatis saat: app dibuka, koneksi kembali online, setelah tiap simpan, dan saat indikator di-tap.
5. Pengiriman memakai RPC `simpan_transaksi` yang **idempoten**: jika UUID yang sama dikirim dua kali, tidak boleh menghasilkan transaksi ganda.
6. Jika pengiriman gagal, transaksi tetap `pending` dan dicoba lagi (jeda bertahap, maksimal 60 detik antar percobaan). Tidak boleh ada transaksi hilang.
7. Setelah sukses, hapus dari antrean lokal.
8. Waktu transaksi (`created_at`) memakai waktu saat penjual menekan Simpan (bukan waktu sinkron).
9. Transaksi yang masih `pending` boleh diedit atau dibatalkan langsung di antrean lokal (lihat 5.1b). Edit/batal transaksi yang sudah terkirim butuh internet.

**Kriteria diterima:**
- Matikan internet, catat 3 transaksi, nyalakan internet: ketiganya muncul di riwayat admin tanpa duplikat.
- Tutup dan buka lagi app saat masih ada antrean: antrean tetap ada dan terkirim.

### 5.4 PWA

- `manifest.json`: nama app, nama singkat, `display: standalone`, `orientation: portrait`, warna tema, ikon 192px dan 512px (termasuk maskable).
- Service worker bawaan Flutter agar app bisa dibuka tanpa internet setelah pemuatan pertama.
- Bisa dipasang ke layar utama (Add to Home Screen).
- Layout mobile-first. Di layar lebar, konten dibatasi lebar maksimum 480px dan diletakkan di tengah.

---

## 6. Model Data (Supabase / PostgreSQL)

```sql
create extension if not exists pgcrypto;

create table kategori (
  id uuid primary key default gen_random_uuid(),
  nama text not null unique,
  urutan int not null default 0
);

create table menu (
  id uuid primary key default gen_random_uuid(),
  kategori_id uuid references kategori(id),
  nama text not null,
  harga int not null check (harga >= 0),
  aktif boolean not null default true,
  created_at timestamptz not null default now()
);

create table transaksi (
  id uuid primary key,  -- dibuat di client (idempoten)
  created_at timestamptz not null default now(),
  total int not null check (total >= 0),
  metode_bayar text not null default 'tunai'
    check (metode_bayar in ('tunai', 'qris')),
  status text not null default 'selesai'
    check (status in ('selesai', 'batal')),
  dibatalkan_at timestamptz,
  diedit_at timestamptz
);

create table transaksi_item (
  id uuid primary key default gen_random_uuid(),
  transaksi_id uuid not null references transaksi(id) on delete cascade,
  nama_menu text not null,      -- salinan nama saat transaksi
  harga_satuan int not null,    -- salinan harga saat transaksi
  qty int not null check (qty > 0),
  subtotal int not null
);

create table pengaturan (
  kunci text primary key,
  nilai text not null
);

create index idx_transaksi_created_at on transaksi (created_at desc);
create index idx_transaksi_item_transaksi on transaksi_item (transaksi_id);

-- Data awal
insert into kategori (nama, urutan) values ('Minuman', 1), ('Makanan', 2);

-- PIN awal: 123456 (WAJIB diganti setelah pertama kali masuk admin)
insert into pengaturan (kunci, nilai)
values ('pin_hash', crypt('123456', gen_salt('bf')));
```

**Catatan penting:** `nama_menu` dan `harga_satuan` pada `transaksi_item` adalah salinan saat transaksi terjadi, jadi perubahan menu tidak mengubah riwayat.

**Skema final sudah dibuat di `supabase/schema.sql` (sudah dijalankan di Supabase).** File itu adalah acuan resmi untuk tabel dan fungsi RPC. Jangan menulis ulang atau mengubahnya tanpa diminta. Selain tabel di atas, skema final punya dua tabel tambahan: `pin_status` (hitungan PIN salah dan waktu kunci) dan `sesi_admin` (token sesi admin).

---

## 7. Keamanan dan RPC

Karena tidak ada login, akses dibatasi lewat **Row Level Security (RLS)** dan **fungsi RPC** (`security definer`).

**Aturan RLS:**
- Aktifkan RLS di semua tabel.
- Role `anon` hanya boleh `SELECT` pada `kategori` dan `menu` (yang aktif).
- Role `anon` **tidak boleh** akses langsung ke `transaksi`, `transaksi_item`, dan `pengaturan`.
- Semua tulis/baca lain lewat fungsi RPC di bawah.

**Daftar RPC:**

Semua dipanggil dengan `supabase.rpc('nama_fungsi', params: {...})`. Kolom "Sesi admin" = butuh `p_token` (token dari `verifikasi_pin`).

| Fungsi | Parameter | Sesi admin | Keterangan |
|---|---|---|---|
| `simpan_transaksi` | `p_id uuid, p_created_at timestamptz, p_metode text, p_items jsonb` | Tidak | Simpan transaksi + item dalam satu proses. Total dihitung ulang di server. Jika `p_id` sudah ada, tidak error dan tidak duplikat (`duplikat: true`). |
| `kasir_riwayat_hari_ini` | — | Tidak | Transaksi hari ini (WIB) beserta item, untuk tab Hari Ini. |
| `kasir_edit_transaksi` | `p_id uuid, p_metode text, p_items jsonb` | Tidak | Ganti isi dan metode bayar. Hanya untuk transaksi `selesai` yang dibuat hari ini (WIB). |
| `kasir_batalkan_transaksi` | `p_id uuid` | Tidak | Ubah status jadi `batal`. Hanya untuk transaksi hari ini (WIB). |
| `verifikasi_pin` | `p_pin text` | — | Benar: `{ok: true, token}`. Salah: `{ok: false, terkunci, sisa_detik?, sisa_percobaan?}`. |
| `admin_keluar` | `p_token uuid` | Ya | Hapus sesi. |
| `admin_ubah_pin` | `p_token uuid, p_pin_lama text, p_pin_baru text` | Ya | PIN baru harus 6 digit angka. Sesi admin lain ikut keluar. |
| `admin_riwayat` | `p_token uuid, p_tanggal date` | Ya | Transaksi + item pada tanggal itu (WIB). Tanggal kosong = hari ini. |
| `admin_ringkasan` | `p_token uuid, p_tanggal date` | Ya | `{total_penjualan, jumlah_transaksi, jumlah_batal, tunai: {jumlah, total}, qris: {jumlah, total}}` (hanya `selesai` yang dihitung). |
| `admin_edit_transaksi` | `p_token uuid, p_id uuid, p_metode text, p_items jsonb` | Ya | Sama seperti `kasir_edit_transaksi`, tanpa batas tanggal. |
| `admin_batalkan_transaksi` | `p_token uuid, p_id uuid` | Ya | Sama seperti `kasir_batalkan_transaksi`, tanpa batas tanggal. |
| `admin_daftar_menu` | `p_token uuid` | Ya | Semua menu (aktif dan nonaktif) dengan nama kategori. |
| `admin_simpan_menu` | `p_token uuid, p_id uuid, p_nama text, p_harga int, p_kategori_id uuid, p_aktif boolean` | Ya | Tambah (`p_id` null) atau ubah menu. |
| `admin_simpan_kategori` | `p_token uuid, p_id uuid, p_nama text, p_urutan int` | Ya | Tambah (`p_id` null) atau ubah kategori. |
| `admin_hapus_kategori` | `p_token uuid, p_id uuid` | Ya | Hanya jika kategori tidak punya menu. |

**Format `p_items`:** array JSON, tiap elemen `{"nama_menu": "Bandrek", "harga_satuan": 8000, "qty": 2}`. Saat mengedit, item lama dikirim dengan `harga_satuan` aslinya, item baru dengan harga menu saat ini.

**Format respons:** fungsi mengembalikan JSON (`{ok: true, ...}`) atau array JSON untuk daftar. Jika gagal, Supabase mengembalikan error dengan pesan bahasa Indonesia yang bisa langsung ditampilkan ke pengguna (kecuali `SESI_TIDAK_VALID`, lihat 5.2).

**Catatan risiko yang diterima di versi 1:** siapa pun yang punya URL app bisa membuat transaksi lewat `simpan_transaksi`, serta mengedit atau membatalkan transaksi **hari ini** (karena kasir tanpa login). Batasannya hanya hari ini, dan setiap edit tercatat lewat `diedit_at` / `dibatalkan_at` sehingga terlihat di riwayat admin. Riwayat hari-hari sebelumnya dan pengelolaan menu tetap terlindungi PIN. Akses admin memakai token sesi dan pembatasan percobaan PIN di server. Untuk pengamanan lebih lanjut di versi berikutnya, pertimbangkan Supabase Auth.

---

## 8. Alur Utama

**Mencatat transaksi**
1. Buka app, tampil halaman Kasir.
2. Tap menu untuk menambah item, atur jumlah.
3. Buka Pesanan, pilih Tunai/QRIS.
4. Tap Simpan Transaksi.
5. Transaksi masuk antrean lokal, lalu terkirim ke Supabase saat online.

**Mengoreksi atau membatalkan transaksi hari ini (tanpa PIN)**
1. Setelah menyimpan, tap **Ubah** atau **Batalkan** di notifikasi. Atau buka tab **Hari Ini** dan pilih transaksi.
2. Edit item / metode bayar lalu **Simpan Perubahan**, atau tap **Batalkan** dan konfirmasi.
3. Total penjualan ikut menyesuaikan.

**Mengoreksi atau membatalkan transaksi hari sebelumnya**
1. Masuk Mode Admin (PIN).
2. Tab Riwayat, pilih tanggal dan transaksi.
3. Tap Edit atau Batalkan.

**Mengubah harga menu**
1. Masuk Mode Admin (PIN).
2. Tab Menu, pilih menu, ubah harga, simpan.
3. Harga baru berlaku untuk transaksi berikutnya. Riwayat lama tidak berubah.

---

## 9. Persyaratan Non-Fungsional

- **Performa:** halaman kasir tampil kurang dari 2 detik pada HP kelas menengah dengan koneksi 4G. Aksi tap menu terasa instan.
- **Ukuran sentuh:** semua tombol minimal 48×48 px, teks mudah dibaca di bawah sinar matahari (kontras tinggi).
- **Keandalan:** tidak ada transaksi yang hilang akibat koneksi putus atau app ditutup.
- **Error handling:** semua error tampil sebagai pesan bahasa Indonesia yang singkat dan jelas, tanpa teks teknis.
- **Kesederhanaan UI:** maksimal 3 tap dari membuka app sampai transaksi tersimpan (untuk 1 item).

---

## 10. Struktur Proyek yang Disarankan

```
lib/
├── main.dart
├── core/
│   ├── config.dart            # baca SUPABASE_URL & SUPABASE_ANON_KEY dari dart-define
│   ├── theme.dart
│   └── format.dart            # format rupiah & tanggal (id_ID)
├── data/
│   ├── models/                # Kategori, Menu, Transaksi, TransaksiItem
│   ├── supabase_service.dart  # semua pemanggilan Supabase & RPC
│   ├── local_store.dart       # Hive: cache menu, antrean transaksi
│   └── sync_service.dart      # logika kirim antrean, retry, cek koneksi
├── providers/                 # Riverpod providers
├── features/
│   ├── kasir/                 # halaman kasir, keranjang
│   └── admin/
│       ├── pin_gate.dart
│       ├── riwayat/
│       ├── menu/
│       └── pengaturan/
└── widgets/                   # komponen bersama
supabase/
└── schema.sql                 # skema final (sudah dijalankan di Supabase)
docs/
└── ASSUMPTIONS.md
```

---

## 11. Urutan Pengerjaan (Milestone)

1. **Setup:** proyek Flutter Web, dependency, konfigurasi `--dart-define`, tema, format rupiah.
2. **Database:** sudah selesai. Salin `schema.sql` yang disediakan ke `supabase/schema.sql` sebagai acuan kontrak API (tabel, RLS, semua RPC). Tidak perlu dibuat ulang. Buat model Dart dan `supabase_service.dart` yang cocok dengan RPC di bagian 7.
3. **Kasir (online dulu):** tampilkan menu, keranjang, simpan transaksi lewat RPC, tab **Hari Ini** dengan edit dan batal (5.1b).
4. **Offline-first:** cache menu, antrean Hive, sync service, indikator status.
5. **Mode Admin:** gerbang PIN, riwayat + ringkasan, batalkan transaksi.
6. **Kelola menu dan kategori**, ubah PIN.
7. **PWA:** manifest, ikon, uji instal di HP, uji offline.
8. **Pengujian dan deploy:** jalankan skenario di bagian 12, deploy ke hosting HTTPS.

---

## 12. Skenario Pengujian (Acceptance Test)

| # | Skenario | Hasil yang diharapkan |
|---|---|---|
| 1 | Catat 1 transaksi (2 bandrek + 1 roti bakar, QRIS) saat online | Muncul di riwayat dengan total dan metode QRIS yang benar |
| 2 | Matikan internet, catat 3 transaksi, nyalakan internet | Indikator "3 belum terkirim" lalu jadi 0; 3 transaksi di riwayat, tanpa duplikat |
| 3 | Ubah harga bandrek dari 8.000 ke 10.000 | Transaksi lama tetap 8.000; transaksi baru 10.000 |
| 4 | Nonaktifkan sebuah menu | Menu hilang dari halaman kasir, tetap ada di riwayat lama |
| 5 | Batalkan sebuah transaksi | Status `batal`, tidak dihitung di total penjualan |
| 6 | Masukkan PIN salah 5 kali | Server mengunci 30 detik, numpad nonaktif dan tampil sisa waktu |
| 7 | Ubah PIN, keluar admin, masuk dengan PIN baru | PIN lama ditolak, PIN baru diterima |
| 8 | Buka app dalam keadaan offline (setelah pernah dibuka online) | App terbuka, menu tampil dari cache, transaksi bisa dicatat |
| 9 | Kirim ulang transaksi dengan UUID yang sama | Tidak ada transaksi ganda |
| 10 | Pasang ke layar utama HP | App terbuka layar penuh, tanpa bilah browser |
| 11 | Salah tambah item di Pesanan, tap × pada item | Item langsung terhapus, total menyesuaikan |
| 12 | Simpan transaksi, lalu tap **Ubah** di notifikasi, ganti jumlah | Transaksi terupdate, total dihitung ulang, `diedit_at` terisi, harga item lama tidak berubah |
| 13 | Simpan transaksi, lalu tap **Batalkan** di notifikasi | Status `batal`, tidak dihitung di total penjualan |
| 14 | Edit transaksi yang masih `pending` saat offline | Perubahan tersimpan di antrean lokal, yang terkirim saat online adalah versi terbaru |
| 15 | Coba edit transaksi kemarin dari tab Hari Ini | Tidak tersedia; hanya bisa lewat Mode Admin |
| 16 | Buka riwayat admin untuk transaksi yang sudah diedit | Ada label "Diedit" |

---

## 13. Rencana Versi Berikutnya (opsional)

- Catatan per pesanan (misal "tanpa susu")
- Menu terlaris dan rekap mingguan/bulanan
- Ekspor riwayat ke CSV
- Pengamanan admin yang lebih kuat (Supabase Auth)
