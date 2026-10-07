-- Migration Script to add nama_pelanggan and status_bayar

ALTER TABLE transaksi ADD COLUMN IF NOT EXISTS nama_pelanggan text;
ALTER TABLE transaksi ADD COLUMN IF NOT EXISTS status_bayar text not null default 'lunas' check (status_bayar in ('lunas', 'belum'));

-- Update _transaksi_json to include nama_pelanggan and status_bayar
CREATE OR REPLACE FUNCTION _transaksi_json(p_awal timestamptz, p_akhir timestamptz)
RETURNS jsonb
LANGUAGE sql STABLE SET search_path = public AS $$
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', t.id,
      'created_at', t.created_at,
      'total', t.total,
      'metode_bayar', t.metode_bayar,
      'status', t.status,
      'nama_pelanggan', t.nama_pelanggan,
      'status_bayar', t.status_bayar,
      'dibatalkan_at', t.dibatalkan_at,
      'diedit_at', t.diedit_at,
      'items', (
        SELECT coalesce(jsonb_agg(
          jsonb_build_object(
            'nama_menu', i.nama_menu,
            'harga_satuan', i.harga_satuan,
            'qty', i.qty,
            'subtotal', i.subtotal
          ) ORDER BY i.nama_menu
        ), '[]'::jsonb)
        FROM transaksi_item i WHERE i.transaksi_id = t.id
      )
    ) ORDER BY t.created_at desc
  ), '[]'::jsonb)
  FROM transaksi t
  WHERE t.created_at >= p_awal AND t.created_at < p_akhir
$$;

DROP FUNCTION IF EXISTS _ganti_isi(uuid, text, jsonb, boolean);
CREATE OR REPLACE FUNCTION _ganti_isi(
  p_id uuid, p_nama_pelanggan text, p_status_bayar text, p_metode text, p_items jsonb, p_hanya_hari_ini boolean
) RETURNS jsonb
LANGUAGE plpgsql SET search_path = public AS $$
DECLARE
  v_t transaksi%rowtype;
  v_total int;
BEGIN
  IF p_metode IS NULL OR p_metode NOT IN ('tunai', 'qris') THEN
    RAISE EXCEPTION 'Metode bayar tidak valid';
  END IF;
  IF p_status_bayar IS NULL OR p_status_bayar NOT IN ('lunas', 'belum') THEN
    RAISE EXCEPTION 'Status bayar tidak valid';
  END IF;
  
  v_total := _total_items(p_items);

  SELECT * INTO v_t FROM transaksi WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Transaksi tidak ditemukan'; END IF;
  IF v_t.status = 'batal' THEN
    RAISE EXCEPTION 'Transaksi sudah dibatalkan, tidak bisa diubah';
  END IF;
  IF p_hanya_hari_ini
     AND (v_t.created_at AT TIME ZONE 'Asia/Jakarta')::date <> _hari_ini() THEN
    RAISE EXCEPTION 'Transaksi hari sebelumnya hanya bisa diubah lewat Mode Admin';
  END IF;

  DELETE FROM transaksi_item WHERE transaksi_id = p_id;

  INSERT INTO transaksi_item (transaksi_id, nama_menu, harga_satuan, qty, subtotal)
  SELECT p_id, btrim(x.nama_menu), x.harga_satuan, x.qty, x.harga_satuan * x.qty
  FROM jsonb_to_recordset(p_items) AS x(nama_menu text, harga_satuan int, qty int);

  UPDATE transaksi
     SET total = v_total, nama_pelanggan = p_nama_pelanggan, status_bayar = p_status_bayar, metode_bayar = p_metode, diedit_at = now()
   WHERE id = p_id;

  RETURN jsonb_build_object('ok', true, 'total', v_total);
END $$;

