import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1F1B16),
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
            backgroundColor: Colors.red,
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
      backgroundColor: const Color(0xFFF9EFE6),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Riwayat & Laporan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Pilih Rentang Tanggal',
            onPressed: () => _pilihRentang(context, ref),
            icon: const Icon(Icons.date_range, color: AppTheme.primary),
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
                color: Colors.white,
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
                              selectedColor: AppTheme.primary,
                              backgroundColor: const Color(0xFFF9EFE6),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF6E5A4F),
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
                            color: Color(0xFF2D1F17),
                          ),
                        ),
                        Text(
                          '${laporan.transaksi.length} catatan',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6E5A4F),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // List Transaksi
                  if (laporan.transaksi.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Tidak ada transaksi pada periode ini.',
                              style: TextStyle(color: Color(0xFF6E5A4F)),
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
                            color: Colors.red, size: 44),
                        const SizedBox(height: 12),
                        Text(
                          'Gagal memuat laporan:\n${err.toString().replaceAll('Exception:', '').trim()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4A2D).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                colors: [Color(0xFF7C4A2D), Color(0xFF9E5D38)],
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
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFormat.currency(ringkasan.totalPenjualan),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${ringkasan.jumlahTransaksi} transaksi berhasil'
                        '${ringkasan.jumlahBatal > 0 ? ' • ${ringkasan.jumlahBatal} batal' : ''}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.point_of_sale,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          // Average per Trx info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFFEE5D4).withValues(alpha: 0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rata-rata per Transaksi',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C4A2D),
                  ),
                ),
                Text(
                  AppFormat.currency(ringkasan.rataRataTransaksi),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C4A2D),
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
                      color: const Color(0xFFF9EFE6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.payments_outlined,
                              size: 16,
                              color: Color(0xFF7C4A2D),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TUNAI (${ringkasan.tunaiJumlah})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C4A2D),
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
                            color: Color(0xFF2D1F17),
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
                      color: const Color(0xFFF9EFE6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.qr_code_2,
                              size: 16,
                              color: Color(0xFFE28743),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'QRIS (${ringkasan.qrisJumlah})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE28743),
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
                            color: Color(0xFF2D1F17),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBatal
              ? Colors.red.withValues(alpha: 0.3)
              : const Color(0xFFEBDCD0).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4A2D).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                            color: Color(0xFF9E8D83),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isBatal)
                          _badge('Batal', Colors.red)
                        else if (isDiedit)
                          _badge('Diedit', Colors.orange),
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
                        color: isBatal ? Colors.grey : const Color(0xFF2D1F17),
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
                      color: isBatal ? Colors.grey : AppTheme.primary,
                      decoration: isBatal ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9EFE6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t.metodeBayar.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6E5A4F),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFFB39E91),
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
