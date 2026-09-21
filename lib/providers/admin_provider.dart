import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/models/admin_menu_item.dart';
import '../data/models/admin_ringkasan.dart';
import '../data/models/transaksi.dart';
import 'supabase_provider.dart';

class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException([this.message = 'SESI_TIDAK_VALID']);
  @override
  String toString() => message;
}

/// Token sesi admin disimpan di memori saja (tidak ke storage)
final adminTokenProvider = NotifierProvider<AdminTokenNotifier, String?>(AdminTokenNotifier.new);

class AdminTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setToken(String token) {
    state = token;
  }

  void clearToken() {
    state = null;
  }
}

/// Tanggal filter yang dipilih di tab Riwayat (default: hari ini)
final adminSelectedDateProvider = NotifierProvider<AdminSelectedDateNotifier, DateTime>(AdminSelectedDateNotifier.new);

class AdminSelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDate(DateTime date) {
    state = date;
  }
}

/// Provider Riwayat Transaksi Admin berdasarkan tanggal yang dipilih
final adminRiwayatProvider = FutureProvider.autoDispose<List<Transaksi>>((ref) async {
  final token = ref.watch(adminTokenProvider);
  if (token == null) {
    throw SessionExpiredException();
  }

  final date = ref.watch(adminSelectedDateProvider);
  final formattedDate = DateFormat('yyyy-MM-dd').format(date);
  final svc = ref.read(supabaseServiceProvider);

  try {
    return await svc.adminRiwayat(token, tanggal: formattedDate);
  } catch (e) {
    final errStr = e.toString();
    if (errStr.contains('SESI_TIDAK_VALID')) {
      ref.read(adminTokenProvider.notifier).clearToken();
      throw SessionExpiredException();
    }
    rethrow;
  }
});

/// Provider Ringkasan Penjualan Admin berdasarkan tanggal yang dipilih
final adminRingkasanProvider = FutureProvider.autoDispose<AdminRingkasan>((ref) async {
  final token = ref.watch(adminTokenProvider);
  if (token == null) {
    throw SessionExpiredException();
  }

  final date = ref.watch(adminSelectedDateProvider);
  final formattedDate = DateFormat('yyyy-MM-dd').format(date);
  final svc = ref.read(supabaseServiceProvider);

  try {
    return await svc.adminRingkasan(token, tanggal: formattedDate);
  } catch (e) {
    final errStr = e.toString();
    if (errStr.contains('SESI_TIDAK_VALID')) {
      ref.read(adminTokenProvider.notifier).clearToken();
      throw SessionExpiredException();
    }
    rethrow;
  }
});

/// Provider Daftar Menu Admin (aktif & nonaktif)
final adminDaftarMenuProvider = FutureProvider.autoDispose<List<AdminMenuItem>>((ref) async {
  final token = ref.watch(adminTokenProvider);
  if (token == null) {
    throw SessionExpiredException();
  }

  final svc = ref.read(supabaseServiceProvider);
  try {
    return await svc.adminDaftarMenu(token);
  } catch (e) {
    final errStr = e.toString();
    if (errStr.contains('SESI_TIDAK_VALID')) {
      ref.read(adminTokenProvider.notifier).clearToken();
      throw SessionExpiredException();
    }
    rethrow;
  }
});
