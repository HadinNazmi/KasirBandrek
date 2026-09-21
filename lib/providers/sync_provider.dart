import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/hive_boxes.dart';
import '../data/sync_service.dart';
import 'hari_ini_provider.dart';
import 'supabase_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final service = SyncService(supabaseService);

  service.onSyncChanged = () {
    ref.read(pendingCountProvider.notifier).refresh();
    ref.invalidate(hariIniProvider);
  };

  // Jalankan sinkronisasi awal saat app dibuka
  service.sync();

  ref.onDispose(() => service.dispose());
  return service;
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    return !results.contains(ConnectivityResult.none) && results.isNotEmpty;
  });
});

final pendingCountProvider = NotifierProvider<PendingCountNotifier, int>(PendingCountNotifier.new);

class PendingCountNotifier extends Notifier<int> {
  @override
  int build() {
    return HiveBoxes.antreanBox.length;
  }

  void refresh() {
    state = HiveBoxes.antreanBox.length;
  }
}
