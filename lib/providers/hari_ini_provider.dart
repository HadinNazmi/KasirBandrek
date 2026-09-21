import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/transaksi.dart';
import 'supabase_provider.dart';

final hariIniProvider = FutureProvider<List<Transaksi>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return await supabaseService.kasirRiwayatHariIni();
});
