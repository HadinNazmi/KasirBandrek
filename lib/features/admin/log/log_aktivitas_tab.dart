import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../data/models/log_aktivitas_item.dart';
import '../../../providers/admin_log_provider.dart';
import '../../../providers/admin_provider.dart';
import '../pin_gate.dart';

class LogAktivitasTab extends ConsumerWidget {
  const LogAktivitasTab({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(adminLogTipeFilterProvider);
    final logAsync = ref.watch(adminLogAktivitasProvider);

    // Watch for session expiration
    logAsync.whenOrNull(error: (e, _) => _checkSession(context, e, ref));

    final filters = [
      (label: 'Semua', value: null),
      (label: 'Pembatalan', value: 'BATAL_TRANSAKSI'),
      (label: 'Perubahan', value: 'UBAH_TRANSAKSI'),
      (label: 'Transaksi Baru', value: 'TRANSAKSI_BARU'),
      (label: 'Menu & Sistem', value: 'MENU'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9EFE6),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Log Aktivitas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Audit Trail & Keamanan Kasir',
              style: TextStyle(fontSize: 12, color: AppTheme.outline),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Muat Ulang',
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: () => ref.invalidate(adminLogAktivitasProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminLogAktivitasProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Filter Chips Bar
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filters.map((f) {
                      final isSelected = activeFilter == f.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(f.label),
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
                            ref
                                .read(adminLogTipeFilterProvider.notifier)
                                .setTipe(f.value);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // Security Notice Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE5D4).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.secondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.shield_outlined,
                          size: 20, color: AppTheme.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Catatan aktivitas ini tersimpan secara otomatis dan permanen (tamper-proof) untuk mengawasi kasir & mencegah manipulasi.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5D3A24),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Content List
            logAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_outlined,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Belum ada catatan aktivitas pada kategori ini.',
                            style: TextStyle(color: Color(0xFF6E5A4F)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Group by Day
                final Map<String, List<LogAktivitasItem>> grouped = {};
                for (final log in logs) {
                  final key = _groupKey(log.createdAt.toLocal());
                  grouped.putIfAbsent(key, () => []).add(log);
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final groupKey = grouped.keys.elementAt(index);
                      final items = grouped[groupKey]!;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Text(
                              groupKey,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C4A2D),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          ...items.map((item) => _buildLogCard(context, item)),
                        ],
                      );
                    },
                    childCount: grouped.keys.length,
                  ),
                );
              },
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
                          'Gagal memuat log aktivitas:\n${err.toString().replaceAll('Exception:', '').trim()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
                              ref.invalidate(adminLogAktivitasProvider),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
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

  String _groupKey(DateTime dt) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(dt, now)) {
      return 'Hari Ini';
    }
    if (DateUtils.isSameDay(dt, now.subtract(const Duration(days: 1)))) {
      return 'Kemarin';
    }
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt);
  }

  Widget _buildLogCard(BuildContext context, LogAktivitasItem log) {
    final style = _getLogStyle(log.tipeAksi);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: style.borderColor.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4A2D).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Badge
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: style.bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, size: 20, color: style.accentColor),
            ),
            const SizedBox(width: 12),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Aktor Badge + Timestamp
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: log.aktor.toLowerCase() == 'admin'
                                  ? const Color(0xFFEDE7F6)
                                  : const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log.aktor.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: log.aktor.toLowerCase() == 'admin'
                                    ? const Color(0xFF512DA8)
                                    : const Color(0xFF00796B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: style.bgColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              style.badgeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: style.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        DateFormat('HH:mm').format(log.createdAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Judul
                  Text(
                    log.judul,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F1B16),
                    ),
                  ),
                  if (log.rincian != null && log.rincian!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      log.rincian!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5D4A3E),
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _LogStyle _getLogStyle(String tipe) {
    if (tipe.contains('BATAL')) {
      return _LogStyle(
        icon: Icons.cancel_outlined,
        accentColor: const Color(0xFFD32F2F),
        bgColor: const Color(0xFFFFEBEE),
        borderColor: const Color(0xFFEF9A9A),
        badgeLabel: 'Pembatalan',
      );
    }
    if (tipe.contains('UBAH') || tipe.contains('EDIT')) {
      return _LogStyle(
        icon: Icons.edit_note_outlined,
        accentColor: const Color(0xFFE65100),
        bgColor: const Color(0xFFFFF3E0),
        borderColor: const Color(0xFFFFCC80),
        badgeLabel: 'Perubahan',
      );
    }
    if (tipe.contains('TRANSAKSI_BARU')) {
      return _LogStyle(
        icon: Icons.add_shopping_cart,
        accentColor: const Color(0xFF2E7D32),
        bgColor: const Color(0xFFE8F5E9),
        borderColor: const Color(0xFFA5D6A7),
        badgeLabel: 'Transaksi Baru',
      );
    }
    if (tipe.contains('MENU') || tipe.contains('KATEGORI')) {
      return _LogStyle(
        icon: Icons.restaurant_menu,
        accentColor: const Color(0xFF1565C0),
        bgColor: const Color(0xFFE3F2FD),
        borderColor: const Color(0xFF90CAF9),
        badgeLabel: 'Menu & Sistem',
      );
    }
    return _LogStyle(
      icon: Icons.history,
      accentColor: AppTheme.primary,
      bgColor: const Color(0xFFF9EFE6),
      borderColor: AppTheme.surfaceDim,
      badgeLabel: 'Aktivitas',
    );
  }
}

class _LogStyle {
  final IconData icon;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;
  final String badgeLabel;

  _LogStyle({
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
    required this.badgeLabel,
  });
}
