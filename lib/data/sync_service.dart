import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/hive_boxes.dart';
import '../core/network_info.dart';
import 'models/transaksi.dart';
import 'supabase_service.dart';

class SyncService {
  final SupabaseService _supabaseService;
  bool _isSyncing = false;
  final Set<dynamic> _syncingKeys = {};
  Timer? _retryTimer;
  int _retrySeconds = 5;

  // Callback / listener saat sync selesai atau antrean berubah
  void Function()? onSyncChanged;

  SyncService(this._supabaseService) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none) && results.isNotEmpty) {
        // Koneksi pulih, langsung sinkronisasi
        sync();
      }
    });
  }

  Future<void> sync() async {
    if (_isSyncing) return;

    final hasInternet = await NetworkInfo.isConnected();
    if (!hasInternet) return;

    final box = HiveBoxes.antreanBox;
    if (box.isEmpty) return;

    _isSyncing = true;
    _retryTimer?.cancel();
    onSyncChanged?.call();

    try {
      final keys = box.keys.toList();
      for (final key in keys) {
        if (_syncingKeys.contains(key)) continue;

        final raw = box.get(key);
        if (raw == null) continue;

        _syncingKeys.add(key);

        try {
          final map = Map<String, dynamic>.from(raw);
          final t = Transaksi.fromJson(map, isPending: true);

          final res = await _supabaseService.simpanTransaksi(
            id: t.id,
            createdAt: t.createdAt,
            metode: t.metodeBayar,
            items: t.items,
          );

          final isOk = res['ok'] as bool? ?? false;
          final isDuplikat = res['duplikat'] as bool? ?? false;

          if (isOk || isDuplikat) {
            await box.delete(key);
            _retrySeconds = 5; // Reset backoff jika sukses
          }
        } catch (e) {
          // Gagal kirim item ini, jadwalkan retry dengan jeda bertahap (maks 60 detik)
          _scheduleRetry();
          break;
        } finally {
          _syncingKeys.remove(key);
        }
      }
    } finally {
      _isSyncing = false;
      onSyncChanged?.call();
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: _retrySeconds), () {
      sync();
    });
    // Jeda bertahap hingga maksimal 60 detik
    _retrySeconds = (_retrySeconds * 2).clamp(5, 60);
  }

  void dispose() {
    _retryTimer?.cancel();
  }
}
