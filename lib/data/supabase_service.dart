import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/format.dart';
import 'models/admin_menu_item.dart';
import 'models/admin_ringkasan.dart';
import 'models/laporan_penjualan.dart';
import 'models/log_aktivitas_item.dart';
import 'models/transaksi.dart';
import 'models/transaksi_item.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // =====================================================================
  // KASIR RPC (Tanpa PIN)
  // =====================================================================

  Future<Map<String, dynamic>> simpanTransaksi({
    required String id,
    required DateTime createdAt,
    required String metode,
    required List<TransaksiItem> items,
  }) async {
    final response = await _client.rpc('simpan_transaksi', params: {
      'p_id': id,
      'p_created_at': createdAt.toIso8601String(),
      'p_metode': metode,
      'p_items': items.map((e) => e.toJson()).toList(),
    });
    return response as Map<String, dynamic>;
  }

  Future<List<Transaksi>> kasirRiwayatHariIni() async {
    final response = await _client.rpc('kasir_riwayat_hari_ini');
    final List list = response as List;
    return list.map((e) => Transaksi.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> kasirEditTransaksi({
    required String id,
    required String metode,
    required List<TransaksiItem> items,
  }) async {
    final response = await _client.rpc('kasir_edit_transaksi', params: {
      'p_id': id,
      'p_metode': metode,
      'p_items': items.map((e) => e.toJson()).toList(),
    });
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> kasirBatalkanTransaksi({required String id}) async {
    final response = await _client.rpc('kasir_batalkan_transaksi', params: {
      'p_id': id,
    });
    return response as Map<String, dynamic>;
  }

  // =====================================================================
  // ADMIN RPC (Dengan PIN/Token)
  // =====================================================================

  Future<Map<String, dynamic>> verifikasiPin(String pin) async {
    final response = await _client.rpc('verifikasi_pin', params: {
      'p_pin': pin,
    });
    return response as Map<String, dynamic>;
  }

  Future<void> adminKeluar(String token) async {
    await _client.rpc('admin_keluar', params: {
      'p_token': token,
    });
  }

  Future<void> adminUbahPin({
    required String token,
    required String pinLama,
    required String pinBaru,
  }) async {
    await _client.rpc('admin_ubah_pin', params: {
      'p_token': token,
      'p_pin_lama': pinLama,
      'p_pin_baru': pinBaru,
    });
  }

  Future<List<Transaksi>> adminRiwayat(String token, {String? tanggal}) async {
    final response = await _client.rpc('admin_riwayat', params: {
      'p_token': token,
      'p_tanggal': tanggal,
    });
    final List list = response as List;
    return list.map((e) => Transaksi.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminRingkasan> adminRingkasan(String token, {String? tanggal}) async {
    final response = await _client.rpc('admin_ringkasan', params: {
      'p_token': token,
      'p_tanggal': tanggal,
    });
    return AdminRingkasan.fromJson(response as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> adminEditTransaksi({
    required String token,
    required String id,
    required String metode,
    required List<TransaksiItem> items,
  }) async {
    final response = await _client.rpc('admin_edit_transaksi', params: {
      'p_token': token,
      'p_id': id,
      'p_metode': metode,
      'p_items': items.map((e) => e.toJson()).toList(),
    });
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminBatalkanTransaksi({
    required String token,
    required String id,
  }) async {
    final response = await _client.rpc('admin_batalkan_transaksi', params: {
      'p_token': token,
      'p_id': id,
    });
    return response as Map<String, dynamic>;
  }

  Future<List<AdminMenuItem>> adminDaftarMenu(String token) async {
    final response = await _client.rpc('admin_daftar_menu', params: {
      'p_token': token,
    });
    final List list = response as List;
    return list.map((e) => AdminMenuItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> adminSimpanMenu({
    required String token,
    String? id,
    required String nama,
    required int harga,
    required String kategoriId,
    required bool aktif,
    String? fotoUrl,
  }) async {
    final response = await _client.rpc('admin_simpan_menu', params: {
      'p_token': token,
      'p_id': id,
      'p_nama': nama,
      'p_harga': harga,
      'p_kategori_id': kategoriId,
      'p_aktif': aktif,
      'p_foto_url': fotoUrl,
    });
    return response as Map<String, dynamic>;
  }

  Future<void> adminHapusMenu({
    required String token,
    required String id,
  }) async {
    await _client.rpc('admin_hapus_menu', params: {
      'p_token': token,
      'p_id': id,
    });
  }

  Future<String> uploadFotoMenu({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final cleanExt = fileExtension.replaceAll('.', '').toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}.$cleanExt';
    final path = 'menus/$fileName';
    final contentType = cleanExt == 'png'
        ? 'image/png'
        : cleanExt == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    await _client.storage.from('menu-foto').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: true,
      ),
    );
    return _client.storage.from('menu-foto').getPublicUrl(path);
  }

  Future<Map<String, dynamic>> adminSimpanKategori({
    required String token,
    String? id,
    required String nama,
    required int urutan,
  }) async {
    final response = await _client.rpc('admin_simpan_kategori', params: {
      'p_token': token,
      'p_id': id,
      'p_nama': nama,
      'p_urutan': urutan,
    });
    return response as Map<String, dynamic>;
  }

  Future<void> adminHapusKategori({
    required String token,
    required String id,
  }) async {
    await _client.rpc('admin_hapus_kategori', params: {
      'p_token': token,
      'p_id': id,
    });
  }

  // =====================================================================
  // LAPORAN & LOG AKTIVITAS (MEETING 1)
  // =====================================================================

  Future<LaporanPenjualan> adminLaporanPenjualan({
    required String token,
    DateTime? dari,
    DateTime? sampai,
  }) async {
    final response = await _client.rpc('admin_laporan_penjualan', params: {
      'p_token': token,
      'p_dari': dari != null ? AppFormat.dateSql(dari) : null,
      'p_sampai': sampai != null ? AppFormat.dateSql(sampai) : null,
    });
    return LaporanPenjualan.fromJson(response as Map<String, dynamic>);
  }

  Future<List<LogAktivitasItem>> adminLogAktivitas({
    required String token,
    int limit = 100,
    int offset = 0,
    String? tipe,
  }) async {
    final response = await _client.rpc('admin_log_aktivitas', params: {
      'p_token': token,
      'p_limit': limit,
      'p_offset': offset,
      'p_tipe': (tipe != null && tipe.isNotEmpty) ? tipe : null,
    });
    final List list = response as List;
    return list.map((e) => LogAktivitasItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
