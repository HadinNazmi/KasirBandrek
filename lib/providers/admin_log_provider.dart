import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/log_aktivitas_item.dart';
import 'admin_provider.dart';
import 'supabase_provider.dart';

final adminLogTipeFilterProvider =
    NotifierProvider<AdminLogTipeFilterNotifier, String?>(
  AdminLogTipeFilterNotifier.new,
);

class AdminLogTipeFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setTipe(String? tipe) {
    state = tipe;
  }
}

final adminLogAktivitasProvider =
    FutureProvider.autoDispose<List<LogAktivitasItem>>((ref) async {
  final token = ref.watch(adminTokenProvider);
  if (token == null) {
    throw SessionExpiredException();
  }

  final tipe = ref.watch(adminLogTipeFilterProvider);
  final svc = ref.read(supabaseServiceProvider);

  try {
    return await svc.adminLogAktivitas(
      token: token,
      limit: 100,
      tipe: tipe,
    );
  } catch (e) {
    final errStr = e.toString();
    if (errStr.contains('SESI_TIDAK_VALID')) {
      ref.read(adminTokenProvider.notifier).clearToken();
      throw SessionExpiredException();
    }
    rethrow;
  }
});
