import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
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
            backgroundColor: AppColors.error,
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
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Log Aktivitas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.cream,
              ),
            ),
            Text(
              'Audit Trail & Keamanan Kasir',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.cardBgSecondary,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Muat Ulang',
            icon: const Icon(Icons.refresh, color: AppColors.gold),
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
                color: AppColors.cardBg,
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
                          selectedColor: AppColors.burgundy,
                          backgroundColor: AppColors.cardBgSecondary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.cream
                                : AppColors.textDark,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.burgundy
                                  : AppColors.border,
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
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.shield_outlined,
                          size: 20, color: AppColors.burgundy),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Catatan aktivitas ini tersimpan secara otomatis dan permanen (tamper-proof) untuk mengawasi kasir & mencegah manipulasi.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textDark,
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
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_outlined,
                              size: 48, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada catatan aktivitas pada kategori ini.',
                            style: TextStyle(color: AppColors.textMuted),
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
                                color: AppColors.burgundy,
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
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.burgundy),
                ),
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
                          'Gagal memuat log aktivitas:\n${err.toString().replaceAll('Exception:', '').trim()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.burgundy,
                            foregroundColor: AppColors.cream,
                          ),
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
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: style.borderColor.withValues(alpha: 0.5),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 6,
            offset: Offset(0, 2),
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
                                  ? AppColors.burgundy.withValues(alpha: 0.12)
                                  : AppColors.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log.aktor.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: log.aktor.toLowerCase() == 'admin'
                                  ? AppColors.burgundy
                                  : AppColors.textDark,
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
                          color: AppColors.textMuted,
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
                      color: AppColors.textDark,
                    ),
                  ),
                  if (log.rincian != null && log.rincian!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      log.rincian!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
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
        accentColor: AppColors.error,
        bgColor: AppColors.errorBg,
        borderColor: AppColors.error.withValues(alpha: 0.3),
        badgeLabel: 'Pembatalan',
      );
    }
    if (tipe.contains('UBAH') || tipe.contains('EDIT')) {
      return _LogStyle(
        icon: Icons.edit_note_outlined,
        accentColor: AppColors.warning,
        bgColor: AppColors.warningBg,
        borderColor: AppColors.warning.withValues(alpha: 0.3),
        badgeLabel: 'Perubahan',
      );
    }
    if (tipe.contains('TRANSAKSI_BARU')) {
      return _LogStyle(
        icon: Icons.add_shopping_cart,
        accentColor: AppColors.success,
        bgColor: AppColors.successBg,
        borderColor: AppColors.success.withValues(alpha: 0.3),
        badgeLabel: 'Transaksi Baru',
      );
    }
    if (tipe.contains('MENU') || tipe.contains('KATEGORI')) {
      return _LogStyle(
        icon: Icons.restaurant_menu,
        accentColor: AppColors.info,
        bgColor: AppColors.infoBg,
        borderColor: AppColors.info.withValues(alpha: 0.3),
        badgeLabel: 'Menu & Sistem',
      );
    }
    return _LogStyle(
      icon: Icons.history,
      accentColor: AppColors.burgundy,
      bgColor: AppColors.cardBgSecondary,
      borderColor: AppColors.border,
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
