import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/hive_boxes.dart';
import '../providers/sync_provider.dart';
import 'models/transaksi.dart';
import 'models/transaksi_item.dart';
import 'sync_service.dart';

final transaksiRepositoryProvider = Provider<TransaksiRepository>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  return TransaksiRepository(syncService, ref);
});

class TransaksiRepository {
  final SyncService _syncService;
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  TransaksiRepository(this._syncService, this._ref);

  /// Simpan transaksi baru secara offline-first.
  /// Tulis ke box antrean_transaksi di Hive dulu (status pending),
  /// lalu jalankan sinkronisasi di background.
  Future<Map<String, dynamic>> simpan({
    required String metode,
    required List<TransaksiItem> items,
  }) async {
    final id = _uuid.v4();
    final createdAt = DateTime.now();
    final total = items.fold(0, (sum, i) => sum + i.subtotal);

    final transaksi = Transaksi(
      id: id,
      createdAt: createdAt,
      total: total,
      metodeBayar: metode,
      status: 'selesai',
      items: items,
      isPending: true,
    );

    // 1. Tulis ke antrean lokal Hive
    await HiveBoxes.antreanBox.put(id, transaksi.toJson());
    _ref.read(pendingCountProvider.notifier).refresh();

    // 2. Trigger sync di background tanpa memblokir UI
    _syncService.sync();

    return {
      'ok': true,
      'id': id,
      'transaksi': transaksi,
    };
  }

  /// Edit transaksi pending yang ada di antrean lokal
  Future<void> editPending({
    required String id,
    required String metode,
    required List<TransaksiItem> items,
  }) async {
    final raw = HiveBoxes.antreanBox.get(id);
    if (raw != null) {
      final map = Map<String, dynamic>.from(raw);
      final total = items.fold(0, (sum, i) => sum + i.subtotal);
      final updated = Transaksi.fromJson(map, isPending: true).copyWith(
        items: items,
        total: total,
        metodeBayar: metode,
        dieditAt: DateTime.now(),
      );

      await HiveBoxes.antreanBox.put(id, updated.toJson());
      _ref.read(pendingCountProvider.notifier).refresh();
      _syncService.sync();
    }
  }

  /// Batalkan transaksi pending (hapus permanen dari antrean lokal)
  Future<void> batalPending(String id) async {
    await HiveBoxes.antreanBox.delete(id);
    _ref.read(pendingCountProvider.notifier).refresh();
  }
}
