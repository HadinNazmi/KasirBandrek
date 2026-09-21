import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../data/models/transaksi.dart';
import '../../../providers/admin_provider.dart';
import '../pin_gate.dart';
import 'admin_transaksi_detail_sheet.dart';

class RiwayatTab extends ConsumerWidget {
  const RiwayatTab({super.key});

  void _pilihTanggal(BuildContext context, WidgetRef ref, DateTime currentDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
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
      ref.read(adminSelectedDateProvider.notifier).setDate(picked);
    }
  }

  void _checkSession(BuildContext context, Object error, WidgetRef ref) {
    if (error is SessionExpiredException || error.toString().contains('SESI_TIDAK_VALID')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(adminTokenProvider.notifier).clearToken();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PinGateScreen()),
          (route) => route.isFirst,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi admin telah berakhir. Silakan masukkan PIN kembali.'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(adminSelectedDateProvider);
    final ringkasanAsync = ref.watch(adminRingkasanProvider);
    final riwayatAsync = ref.watch(adminRiwayatProvider);

    // Watch for session expiration
    ringkasanAsync.whenOrNull(error: (e, _) => _checkSession(context, e, ref));
    riwayatAsync.whenOrNull(error: (e, _) => _checkSession(context, e, ref));

    final isToday = DateUtils.isSameDay(selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF9EFE6),
      appBar: AppBar(
        title: const Text('Riwayat Penjualan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Filter Tanggal Button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _pilihTanggal(context, ref, selectedDate),
              icon: const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
              label: Text(
                isToday ? 'Hari Ini' : AppFormat.date(selectedDate),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFEE5D4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminRingkasanProvider);
          ref.invalidate(adminRiwayatProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Ringkasan Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: ringkasanAsync.when(
                  data: (ringkasan) => _buildSummaryCard(ringkasan),
                  loading: () => Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        'Gagal memuat ringkasan: ${err.toString().replaceAll('Exception:', '').trim()}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Section Header
            SliverToBoxAdapter(
              child: Padding(
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
                    riwayatAsync.when(
                      data: (list) => Text(
                        '${list.length} catatan',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6E5A4F)),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            // Daftar Transaksi
            riwayatAsync.when(
              data: (transaksis) {
                if (transaksis.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_outlined, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            isToday
                                ? 'Belum ada transaksi hari ini.'
                                : 'Tidak ada transaksi pada tanggal ${AppFormat.date(selectedDate)}.',
                            style: const TextStyle(color: Color(0xFF6E5A4F)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final t = transaksis[index];
                      return _buildTransaksiItem(context, t);
                    },
                    childCount: transaksis.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      Text(err.toString().replaceAll('Exception:', '').trim()),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(adminRingkasanProvider);
                          ref.invalidate(adminRiwayatProvider);
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(dynamic ringkasan) {
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
                  child: const Icon(Icons.point_of_sale, color: Colors.white, size: 28),
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
                            const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF7C4A2D)),
                            const SizedBox(width: 6),
                            Text(
                              'TUNAI (${ringkasan.tunai.jumlah})',
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
                          AppFormat.currency(ringkasan.tunai.total),
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
                            const Icon(Icons.qr_code_2, size: 16, color: Color(0xFFE28743)),
                            const SizedBox(width: 6),
                            Text(
                              'QRIS (${ringkasan.qris.jumlah})',
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
                          AppFormat.currency(ringkasan.qris.total),
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

  Widget _buildTransaksiItem(BuildContext context, Transaksi t) {
    final isBatal = t.status == 'batal';
    final isDiedit = t.dieditAt != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBatal ? Colors.red.withValues(alpha: 0.3) : const Color(0xFFEBDCD0).withValues(alpha: 0.6),
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
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AdminTransaksiDetailSheet(transaksi: t),
          );
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
                          AppFormat.dateTime(t.createdAt.toLocal()).split(', ').last,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9E8D83), fontWeight: FontWeight.w500),
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              const Icon(Icons.chevron_right, size: 18, color: Color(0xFFB39E91)),
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
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}
