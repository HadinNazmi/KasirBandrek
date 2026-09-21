import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models/transaksi.dart';
import '../../data/transaksi_repository.dart';
import '../../providers/hari_ini_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/supabase_provider.dart';
import 'widgets/cart_sheet.dart';

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
                        colors: [AppTheme.primary, Color(0xFFAD6B45)],
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
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppFormat.currency(totalHariIni),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${selesai.length} transaksi selesai',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.trending_up, color: Colors.white30, size: 48),
                      ],
                    ),
                  ),
                ),

                if (transaksis.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('Belum ada transaksi hari ini.')),
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
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 8),
              Text(err.toString().replaceAll('Exception:', '').trim()),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isBatal ? Colors.red.withValues(alpha: 0.3) : Colors.transparent,
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
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 6),
                    if (isBatal)
                      _badge('Batal', Colors.red)
                    else ...[
                      if (t.isPending) ...[
                        _badge('Belum terkirim', Colors.orange),
                        const SizedBox(width: 4),
                      ],
                      if (isDiedit)
                        _badge('Diedit', Colors.blueGrey),
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
                      color: isBatal ? Colors.grey : Colors.black,
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
                    color: isBatal ? Colors.grey : AppTheme.primary,
                    decoration: isBatal ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.metodeBayar.toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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
      backgroundColor: Colors.white,
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
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(AppFormat.dateTime(t.createdAt.toLocal()),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Row(
                      children: [
                        Text(t.metodeBayar.toUpperCase(),
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        if (t.isPending) ...[
                          const SizedBox(width: 8),
                          _badge('Belum terkirim', Colors.orange),
                        ],
                      ],
                    ),
                  ]),
                  const Spacer(),
                  Text(AppFormat.currency(t.total),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primary)),
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
                                  backgroundColor: Colors.orange,
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
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
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
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
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
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Transaksi ini sudah dibatalkan',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
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
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: sheetCtx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Batalkan Transaksi'),
        content: const Text('Apakah Anda yakin ingin membatalkan transaksi ini? Tindakan ini tidak bisa diurungkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Tidak')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
