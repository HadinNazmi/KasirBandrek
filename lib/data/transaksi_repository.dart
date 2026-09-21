import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'models/transaksi_item.dart';
import 'supabase_service.dart';
import '../providers/supabase_provider.dart';

final transaksiRepositoryProvider = Provider<TransaksiRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return TransaksiRepository(supabaseService);
});

class TransaksiRepository {
  final SupabaseService _supabaseService;
  final Uuid _uuid = const Uuid();

  TransaksiRepository(this._supabaseService);

  /// Simpan transaksi baru.
  /// Milestone 3: langsung ke Supabase.
  /// Milestone 4: akan diganti menjadi antrean Hive lalu sync.
  Future<Map<String, dynamic>> simpan({
    required String metode,
    required List<TransaksiItem> items,
  }) async {
    final id = _uuid.v4();
    final createdAt = DateTime.now();
    return await _supabaseService.simpanTransaksi(
      id: id,
      createdAt: createdAt,
      metode: metode,
      items: items,
    );
  }
}
