import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../data/models/laporan_penjualan.dart';
import '../../../data/models/transaksi.dart';
import '../../../providers/admin_laporan_provider.dart';
import '../../../providers/admin_log_provider.dart';
import '../../../providers/admin_provider.dart';
import '../pin_gate.dart';
import 'admin_transaksi_detail_sheet.dart';
import '../../shared/widgets/produk_terjual_card.dart';

class RiwayatTab extends ConsumerWidget {
  const RiwayatTab({super.key});

  void _pilihRentang(BuildContext context, WidgetRef ref) async {
    final filter = ref.read(adminLaporanFilterProvider);
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: filter.dari ?? now.subtract(const Duration(days: 7)),
      end: filter.sampai ?? now,
    );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.burgundy,
              onPrimary: AppColors.cream,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(adminLaporanFilterProvider.notifier).setCustomRange(
            picked.start,
            picked.end,
          );
    }
  }

  void _checkSession(BuildContext context, Object error, WidgetRef ref) {
    if (error is SessionExpiredException ||
        error.toString().contains('SESI_TIDAK_VALID')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminTokenProvider.notifier).clearToken();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PinGateScreen()),
          (route) => route.isFirst,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Sesi admin telah berakhir. Silakan masukkan PIN kembali.'),
            backgroundColor: AppColors.error,
          ),
        );
      });
    }
  }

  String _formatPeriodeText(LaporanFilterState filter) {
    switch (filter.preset) {
      case LaporanPreset.hariIni:
        return 'Hari Ini (${filter.dari != null ? DateFormat('d MMMM yyyy', 'id_ID').format(filter.dari!) : ''})';
      case LaporanPreset.tujuhHari:
        return '7 Hari Terakhir (${_formatDateRange(filter.dari, filter.sampai)})';
      case LaporanPreset.bulanIni:
        return 'Bulan Ini (${_formatDateRange(filter.dari, filter.sampai)})';
      case LaporanPreset.tahunIni:
        return 'Tahun Ini (${_formatDateRange(filter.dari, filter.sampai)})';
      case LaporanPreset.semua:
        return 'Semua Waktu (All-Time)';
      case LaporanPreset.custom:
        return 'Rentang: ${_formatDateRange(filter.dari, filter.sampai)}';
    }
  }

  String _formatDateRange(DateTime? dari, DateTime? sampai) {
    if (dari == null || sampai == null) return '';
    final fmt = DateFormat('d MMM yyyy', 'id_ID');
    return '${fmt.format(dari)} - ${fmt.format(sampai)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(adminLaporanFilterProvider);
    final laporanAsync = ref.watch(adminLaporanProvider);

    // Watch for session expiration
    laporanAsync.whenOrNull(error: (e, _) => _checkSession(context, e, ref));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Riwayat & Laporan',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.cream),
        ),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Pilih Rentang Tanggal',
            onPressed: () => _pilihRentang(context, ref),
            icon: const Icon(Icons.date_range, color: AppColors.cream),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminLaporanProvider);
          ref.invalidate(adminLogAktivitasProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Filter Presets Bar
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: LaporanPreset.values.map((preset) {
                          final isSelected = filter.preset == preset;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(preset.label),
                              selected: isSelected,
                              showCheckmark: false,
                              selectedColor: AppColors.burgundy,
                              backgroundColor: AppColors.surfaceElevated,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.cream
                                    : AppColors.textSecondary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.transparent,
                                ),
                              ),
                              onSelected: (_) {
                                if (preset == LaporanPreset.custom) {
                                  _pilihRentang(context, ref);
                                } else {
                                  ref
                                      .read(adminLaporanFilterProvider.notifier)
                                      .setPreset(preset);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppTheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatPeriodeText(filter),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Main Content: Summary, Chart, Transaction List
            laporanAsync.when(
              data: (laporan) => SliverList(
                delegate: SliverChildListDelegate([
                  // Ringkasan Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _buildSummaryCard(laporan.ringkasan),
                  ),

                  // Produk Terjual Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ProdukTerjualCard(
                      transaksi: laporan.transaksi,
                      judulPeriode: _formatPeriodeText(filter),
                    ),
                  ),

                  // Section Header Transaksi
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Daftar Transaksi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${laporan.transaksi.length} catatan',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // List Transaksi
                  if (laporan.transaksi.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 48,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Tidak ada transaksi pada periode ini.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...laporan.transaksi.map(
                      (t) => _buildTransaksiItem(
                        context,
                        ref,
                        t,
                        showFullDate: filter.preset != LaporanPreset.hariIni,
                      ),
                    ),

                  const SizedBox(height: 32),
                ]),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.error, size: 44),
                        const SizedBox(height: 12),
                        Text(
                          'Gagal memuat laporan:\n${err.toString().replaceAll('Exception:', '').trim()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(adminLaporanProvider),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(LaporanRingkasan ringkasan) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowDark,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Total Penjualan Hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.burgundy, AppColors.burgundyDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Penjualan (Selesai)',
                        style: TextStyle(color: AppColors.textOnDarkMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormat.currency(ringkasan.totalPenjualan),
                        style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ringkasan.jumlahTransaksi} transaksi berhasil'
                        '${ringkasan.jumlahBatal > 0 ? ' • ${ringkasan.jumlahBatal} batal' : ''}',
                        style: const TextStyle(color: AppColors.textOnDarkMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.cream.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.point_of_sale,
                    color: AppColors.cream,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          // Metode Bayar Breakdowns (Tunai & QRIS)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Tunai
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.payments_outlined,
                              size: 16,
                              color: AppColors.burgundy,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'TUNAI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.burgundy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppFormat.currency(ringkasan.tunaiTotal),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // QRIS
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.qr_code_2,
                              size: 16,
                              color: AppColors.gold,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'QRIS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.burgundyDeep,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppFormat.currency(ringkasan.qrisTotal),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransaksiItem(
    BuildContext context,
    WidgetRef ref,
    Transaksi t, {
    required bool showFullDate,
  }) {
    final isBatal = t.status == 'batal';
    final isDiedit = t.dieditAt != null;

    final dateText = showFullDate
        ? DateFormat('d MMM, HH:mm', 'id_ID').format(t.createdAt.toLocal())
        : DateFormat('HH:mm', 'id_ID').format(t.createdAt.toLocal());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBatal
              ? AppColors.errorBorder
              : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () async {
          final res = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AdminTransaksiDetailSheet(transaksi: t),
          );
          if (res != null) {
            ref.invalidate(adminLaporanProvider);
            ref.invalidate(adminLogAktivitasProvider);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Jam & Badges
                    Row(
                      children: [
                        Text(
                          dateText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isBatal)
                          _badge('Batal', AppColors.error)
                        else if (isDiedit)
                          _badge('Diedit', AppColors.warning),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Item summary
                    Text(
                      t.items.map((i) => '${i.namaMenu} ×${i.qty}').join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isBatal ? AppColors.textMuted : AppColors.textPrimary,
                        decoration: isBatal ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormat.currency(t.total),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isBatal ? AppColors.textMuted : AppColors.burgundy,
                      decoration: isBatal ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t.metodeBayar.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
