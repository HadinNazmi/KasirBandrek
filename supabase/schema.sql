-- =====================================================================
-- schema.sql — Sistem Pencatatan Kedai (Supabase / PostgreSQL)
--
-- Cara pakai: Supabase → SQL Editor → New query → tempel semua → Run.
-- Aman dijalankan ulang (tidak menghapus data yang sudah ada).
-- PIN awal: 123456  (WAJIB diganti lewat Ubah PIN di Mode Admin)
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;


-- =====================================================================
-- 1. TABEL
-- =====================================================================

create table if not exists kategori (
  id     uuid primary key default gen_random_uuid(),
  nama   text not null unique,
  urutan int  not null default 0
);

create table if not exists menu (
  id          uuid primary key default gen_random_uuid(),
  kategori_id uuid references kategori(id),
  nama        text not null,
  harga       int  not null check (harga >= 0),
  aktif       boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists transaksi (
  id            uuid primary key,              -- dibuat di client (idempoten)
  created_at    timestamptz not null default now(),
  total         int  not null check (total >= 0),
  metode_bayar  text not null default 'tunai'
                check (metode_bayar in ('tunai', 'qris')),
  status        text not null default 'selesai'
                check (status in ('selesai', 'batal')),
  dibatalkan_at timestamptz,
  diedit_at     timestamptz
);

create table if not exists transaksi_item (
  id           uuid primary key default gen_random_uuid(),
  transaksi_id uuid not null references transaksi(id) on delete cascade,
  nama_menu    text not null,   -- salinan nama saat transaksi
  harga_satuan int  not null,   -- salinan harga saat transaksi
  qty          int  not null check (qty > 0),
  subtotal     int  not null
);

create table if not exists pengaturan (
  kunci text primary key,
  nilai text not null
);

-- Status percobaan PIN (satu baris saja)
create table if not exists pin_status (
  id           int primary key default 1 check (id = 1),
  gagal        int not null default 0,
  kunci_sampai timestamptz
);

-- Sesi admin (token dibuat setelah PIN benar, berlaku 12 jam)
create table if not exists sesi_admin (
  token         uuid primary key default gen_random_uuid(),
  berlaku_sampai timestamptz not null
);

create index if not exists idx_transaksi_created_at on transaksi (created_at desc);
create index if not exists idx_transaksi_item_transaksi on transaksi_item (transaksi_id);
create index if not exists idx_menu_kategori on menu (kategori_id);


-- =====================================================================
-- 2. DATA AWAL
-- =====================================================================

insert into kategori (nama, urutan)
values ('Minuman', 1), ('Makanan', 2)
on conflict (nama) do nothing;

insert into pengaturan (kunci, nilai)
values ('pin_hash', extensions.crypt('123456', extensions.gen_salt('bf')))
on conflict (kunci) do nothing;

insert into pin_status (id) values (1) on conflict (id) do nothing;

-- Contoh menu (hapus tanda komentar kalau mau dipakai untuk uji coba):
-- insert into menu (kategori_id, nama, harga)
-- select k.id, v.nama, v.harga
-- from (values ('Minuman', 'Bandrek', 8000), ('Makanan', 'Roti Bakar', 12000)) as v(kat, nama, harga)
-- join kategori k on k.nama = v.kat;


-- =====================================================================
-- 3. ROW LEVEL SECURITY
-- =====================================================================

alter table kategori       enable row level security;
alter table menu           enable row level security;
alter table transaksi      enable row level security;
alter table transaksi_item enable row level security;
alter table pengaturan     enable row level security;
alter table pin_status     enable row level security;
alter table sesi_admin     enable row level security;

-- Anon hanya boleh membaca kategori dan menu aktif (untuk halaman kasir).
drop policy if exists "anon baca kategori" on kategori;
create policy "anon baca kategori" on kategori
  for select to anon using (true);

drop policy if exists "anon baca menu aktif" on menu;
create policy "anon baca menu aktif" on menu
  for select to anon using (aktif = true);

-- Tabel lain tanpa policy = tidak bisa diakses langsung oleh anon.
-- Semua akses lain lewat fungsi RPC di bawah.


-- =====================================================================
-- 4. FUNGSI INTERNAL (tidak bisa dipanggil dari app)
-- =====================================================================

create or replace function _hari_ini() returns date
language sql stable set search_path = public as $$
  select (now() at time zone 'Asia/Jakarta')::date
$$;

-- Cek token sesi admin; error 'SESI_TIDAK_VALID' jika tidak valid/kedaluwarsa.
create or replace function _cek_token(p_token uuid) returns void
language plpgsql set search_path = public as $$
begin
  if p_token is null or not exists (
    select 1 from sesi_admin where token = p_token and berlaku_sampai > now()
  ) then
    raise exception 'SESI_TIDAK_VALID';
  end if;
end $$;

-- Validasi daftar item, kembalikan total (dihitung ulang di server).
-- Format item: [{"nama_menu": "...", "harga_satuan": 8000, "qty": 2}, ...]
create or replace function _total_items(p_items jsonb) returns int
language plpgsql set search_path = public as $$
declare
  v_n int;
  v_total bigint;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Daftar item tidak valid';
  end if;

  v_n := jsonb_array_length(p_items);
  if v_n = 0 then raise exception 'Pesanan masih kosong'; end if;
  if v_n > 100 then raise exception 'Jumlah item terlalu banyak'; end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_items) as x(nama_menu text, harga_satuan int, qty int)
    where x.nama_menu is null or btrim(x.nama_menu) = ''
       or x.harga_satuan is null or x.harga_satuan < 0 or x.harga_satuan > 1000000
       or x.qty is null or x.qty < 1 or x.qty > 999
  ) then
    raise exception 'Data item tidak valid';
  end if;

  select sum(x.harga_satuan::bigint * x.qty) into v_total
  from jsonb_to_recordset(p_items) as x(nama_menu text, harga_satuan int, qty int);

  if v_total > 2000000000 then raise exception 'Total terlalu besar'; end if;
  return v_total::int;
