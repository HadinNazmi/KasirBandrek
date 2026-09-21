import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../data/models/transaksi_item.dart';
import '../../../data/transaksi_repository.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/hari_ini_provider.dart';
import '../../../providers/supabase_provider.dart';

/// Bottom sheet keranjang pesanan.
/// Dapat dipakai untuk pesanan baru (editMode = false)
/// maupun edit transaksi yang sudah ada (editMode = true).
class CartSheet extends ConsumerStatefulWidget {
  final bool editMode;
  final bool isLocalPending;
  final String? transaksiId;
  final List<TransaksiItem> initialItems;
  final String initialMetode;
  final String? adminToken;

  const CartSheet({
    super.key,
    this.editMode = false,
    this.isLocalPending = false,
    this.transaksiId,
    this.initialItems = const [],
    this.initialMetode = 'tunai',
    this.adminToken,
  });

  @override
  ConsumerState<CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends ConsumerState<CartSheet> {
  late List<TransaksiItem> _items;
  late String _metodeBayar;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _items = widget.editMode
        ? List.from(widget.initialItems)
        : List.from(ref.read(cartProvider));
    _metodeBayar = widget.initialMetode;
  }

  int get _totalHarga => _items.fold(0, (s, i) => s + i.subtotal);

  void _increment(int idx) {
    setState(() {
      final item = _items[idx];
      _items[idx] = TransaksiItem(
        namaMenu: item.namaMenu,
        hargaSatuan: item.hargaSatuan,
        qty: item.qty + 1,
        subtotal: item.hargaSatuan * (item.qty + 1),
      );
    });
  }

  void _decrement(int idx) {
    setState(() {
      final item = _items[idx];
      if (item.qty > 1) {
        _items[idx] = TransaksiItem(
          namaMenu: item.namaMenu,
          hargaSatuan: item.hargaSatuan,
          qty: item.qty - 1,
          subtotal: item.hargaSatuan * (item.qty - 1),
        );
      } else {
        _items.removeAt(idx);
      }
    });
  }

  void _remove(int idx) {
    setState(() {
      _items.removeAt(idx);
    });
  }

  Future<void> _simpan() async {
    if (_items.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      if (widget.editMode) {
        if (widget.isLocalPending) {
          final repo = ref.read(transaksiRepositoryProvider);
          await repo.editPending(
            id: widget.transaksiId!,
            metode: _metodeBayar,
            items: _items,
          );
        } else {
          final svc = ref.read(supabaseServiceProvider);
          if (widget.adminToken != null) {
            await svc.adminEditTransaksi(
              token: widget.adminToken!,
              id: widget.transaksiId!,
              metode: _metodeBayar,
              items: _items,
            );
            ref.invalidate(adminRiwayatProvider);
            ref.invalidate(adminRingkasanProvider);
          } else {
            await svc.kasirEditTransaksi(
              id: widget.transaksiId!,
              metode: _metodeBayar,
              items: _items,
            );
          }
        }
        ref.invalidate(hariIniProvider);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transaksi berhasil diubah')),
          );
        }
      } else {
        final repo = ref.read(transaksiRepositoryProvider);
        await repo.simpan(metode: _metodeBayar, items: _items);
        ref.read(cartProvider.notifier).clear();
        ref.invalidate(hariIniProvider);
        if (mounted) {
          Navigator.pop(context, 'saved');
        }
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('SESI_TIDAK_VALID')) {
        ref.read(adminTokenProvider.notifier).clearToken();
        if (mounted) {
          Navigator.pop(context, false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi admin telah berakhir. Silakan masuk kembali.'),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      widget.editMode ? 'Edit Pesanan' : 'Pesanan',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (!widget.editMode && _items.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          ref.read(cartProvider.notifier).clear();
                          setState(() => _items.clear());
                        },
                        child: const Text('Kosongkan', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Daftar item
              Expanded(
                child: _items.isEmpty
                    ? const Center(child: Text('Pesanan kosong', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) => _buildItemRow(_items[idx], idx),
                      ),
              ),

              // Metode bayar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const Text('Metode Bayar', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(children: [
                      _buildMetodeChip('Tunai', 'tunai'),
                      const SizedBox(width: 8),
                      _buildMetodeChip('QRIS', 'qris'),
                    ]),
                  ],
                ),
              ),

              // Total + Simpan
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 16)),
                        Text(
                          AppFormat.currency(_totalHarga),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: (_items.isEmpty || _isLoading) ? null : _simpan,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              widget.editMode ? 'Simpan Perubahan' : 'Simpan Transaksi',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemRow(TransaksiItem item, int idx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppTheme.neutral, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _remove(idx),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 16, color: Colors.red),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.namaMenu, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(AppFormat.currency(item.hargaSatuan), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Row(children: [
            _qtyButton(Icons.remove, () => _decrement(idx)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${item.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            _qtyButton(Icons.add, () => _increment(idx)),
          ]),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: AppTheme.tertiary, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: AppTheme.primary),
      ),
    );
  }

  Widget _buildMetodeChip(String label, String value) {
    final isSelected = _metodeBayar == value;
    return GestureDetector(
      onTap: () => setState(() => _metodeBayar = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.neutral,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
