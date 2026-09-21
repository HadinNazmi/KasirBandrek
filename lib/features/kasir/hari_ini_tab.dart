import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../data/models/transaksi.dart';
import '../../data/transaksi_repository.dart';
import '../../providers/hari_ini_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/supabase_provider.dart';
import 'widgets/cart_sheet.dart';
import '../shared/widgets/produk_terjual_card.dart';

class HariIniTab extends ConsumerWidget {
  const HariIniTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hariIniAsync = ref.watch(hariIniProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hari Ini', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: hariIniAsync.when(
        data: (transaksis) {
          final selesai = transaksis.where((t) => t.status == 'selesai').toList();
          final totalHariIni = selesai.fold(0, (sum, t) => sum + t.total);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(hariIniProvider),
            child: CustomScrollView(
              slivers: [
                // Ringkasan total hari ini
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.burgundy, AppColors.burgundyDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Penjualan Hari Ini',
                                style: TextStyle(color: AppColors.textOnDarkMuted, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppFormat.currency(totalHariIni),
                                style: const TextStyle(
                                  color: AppColors.cream,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${selesai.length} transaksi selesai',
                                style: const TextStyle(color: AppColors.textOnDarkMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.trending_up, color: AppColors.textOnDarkMuted, size: 48),
                      ],
                    ),
                  ),
                ),

                // Produk Terjual Hari Ini
                if (selesai.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: ProdukTerjualCard(
                        transaksi: transaksis,
                        judulPeriode: 'Hanya transaksi selesai hari ini',
                      ),
                    ),
                  ),

                if (transaksis.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('Belum ada transaksi hari ini.', style: TextStyle(color: AppColors.textSecondary))),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final t = transaksis[index];
                        return _buildTransaksiCard(context, ref, t);
                      },
                      childCount: transaksis.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 8),
              Text(err.toString().replaceAll('Exception:', '').trim(), style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(hariIniProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransaksiCard(BuildContext context, WidgetRef ref, Transaksi t) {
    final isBatal = t.status == 'batal';
    final isDiedit = t.dieditAt != null;

    return GestureDetector(
      onTap: () => _showDetail(context, ref, t),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isBatal ? AppColors.errorBorder : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Jam + label status
                  Row(children: [
                    Text(
                      AppFormat.dateTime(t.createdAt.toLocal()).split(', ').last,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    if (isBatal)
                      _badge('Batal', AppColors.error)
                    else ...[
                      if (t.isPending) ...[
                        _badge('Belum terkirim', AppColors.warning),
                        const SizedBox(width: 4),
                      ],
                      if (isDiedit)
                        _badge('Diedit', AppColors.info),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  // Ringkasan item
                  Text(
                    t.items.map((i) => '${i.namaMenu} ×${i.qty}').join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isBatal ? AppColors.textMuted : AppColors.textPrimary,
                      decoration: isBatal ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormat.currency(t.total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBatal ? AppColors.textMuted : AppColors.burgundy,
                    decoration: isBatal ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.metodeBayar.toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref, Transaksi t) {
    final isBatal = t.status == 'batal';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, sc) => Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(AppFormat.dateTime(t.createdAt.toLocal()),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                    Row(
                      children: [
                        Text(t.metodeBayar.toUpperCase(),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        if (t.isPending) ...[
                          const SizedBox(width: 8),
                          _badge('Belum terkirim', AppColors.warning),
                        ],
                      ],
                    ),
                  ]),
                  const Spacer(),
                  Text(AppFormat.currency(t.total),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.burgundy)),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: AppColors.textPrimary),
                    ),
                  ),
                ]),
              ),
              const Divider(height: 20),
              // Items
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: t.items.length,
                  itemBuilder: (_, idx) {
                    final item = t.items[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Expanded(child: Text('${item.namaMenu} ×${item.qty}')),
                        Text(AppFormat.currency(item.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    );
                  },
                ),
              ),

              // Aksi Edit / Batalkan (hanya jika status selesai)
              if (!isBatal)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (!t.isPending) {
                            final isOnline = ref.read(isOnlineProvider).value ?? true;
                            if (!isOnline) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Butuh internet untuk mengubah transaksi yang sudah terkirim'),
                                  backgroundColor: AppColors.warning,
                                ),
                              );
                              return;
                            }
                          }

                          Navigator.pop(ctx);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => CartSheet(
                              editMode: true,
                              isLocalPending: t.isPending,
                              transaksiId: t.id,
                              initialItems: t.items,
                              initialMetode: t.metodeBayar,
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: AppColors.burgundy,
                          side: const BorderSide(color: AppColors.burgundy),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _batalkan(ctx, context, ref, t),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Batalkan'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.cream,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),
                ),

              if (isBatal)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Transaksi ini sudah dibatalkan',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _batalkan(BuildContext sheetCtx, BuildContext rootCtx, WidgetRef ref, Transaksi t) async {
    if (!t.isPending) {
      final isOnline = ref.read(isOnlineProvider).value ?? true;
      if (!isOnline) {
        ScaffoldMessenger.of(rootCtx).showSnackBar(
          const SnackBar(
            content: Text('Butuh internet untuk mengubah transaksi yang sudah terkirim'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: sheetCtx,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Batalkan Transaksi', style: TextStyle(color: AppColors.textDark)),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan transaksi ini? Tindakan ini tidak bisa diurungkan.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Tidak', style: TextStyle(color: AppColors.textDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.cream),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      if (t.isPending) {
        final repo = ref.read(transaksiRepositoryProvider);
        await repo.batalPending(t.id);
      } else {
        final svc = ref.read(supabaseServiceProvider);
        await svc.kasirBatalkanTransaksi(id: t.id);
      }
      ref.invalidate(hariIniProvider);
      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
      if (rootCtx.mounted) {
        ScaffoldMessenger.of(rootCtx).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil dibatalkan')),
        );
      }
    } catch (e) {
      if (rootCtx.mounted) {
        ScaffoldMessenger.of(rootCtx).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