end $$;

-- Ambil daftar transaksi + item dalam rentang waktu, terbaru di atas.
create or replace function _transaksi_json(p_awal timestamptz, p_akhir timestamptz)
returns jsonb
language sql stable set search_path = public as $$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', t.id,
      'created_at', t.created_at,
      'total', t.total,
      'metode_bayar', t.metode_bayar,
      'status', t.status,
      'dibatalkan_at', t.dibatalkan_at,
      'diedit_at', t.diedit_at,
      'items', (
        select coalesce(jsonb_agg(
          jsonb_build_object(
            'nama_menu', i.nama_menu,
            'harga_satuan', i.harga_satuan,
            'qty', i.qty,
            'subtotal', i.subtotal
          ) order by i.nama_menu
        ), '[]'::jsonb)
        from transaksi_item i where i.transaksi_id = t.id
      )
    ) order by t.created_at desc
  ), '[]'::jsonb)
  from transaksi t
  where t.created_at >= p_awal and t.created_at < p_akhir
$$;

-- Ganti isi transaksi (dipakai kasir dan admin).
create or replace function _ganti_isi(
  p_id uuid, p_metode text, p_items jsonb, p_hanya_hari_ini boolean
) returns jsonb
language plpgsql set search_path = public as $$
declare
  v_t transaksi%rowtype;
  v_total int;
begin
  if p_metode is null or p_metode not in ('tunai', 'qris') then
    raise exception 'Metode bayar tidak valid';
  end if;
  v_total := _total_items(p_items);

  select * into v_t from transaksi where id = p_id for update;
  if not found then raise exception 'Transaksi tidak ditemukan'; end if;
  if v_t.status = 'batal' then
    raise exception 'Transaksi sudah dibatalkan, tidak bisa diubah';
  end if;
  if p_hanya_hari_ini
     and (v_t.created_at at time zone 'Asia/Jakarta')::date <> _hari_ini() then
    raise exception 'Transaksi hari sebelumnya hanya bisa diubah lewat Mode Admin';
  end if;

  delete from transaksi_item where transaksi_id = p_id;

  insert into transaksi_item (transaksi_id, nama_menu, harga_satuan, qty, subtotal)
  select p_id, btrim(x.nama_menu), x.harga_satuan, x.qty, x.harga_satuan * x.qty
  from jsonb_to_recordset(p_items) as x(nama_menu text, harga_satuan int, qty int);

  update transaksi
     set total = v_total, metode_bayar = p_metode, diedit_at = now()
   where id = p_id;

  return jsonb_build_object('ok', true, 'total', v_total);
end $$;

-- Batalkan transaksi (dipakai kasir dan admin).
create or replace function _batalkan(p_id uuid, p_hanya_hari_ini boolean)
returns jsonb
language plpgsql set search_path = public as $$
declare
  v_t transaksi%rowtype;
