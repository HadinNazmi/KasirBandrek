# 📝 Fitur Catatan Pesanan (Notes Feature)

## 📋 Ringkasan Perubahan

Telah menambahkan fitur untuk mencatat catatan pesanan khusus dari pelanggan, misalnya:
- "Nasi goreng - telur dadar, sayur dikit"
- "Sambal jangan terlalu pedas"
- "Tambah gula sedikit"

## 🗄️ Database - SQL Query

### Tambah Kolom ke Tabel `transaksi`

```sql
ALTER TABLE transaksi ADD COLUMN IF NOT EXISTS catatan text;
```

**Penjelasan:**
- Tipe `text` memungkinkan catatan panjang tanpa batas
- `NULL` secara default (opsional, tidak wajib diisi)
- File migration: `supabase/migrations/20261007_add_catatan_kolom.sql`

### Update Functions di Database

Semua function di database telah diupdate untuk menangani parameter `catatan`:

1. **`simpan_transaksi`** - Menerima `p_catatan` sebagai parameter
2. **`kasir_edit_transaksi`** - Menerima `p_catatan` sebagai parameter
3. **`admin_edit_transaksi`** - Menerima `p_catatan` sebagai parameter
4. **`_ganti_isi`** - Helper function yang menangani catatan
5. **`_transaksi_json`** - Function yang mengembalikan data transaksi (sekarang include catatan)

---

## 📱 Frontend - Perubahan Files

### 1. **`lib/data/models/transaksi.dart`**
- Tambah field: `final String? catatan;`
- Update `fromJson()` untuk parse `catatan`
- Update `copyWith()` untuk handle `catatan`
- Update `toJson()` untuk serialize `catatan`

### 2. **`lib/features/kasir/widgets/cart_sheet.dart`**
- Tambah parameter di constructor: `initialCatatan`
- Tambah `TextEditingController _catatanController`
- Tambah UI: Text field untuk input catatan (3 lines)
  - Placeholder: "Misal: Nasi goreng - telur dadar, sayur dikit, sambal jangan terlalu pedas"
- Update `_simpan()` untuk extract dan pass `catatan`
- Pass `catatan` ke repository.simpan() dan svc.kasirEditTransaksi() / adminEditTransaksi()

### 3. **`lib/features/kasir/kasir_screen.dart`**
- Update `_ubahLast()` untuk pass `initialCatatan` saat edit

### 4. **`lib/data/transaksi_repository.dart`**
- Update `simpan()` method: tambah parameter `String? catatan`
- Update `editPending()` method: tambah parameter `String? catatan`
- Kedua method sekarang pass catatan ke model Transaksi

### 5. **`lib/data/supabase_service.dart`**
- Update `simpanTransaksi()`: tambah parameter `String? catatan`
- Update `kasirEditTransaksi()`: tambah parameter `String? catatan`
- Update `adminEditTransaksi()`: tambah parameter `String? catatan`
- Semua method sekarang pass `p_catatan` ke RPC call

### 6. **`lib/data/sync_service.dart`**
- Update sync() untuk pass `catatan` saat call `simpanTransaksi()`

---

## 🔄 Flow Penggunaan

### Saat Input Pesanan Baru:
1. Kasir menambahkan item ke keranjang
2. Kasir tap "Lihat Pesanan" → CartSheet terbuka
3. (Optional) Kasir input nama pelanggan
4. **[BARU]** Kasir input catatan pesanan (misal: "Telur dadar, sayur dikit")
5. Kasir pilih status pembayaran & metode bayar
6. Kasir tap "Simpan Transaksi"
7. Data termasuk catatan disimpan ke database

### Saat Edit Transaksi:
1. Kasir tap tombol "Ubah" di notifikasi atau di history
2. CartSheet terbuka dengan mode edit
3. **[BARU]** Catatan yang sudah tersimpan ditampilkan
4. Kasir bisa mengubah catatan
5. Tap "Simpan Perubahan"
6. Catatan yang diupdate disimpan

---

## 📊 Data yang Tersimpan

Contoh JSON transaksi dengan catatan:

```json
{
  "id": "uuid-xxx",
  "created_at": "2026-10-07T10:30:00.000Z",
  "total": 45000,
  "nama_pelanggan": "Budi",
  "status_bayar": "lunas",
  "catatan": "Nasi goreng - telur dadar, sayur dikit, sambal jangan terlalu pedas",
  "metode_bayar": "tunai",
  "status": "selesai",
  "items": [
    {
      "nama_menu": "Nasi Goreng",
      "harga_satuan": 30000,
      "qty": 1,
      "subtotal": 30000
    }
  ]
}
```

---

## ✅ Testing Checklist

- [ ] Simpan transaksi baru dengan catatan → Cek apakah catatan tersimpan di database
- [ ] Edit transaksi → Catatan bisa diubah/kosongkan
- [ ] Lihat history transaksi → Catatan ditampilkan (jika ada)
- [ ] Offline sync → Catatan tidak hilang saat sync
- [ ] Mode Admin → Admin bisa lihat dan edit catatan

---

## 🚀 Next Steps (Opsional)

- [ ] Tampilkan catatan di layar history/riwayat transaksi
- [ ] Tampilkan catatan di receipt/struk
- [ ] Add search/filter by catatan
- [ ] Export catatan ke laporan penjualan

