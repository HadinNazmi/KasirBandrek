import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/hive_boxes.dart';
import '../data/models/transaksi.dart';
import 'supabase_provider.dart';

final hariIniProvider = FutureProvider<List<Transaksi>>((ref) async {
  // 1. Ambil transaksi pending dari antrean lokal Hive
  final box = HiveBoxes.antreanBox;
  final List<Transaksi> pendingList = [];

  for (final key in box.keys) {
    final raw = box.get(key);
    if (raw != null) {
      try {
        final map = Map<String, dynamic>.from(raw);
        pendingList.add(Transaksi.fromJson(map, isPending: true));
      } catch (_) {}
    }
  }

  // Urutkan transaksi pending terbaru di atas
  pendingList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // 2. Ambil transaksi server jika ada koneksi
  List<Transaksi> serverList = [];
  try {
    final supabaseService = ref.read(supabaseServiceProvider);
    serverList = await supabaseService.kasirRiwayatHariIni();
  } catch (_) {
    // Jika offline, biarkan serverList kosong
    serverList = [];
  }

  // 3. Gabungkan: pending di atas, pastikan tidak ada ID ganda
  final pendingIds = pendingList.map((t) => t.id).toSet();
  final filteredServerList = serverList.where((t) => !pendingIds.contains(t.id)).toList();

  return [...pendingList, ...filteredServerList];
});