begin
  select * into v_t from transaksi where id = p_id for update;
  if not found then raise exception 'Transaksi tidak ditemukan'; end if;
  if v_t.status = 'batal' then
    return jsonb_build_object('ok', true);   -- sudah batal, anggap berhasil
  end if;
  if p_hanya_hari_ini
     and (v_t.created_at at time zone 'Asia/Jakarta')::date <> _hari_ini() then
    raise exception 'Transaksi hari sebelumnya hanya bisa dibatalkan lewat Mode Admin';
  end if;

  update transaksi set status = 'batal', dibatalkan_at = now() where id = p_id;
  return jsonb_build_object('ok', true);
end $$;


-- =====================================================================
-- 5. FUNGSI RPC UNTUK KASIR (tanpa PIN)
-- =====================================================================

-- Simpan transaksi baru. Idempoten: UUID yang sama tidak menghasilkan data ganda.
create or replace function simpan_transaksi(
  p_id uuid, p_created_at timestamptz, p_metode text, p_items jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_total int;
  v_waktu timestamptz;
  v_baris int;
begin
  if p_id is null then raise exception 'ID transaksi wajib diisi'; end if;
  if p_metode is null or p_metode not in ('tunai', 'qris') then
    raise exception 'Metode bayar tidak valid';
  end if;
  v_total := _total_items(p_items);

  v_waktu := coalesce(p_created_at, now());
  if v_waktu > now() + interval '5 minutes' then v_waktu := now(); end if;

  insert into transaksi (id, created_at, total, metode_bayar)
  values (p_id, v_waktu, v_total, p_metode)
  on conflict (id) do nothing;

  get diagnostics v_baris = row_count;
  if v_baris = 0 then
    return jsonb_build_object('ok', true, 'duplikat', true);
  end if;

  insert into transaksi_item (transaksi_id, nama_menu, harga_satuan, qty, subtotal)
  select p_id, btrim(x.nama_menu), x.harga_satuan, x.qty, x.harga_satuan * x.qty
  from jsonb_to_recordset(p_items) as x(nama_menu text, harga_satuan int, qty int);

  return jsonb_build_object('ok', true, 'duplikat', false, 'total', v_total);
end $$;

-- Daftar transaksi hari ini (WIB) untuk tab "Hari Ini".
create or replace function kasir_riwayat_hari_ini() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_hari date := _hari_ini();
begin
  return _transaksi_json(
    v_hari::timestamp at time zone 'Asia/Jakarta',
    (v_hari + 1)::timestamp at time zone 'Asia/Jakarta'
  );
end $$;

-- Edit transaksi hari ini tanpa PIN.
create or replace function kasir_edit_transaksi(
  p_id uuid, p_metode text, p_items jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  return _ganti_isi(p_id, p_metode, p_items, true);
end $$;

-- Batalkan transaksi hari ini tanpa PIN.
create or replace function kasir_batalkan_transaksi(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  return _batalkan(p_id, true);
end $$;


-- =====================================================================
-- 6. FUNGSI RPC ADMIN (PIN → token sesi)
-- =====================================================================

-- Verifikasi PIN. Jika benar, kembalikan token sesi (dipakai di semua fungsi admin).
-- Salah 5 kali berturut-turut = dikunci 30 detik (dihitung di server).
-- Hasil: {ok: true, token: "..."}  atau
--        {ok: false, terkunci: bool, sisa_detik?: int, sisa_percobaan?: int}
create or replace function verifikasi_pin(p_pin text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_status pin_status%rowtype;
  v_hash text;
  v_token uuid;
begin
  select * into v_status from pin_status where id = 1 for update;

  if v_status.kunci_sampai is not null and v_status.kunci_sampai > now() then
    return jsonb_build_object(
      'ok', false, 'terkunci', true,
      'sisa_detik', ceil(extract(epoch from (v_status.kunci_sampai - now())))::int
    );
  end if;

  select nilai into v_hash from pengaturan where kunci = 'pin_hash';

  if p_pin is not null and v_hash is not null
     and v_hash = extensions.crypt(p_pin, v_hash) then
    update pin_status set gagal = 0, kunci_sampai = null where id = 1;
    delete from sesi_admin where berlaku_sampai < now();
    insert into sesi_admin (berlaku_sampai)
    values (now() + interval '12 hours')
    returning token into v_token;
    return jsonb_build_object('ok', true, 'token', v_token);
  end if;

  if v_status.gagal + 1 >= 5 then
    update pin_status
       set gagal = 0, kunci_sampai = now() + interval '30 seconds'
     where id = 1;
    return jsonb_build_object('ok', false, 'terkunci', true, 'sisa_detik', 30);
  end if;

  update pin_status set gagal = gagal + 1 where id = 1;
  return jsonb_build_object(
    'ok', false, 'terkunci', false,
    'sisa_percobaan', 5 - (v_status.gagal + 1)
  );
end $$;

-- Keluar dari mode admin (hapus sesi).
create or replace function admin_keluar(p_token uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  delete from sesi_admin where token = p_token;
  return jsonb_build_object('ok', true);
end $$;

-- Ubah PIN. PIN baru harus 6 digit angka.
create or replace function admin_ubah_pin(
  p_token uuid, p_pin_lama text, p_pin_baru text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_hash text;
begin
  perform _cek_token(p_token);

  select nilai into v_hash from pengaturan where kunci = 'pin_hash';
  if v_hash is null or p_pin_lama is null
     or v_hash <> extensions.crypt(p_pin_lama, v_hash) then
    raise exception 'PIN lama salah';
  end if;

  if p_pin_baru is null or p_pin_baru !~ '^[0-9]{6}$' then
    raise exception 'PIN baru harus 6 digit angka';
  end if;

  update pengaturan
     set nilai = extensions.crypt(p_pin_baru, extensions.gen_salt('bf'))
   where kunci = 'pin_hash';

  delete from sesi_admin where token <> p_token;   -- sesi lain ikut keluar
  return jsonb_build_object('ok', true);
end $$;

-- Riwayat transaksi pada satu tanggal (WIB). Kosongkan tanggal = hari ini.
create or replace function admin_riwayat(p_token uuid, p_tanggal date)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_hari date;
begin
  perform _cek_token(p_token);
  v_hari := coalesce(p_tanggal, _hari_ini());
  return _transaksi_json(
    v_hari::timestamp at time zone 'Asia/Jakarta',
    (v_hari + 1)::timestamp at time zone 'Asia/Jakarta'
  );
end $$;

-- Ringkasan satu tanggal (WIB): hanya transaksi berstatus 'selesai' yang dihitung.
create or replace function admin_ringkasan(p_token uuid, p_tanggal date)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_hari date;
  v_hasil jsonb;
begin
  perform _cek_token(p_token);
  v_hari := coalesce(p_tanggal, _hari_ini());

  select jsonb_build_object(
    'total_penjualan',  coalesce(sum(total) filter (where status = 'selesai'), 0),
    'jumlah_transaksi', count(*) filter (where status = 'selesai'),
    'jumlah_batal',     count(*) filter (where status = 'batal'),
    'tunai', jsonb_build_object(
      'jumlah', count(*) filter (where status = 'selesai' and metode_bayar = 'tunai'),
      'total',  coalesce(sum(total) filter (where status = 'selesai' and metode_bayar = 'tunai'), 0)
    ),
    'qris', jsonb_build_object(
      'jumlah', count(*) filter (where status = 'selesai' and metode_bayar = 'qris'),
      'total',  coalesce(sum(total) filter (where status = 'selesai' and metode_bayar = 'qris'), 0)
    )
  ) into v_hasil
  from transaksi
  where created_at >= v_hari::timestamp at time zone 'Asia/Jakarta'
    and created_at <  (v_hari + 1)::timestamp at time zone 'Asia/Jakarta';

  return v_hasil;
end $$;

-- Edit transaksi tanggal berapa pun.
create or replace function admin_edit_transaksi(
  p_token uuid, p_id uuid, p_metode text, p_items jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _cek_token(p_token);
  return _ganti_isi(p_id, p_metode, p_items, false);
end $$;

-- Batalkan transaksi tanggal berapa pun.
create or replace function admin_batalkan_transaksi(p_token uuid, p_id uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _cek_token(p_token);
  return _batalkan(p_id, false);
end $$;

-- Semua menu (aktif dan nonaktif) beserta nama kategorinya.
create or replace function admin_daftar_menu(p_token uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _cek_token(p_token);
  return (
    select coalesce(jsonb_agg(
      jsonb_build_object(
        'id', m.id,
        'nama', m.nama,
        'harga', m.harga,
        'aktif', m.aktif,
        'kategori_id', m.kategori_id,
        'kategori_nama', k.nama
      ) order by k.urutan nulls last, k.nama, m.nama
    ), '[]'::jsonb)
    from menu m
    left join kategori k on k.id = m.kategori_id
  );
end $$;

-- Tambah menu (p_id null) atau ubah menu (p_id diisi).
create or replace function admin_simpan_menu(
  p_token uuid, p_id uuid, p_nama text, p_harga int,
  p_kategori_id uuid, p_aktif boolean
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid := p_id;
  v_nama text := btrim(coalesce(p_nama, ''));
begin
  perform _cek_token(p_token);

  if v_nama = '' then raise exception 'Nama menu wajib diisi'; end if;
  if p_harga is null or p_harga < 0 or p_harga > 1000000 then
    raise exception 'Harga tidak valid (0 sampai 1.000.000)';
  end if;
  if p_kategori_id is null
     or not exists (select 1 from kategori where id = p_kategori_id) then
    raise exception 'Kategori tidak ditemukan';
  end if;

  if p_id is null then
    insert into menu (kategori_id, nama, harga, aktif)
    values (p_kategori_id, v_nama, p_harga, coalesce(p_aktif, true))
    returning id into v_id;
  else
    update menu
       set kategori_id = p_kategori_id, nama = v_nama, harga = p_harga,
           aktif = coalesce(p_aktif, aktif)
     where id = p_id;
    if not found then raise exception 'Menu tidak ditemukan'; end if;
  end if;

  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

-- Tambah kategori (p_id null) atau ubah kategori (p_id diisi).
create or replace function admin_simpan_kategori(
  p_token uuid, p_id uuid, p_nama text, p_urutan int
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid := p_id;
  v_nama text := btrim(coalesce(p_nama, ''));
begin
  perform _cek_token(p_token);
  if v_nama = '' then raise exception 'Nama kategori wajib diisi'; end if;

  begin
    if p_id is null then
      insert into kategori (nama, urutan)
      values (v_nama, coalesce(p_urutan, 0))
      returning id into v_id;
    else
      update kategori
         set nama = v_nama, urutan = coalesce(p_urutan, urutan)
       where id = p_id;
      if not found then raise exception 'Kategori tidak ditemukan'; end if;
    end if;
  exception when unique_violation then
    raise exception 'Nama kategori sudah ada';
  end;

  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

-- Hapus kategori (hanya jika tidak punya menu).
create or replace function admin_hapus_kategori(p_token uuid, p_id uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _cek_token(p_token);
  if exists (select 1 from menu where kategori_id = p_id) then
    raise exception 'Kategori masih punya menu, pindahkan atau nonaktifkan menunya dulu';
  end if;
  delete from kategori where id = p_id;
  if not found then raise exception 'Kategori tidak ditemukan'; end if;
  return jsonb_build_object('ok', true);
end $$;


-- =====================================================================
-- 7. HAK AKSES
-- =====================================================================

-- Anon tidak boleh akses langsung ke tabel kecuali baca kategori & menu.
revoke all on all tables in schema public from anon, authenticated;
grant select on kategori, menu to anon;

-- Semua fungsi dikunci dulu, lalu buka hanya yang boleh dipanggil dari app.
revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function
  simpan_transaksi(uuid, timestamptz, text, jsonb),
  kasir_riwayat_hari_ini(),
  kasir_edit_transaksi(uuid, text, jsonb),
  kasir_batalkan_transaksi(uuid),
  verifikasi_pin(text),
  admin_keluar(uuid),
  admin_ubah_pin(uuid, text, text),
  admin_riwayat(uuid, date),
  admin_ringkasan(uuid, date),
  admin_edit_transaksi(uuid, uuid, text, jsonb),
  admin_batalkan_transaksi(uuid, uuid),
  admin_daftar_menu(uuid),
  admin_simpan_menu(uuid, uuid, text, int, uuid, boolean),
  admin_simpan_kategori(uuid, uuid, text, int),
  admin_hapus_kategori(uuid, uuid)
to anon;

-- Muat ulang cache API Supabase supaya fungsi baru langsung terbaca.
notify pgrst, 'reload schema';


-- =====================================================================
-- 8. TES CEPAT (opsional, jalankan satu per satu setelah schema berhasil)
-- =====================================================================
-- select verifikasi_pin('123456');   -- harus {"ok": true, "token": "..."}
-- select simpan_transaksi(
--   gen_random_uuid(), now(), 'qris',
--   '[{"nama_menu":"Bandrek","harga_satuan":8000,"qty":2}]'::jsonb
-- );                                 -- harus {"ok": true, "duplikat": false, "total": 16000}
-- select kasir_riwayat_hari_ini();   -- harus berisi transaksi di atas