DROP FUNCTION IF EXISTS simpan_transaksi(uuid, timestamptz, text, jsonb);
CREATE OR REPLACE FUNCTION simpan_transaksi(
  p_id uuid, p_created_at timestamptz, p_nama_pelanggan text, p_status_bayar text, p_metode text, p_items jsonb
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total int;
  v_waktu timestamptz;
  v_baris int;
BEGIN
  IF p_id IS NULL THEN RAISE EXCEPTION 'ID transaksi wajib diisi'; END IF;
  IF p_metode IS NULL OR p_metode NOT IN ('tunai', 'qris') THEN
    RAISE EXCEPTION 'Metode bayar tidak valid';
  END IF;
  IF p_status_bayar IS NULL OR p_status_bayar NOT IN ('lunas', 'belum') THEN
    RAISE EXCEPTION 'Status bayar tidak valid';
  END IF;

  v_total := _total_items(p_items);

  v_waktu := coalesce(p_created_at, now());
  IF v_waktu > now() + interval '5 minutes' THEN v_waktu := now(); END IF;

  INSERT INTO transaksi (id, created_at, total, nama_pelanggan, status_bayar, metode_bayar)
  VALUES (p_id, v_waktu, v_total, p_nama_pelanggan, p_status_bayar, p_metode)
  ON CONFLICT (id) DO NOTHING;

  GET DIAGNOSTICS v_baris = row_count;
  IF v_baris = 0 THEN
    RETURN jsonb_build_object('ok', true, 'duplikat', true);
  END IF;

  INSERT INTO transaksi_item (transaksi_id, nama_menu, harga_satuan, qty, subtotal)
  SELECT p_id, btrim(x.nama_menu), x.harga_satuan, x.qty, x.harga_satuan * x.qty
  FROM jsonb_to_recordset(p_items) AS x(nama_menu text, harga_satuan int, qty int);

  RETURN jsonb_build_object('ok', true, 'duplikat', false, 'total', v_total);
END $$;

DROP FUNCTION IF EXISTS kasir_edit_transaksi(uuid, text, jsonb);
CREATE OR REPLACE FUNCTION kasir_edit_transaksi(
  p_id uuid, p_nama_pelanggan text, p_status_bayar text, p_metode text, p_items jsonb
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN _ganti_isi(p_id, p_nama_pelanggan, p_status_bayar, p_metode, p_items, true);
END $$;

DROP FUNCTION IF EXISTS admin_edit_transaksi(uuid, uuid, text, jsonb);
CREATE OR REPLACE FUNCTION admin_edit_transaksi(
  p_token uuid, p_id uuid, p_nama_pelanggan text, p_status_bayar text, p_metode text, p_items jsonb
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM _cek_token(p_token);
  RETURN _ganti_isi(p_id, p_nama_pelanggan, p_status_bayar, p_metode, p_items, false);
END $$;

-- Perbarui admin_ringkasan untuk menangani status_bayar 'belum'
CREATE OR REPLACE FUNCTION admin_ringkasan(p_token uuid, p_tanggal date)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_hari date;
  v_hasil jsonb;
BEGIN
  PERFORM _cek_token(p_token);
  v_hari := coalesce(p_tanggal, _hari_ini());

  SELECT jsonb_build_object(
    'total_penjualan',  coalesce(sum(total) FILTER (WHERE status = 'selesai' AND status_bayar = 'lunas'), 0),
    'jumlah_transaksi', count(*) FILTER (WHERE status = 'selesai'),
    'jumlah_batal',     count(*) FILTER (WHERE status = 'batal'),
    'tunai', jsonb_build_object(
      'jumlah', count(*) FILTER (WHERE status = 'selesai' AND metode_bayar = 'tunai' AND status_bayar = 'lunas'),
      'total',  coalesce(sum(total) FILTER (WHERE status = 'selesai' AND metode_bayar = 'tunai' AND status_bayar = 'lunas'), 0)
    ),
    'qris', jsonb_build_object(
      'jumlah', count(*) FILTER (WHERE status = 'selesai' AND metode_bayar = 'qris' AND status_bayar = 'lunas'),
      'total',  coalesce(sum(total) FILTER (WHERE status = 'selesai' AND metode_bayar = 'qris' AND status_bayar = 'lunas'), 0)
    ),
    'belum_bayar', jsonb_build_object(
      'jumlah', count(*) FILTER (WHERE status = 'selesai' AND status_bayar = 'belum'),
      'total',  coalesce(sum(total) FILTER (WHERE status = 'selesai' AND status_bayar = 'belum'), 0)
    )
  ) INTO v_hasil
  FROM transaksi
  WHERE created_at >= v_hari::timestamp at time zone 'Asia/Jakarta'
    AND created_at <  (v_hari + 1)::timestamp at time zone 'Asia/Jakarta';

  RETURN v_hasil;
END $$;

-- Update grant permissions
GRANT EXECUTE ON FUNCTION
  simpan_transaksi(uuid, timestamptz, text, text, text, jsonb),
  kasir_edit_transaksi(uuid, text, text, text, jsonb),
  admin_edit_transaksi(uuid, uuid, text, text, text, jsonb)
TO anon;

NOTIFY pgrst, 'reload schema';

