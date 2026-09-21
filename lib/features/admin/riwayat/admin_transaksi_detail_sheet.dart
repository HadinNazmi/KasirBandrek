import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/network_info.dart';
import '../../../core/theme.dart';
import '../../../data/models/transaksi.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/hari_ini_provider.dart';
import '../../../providers/supabase_provider.dart';
import '../../kasir/widgets/cart_sheet.dart';
import '../pin_gate.dart';

class AdminTransaksiDetailSheet extends ConsumerStatefulWidget {
  final Transaksi transaksi;

  const AdminTransaksiDetailSheet({
    super.key,
    required this.transaksi,
  });

  @override
  ConsumerState<AdminTransaksiDetailSheet> createState() => _AdminTransaksiDetailSheetState();
}

class _AdminTransaksiDetailSheetState extends ConsumerState<AdminTransaksiDetailSheet> {
  bool _isLoading = false;

  void _edit() async {
    final token = ref.read(adminTokenProvider);
    if (token == null) {
      _handleSessionExpired();
      return;
    }

    final hasInternet = await NetworkInfo.isConnected();
    if (!hasInternet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(NetworkInfo.offlineMessage), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CartSheet(
        editMode: true,
        adminToken: token,
        transaksiId: widget.transaksi.id,
        initialItems: widget.transaksi.items,
        initialMetode: widget.transaksi.metodeBayar,
      ),
    );
  }

  void _batalkan() async {
    final token = ref.read(adminTokenProvider);
    if (token == null) {
      _handleSessionExpired();
      return;
    }

    final hasInternet = await NetworkInfo.isConnected();
    if (!hasInternet) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(NetworkInfo.offlineMessage), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Batalkan Transaksi'),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan transaksi ini?\n\n'
          'Status transaksi akan diubah menjadi Batal dan tidak dihitung ke total penjualan. Tindakan ini tidak bisa diurungkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final svc = ref.read(supabaseServiceProvider);
      await svc.adminBatalkanTransaksi(
        token: token,
        id: widget.transaksi.id,
      );

      ref.invalidate(adminRiwayatProvider);
      ref.invalidate(adminRingkasanProvider);
      ref.invalidate(hariIniProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil dibatalkan')),
        );
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('SESI_TIDAK_VALID')) {
        _handleSessionExpired();
        return;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errStr.replaceAll('Exception:', '').trim()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleSessionExpired() {
    ref.read(adminTokenProvider.notifier).clearToken();
    if (mounted) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaksi;
    final isBatal = t.status == 'batal';
    final isDiedit = t.dieditAt != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.45,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet Drag Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7C2B9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                AppFormat.dateTime(t.createdAt.toLocal()),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              if (isBatal)
                                _badge('Batal', Colors.red)
                              else if (isDiedit)
                                _badge('Diedit', Colors.orange),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Metode: ${t.metodeBayar.toUpperCase()}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6E5A4F)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormat.currency(t.total),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isBatal ? Colors.grey : AppTheme.primary,
                            decoration: isBatal ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 24),

              // Rincian Item Pesanan
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Item Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6E5A4F))),
                    Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6E5A4F))),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: t.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (_, idx) {
                    final item = t.items[idx];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE5D4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${item.qty}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C4A2D),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.namaMenu,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isBatal ? Colors.grey : Colors.black87,
                                  decoration: isBatal ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              Text(
                                '${AppFormat.currency(item.hargaSatuan)} / pcs',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          AppFormat.currency(item.subtotal),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isBatal ? Colors.grey : Colors.black87,
                            decoration: isBatal ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Action Buttons / Status footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: isBatal
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'Transaksi ini telah dibatalkan',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          // Edit Button
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _edit,
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  side: const BorderSide(color: AppTheme.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Batalkan Button
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _batalkan,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.cancel_outlined),
                                label: const Text('Batalkan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
