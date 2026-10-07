# 🗄️ SQL Query untuk Fitur Catatan Pesanan

## 1️⃣ Tambah Kolom ke Tabel

```sql
-- Tambah kolom catatan ke tabel transaksi
ALTER TABLE transaksi ADD COLUMN IF NOT EXISTS catatan text;
```

**Penjelasan:**
- `catatan` adalah tipe `text` → dapat menyimpan catatan panjang tanpa batas
- Nullable (boleh kosong) → tidak wajib diisi pelanggan
- Default value: `NULL`

---

## 2️⃣ Query Dapatkan Transaksi dengan Catatan

```sql
-- Ambil semua transaksi hari ini beserta catatannya
SELECT 
  id, 
  created_at, 
  total, 
  nama_pelanggan, 
  status_bayar, 
  catatan,        -- ← Kolom baru
  metode_bayar, 
  status
FROM transaksi
WHERE DATE(created_at AT TIME ZONE 'Asia/Jakarta') = CURRENT_DATE AT TIME ZONE 'Asia/Jakarta'
ORDER BY created_at DESC;
```

---

## 3️⃣ Update Transaksi + Catatan

```sql
-- Update catatan pada transaksi tertentu
UPDATE transaksi
SET catatan = 'Telur dadar, sayur dikit, sambal jangan terlalu pedas'
WHERE id = 'uuid-transaksi-xxx';
```

---

## 4️⃣ Cari Transaksi berdasarkan Catatan

```sql
-- Cari transaksi yang memiliki catatan tertentu (case-insensitive)
SELECT *
FROM transaksi
WHERE LOWER(catatan) LIKE '%telur dadar%'
  OR LOWER(catatan) LIKE '%sambal pedas%'
ORDER BY created_at DESC;
```

---

## 5️⃣ Lihat Catatan yang Tidak Kosong

```sql
-- Lihat transaksi yang punya catatan
SELECT id, created_at, nama_pelanggan, catatan
FROM transaksi
WHERE catatan IS NOT NULL 
  AND catatan != ''
ORDER BY created_at DESC
LIMIT 20;
```

---

## 6️⃣ Backup Database (Opsional)

Jika ingin backup sebelum menambah kolom:

```sql
-- Create backup table (sebelum ALTER)
CREATE TABLE transaksi_backup_20261007 AS 
SELECT * FROM transaksi;
```

---

## 📝 Catatan Teknis

- **File Migration**: `supabase/migrations/20261007_add_catatan_kolom.sql`
  - Semua SQL function di database sudah diupdate di file ini
  - Include update untuk `_transaksi_json`, `_ganti_isi`, `simpan_transaksi`, `kasir_edit_transaksi`, `admin_edit_transaksi`

- **Backward Compatibility**: 
  - Kolom `catatan` adalah `NULL` untuk transaksi lama
  - Tidak akan break existing queries karena di-IF NOT EXISTS

- **Performance**:
  - Tipe `text` tidak perlu indexing untuk use case ini
  - Kalau nanti butuh cari catatan, bisa tambah index: `CREATE INDEX idx_transaksi_catatan ON transaksi USING GIN(to_tsvector('indonesian', catatan))`

