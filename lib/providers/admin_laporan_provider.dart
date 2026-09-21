import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/laporan_penjualan.dart';
import 'admin_provider.dart';
import 'supabase_provider.dart';

enum LaporanPreset {
  hariIni('Hari Ini'),
  tujuhHari('7 Hari'),
  bulanIni('Bulan Ini'),
  tahunIni('Tahun Ini'),
  semua('Semua'),
  custom('Rentang');

  final String label;
  const LaporanPreset(this.label);
}

class LaporanFilterState {
  final LaporanPreset preset;
  final DateTime? dari;
  final DateTime? sampai;

  const LaporanFilterState({
    required this.preset,
    this.dari,
    this.sampai,
  });

  LaporanFilterState copyWith({
    LaporanPreset? preset,
    DateTime? Function()? dari,
    DateTime? Function()? sampai,
  }) {
    return LaporanFilterState(
      preset: preset ?? this.preset,
      dari: dari != null ? dari() : this.dari,
      sampai: sampai != null ? sampai() : this.sampai,
    );
  }
}

class AdminLaporanFilterNotifier extends Notifier<LaporanFilterState> {
  @override
  LaporanFilterState build() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return LaporanFilterState(
      preset: LaporanPreset.hariIni,
      dari: today,
      sampai: today,
    );
  }

  void setPreset(LaporanPreset preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (preset) {
      case LaporanPreset.hariIni:
        state = LaporanFilterState(
          preset: preset,
          dari: today,
          sampai: today,
        );
        break;
      case LaporanPreset.tujuhHari:
        state = LaporanFilterState(
          preset: preset,
          dari: today.subtract(const Duration(days: 6)),
          sampai: today,
        );
        break;
      case LaporanPreset.bulanIni:
        state = LaporanFilterState(
          preset: preset,
          dari: DateTime(today.year, today.month, 1),
          sampai: today,
        );
        break;
      case LaporanPreset.tahunIni:
        state = LaporanFilterState(
          preset: preset,
          dari: DateTime(today.year, 1, 1),
          sampai: today,
        );
        break;
      case LaporanPreset.semua:
        state = const LaporanFilterState(
          preset: LaporanPreset.semua,
          dari: null,
          sampai: null,
        );
        break;
      case LaporanPreset.custom:
        // Do not change dates if already custom, keep current dates
        state = state.copyWith(preset: LaporanPreset.custom);
        break;
    }
  }

  void setCustomRange(DateTime dari, DateTime sampai) {
    state = LaporanFilterState(
      preset: LaporanPreset.custom,
      dari: DateTime(dari.year, dari.month, dari.day),
      sampai: DateTime(sampai.year, sampai.month, sampai.day),
    );
  }
}

final adminLaporanFilterProvider =
    NotifierProvider<AdminLaporanFilterNotifier, LaporanFilterState>(
  AdminLaporanFilterNotifier.new,
);

final adminLaporanProvider =
    FutureProvider.autoDispose<LaporanPenjualan>((ref) async {
  final token = ref.watch(adminTokenProvider);
  if (token == null) {
    throw SessionExpiredException();
  }

  final filter = ref.watch(adminLaporanFilterProvider);
  final svc = ref.read(supabaseServiceProvider);

  try {
    return await svc.adminLaporanPenjualan(
      token: token,
      dari: filter.dari,
      sampai: filter.sampai,
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
