import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models/menu.dart';
import '../../data/models/transaksi.dart';
import '../../data/models/transaksi_item.dart';
import '../../data/transaksi_repository.dart';
import '../../providers/cart_provider.dart';
import '../../providers/kategori_provider.dart';
import '../../providers/menu_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/hari_ini_provider.dart';
import '../admin/pin_gate.dart';
import 'widgets/cart_sheet.dart';

class KasirScreen extends ConsumerStatefulWidget {
  const KasirScreen({super.key});

  @override
  ConsumerState<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends ConsumerState<KasirScreen> {
  String _selectedKategoriId = '';

  // State untuk notifikasi setelah simpan
  Transaksi? _lastSavedTransaksi;
  bool _showNotif = false;

  void _openCart(BuildContext ctx) async {
    final result = await showModalBottomSheet<String>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CartSheet(),
    );

    if (result == 'saved') {
      // Ambil transaksi terakhir dari hari ini untuk tombol Ubah/Batalkan
      ref.invalidate(hariIniProvider);
      final list = await ref.read(hariIniProvider.future);
      if (list.isNotEmpty && mounted) {
        setState(() {
          _lastSavedTransaksi = list.first;
          _showNotif = true;
        });

        // Auto-hide setelah 10 detik
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) setState(() => _showNotif = false);
        });
      }
    }
  }

  Future<void> _batalkanLast() async {
    if (_lastSavedTransaksi == null) return;
    try {
      if (_lastSavedTransaksi!.isPending) {
        await ref.read(transaksiRepositoryProvider).batalPending(_lastSavedTransaksi!.id);
      } else {
        final isOnline = ref.read(isOnlineProvider).value ?? true;
        if (!isOnline) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Butuh internet untuk mengubah transaksi yang sudah terkirim'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        final svc = ref.read(supabaseServiceProvider);
        await svc.kasirBatalkanTransaksi(id: _lastSavedTransaksi!.id);
      }
      ref.invalidate(hariIniProvider);
      if (mounted) {
        setState(() => _showNotif = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi dibatalkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception:', '').trim()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _ubahLast(BuildContext ctx) {
    if (_lastSavedTransaksi == null) return;
    final t = _lastSavedTransaksi!;
    setState(() => _showNotif = false);
    showModalBottomSheet(
      context: ctx,
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
  }

  @override
  Widget build(BuildContext context) {
    final kategoriAsync = ref.watch(kategoriProvider);
    final menuAsync = ref.watch(menuProvider);
    final cart = ref.watch(cartProvider);
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final pendingCount = ref.watch(pendingCountProvider);

    final totalItem = cart.fold(0, (sum, item) => sum + item.qty);
    final totalHarga = cart.fold(0, (sum, item) => sum + item.subtotal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kedai Bandrek', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Mode Admin',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PinGateScreen()),
              );
            },
          ),
          // Indikator Online/Offline & Belum Terkirim (Tap untuk sync)
          InkWell(
            onTap: () {
              ref.read(syncServiceProvider).sync();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isOnline
                        ? (pendingCount > 0 ? 'Menyinkronkan $pendingCount transaksi...' : 'Koneksi online dan data tersinkron')
                        : 'Mode offline. Antrean akan dikirim saat online.',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOnline ? Colors.black87 : Colors.orange.shade800,
                    ),
                  ),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount belum terkirim',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC84C32),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Filter kategori chips
              SizedBox(
                height: 60,
                child: kategoriAsync.when(
                  data: (kategoris) => ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      _buildKategoriChip('Semua', '', _selectedKategoriId == ''),
                      ...kategoris.map((k) => _buildKategoriChip(k.nama, k.id, _selectedKategoriId == k.id)),
                    ],
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),

              // Grid menu
              Expanded(
                child: menuAsync.when(
                  data: (menus) {
                    final filtered = _selectedKategoriId.isEmpty
                        ? menus
                        : menus.where((m) => m.kategoriId == _selectedKategoriId).toList();
                    if (filtered.isEmpty) {
                      return const Center(child: Text('Tidak ada menu di kategori ini.'));
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(menuProvider);
                        ref.invalidate(kategoriProvider);
                      },
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (_, index) => _buildMenuCard(filtered[index], cart),
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ),
            ],
          ),

          // Notifikasi Transaksi Tersimpan
          if (_showNotif && _lastSavedTransaksi != null)
            Positioned(
              bottom: totalItem > 0 ? 90 : 12,
              left: 16,
              right: 16,
              child: _buildNotifBar(context),
            ),

          // Bottom Summary Bar
          if (totalItem > 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), offset: const Offset(0, -4), blurRadius: 12)],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$totalItem item', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                            Text(
                              AppFormat.currency(totalHarga),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _openCart(context),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(130, 48)),
                        child: const Text('Lihat Pesanan', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Tombol simpan jika keranjang kosong (bisa tap area mana saja)
      floatingActionButton: totalItem == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openCart(context),
              backgroundColor: AppTheme.secondary,
              icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
              label: const Text('Pesanan', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildNotifBar(BuildContext ctx) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Transaksi tersimpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => _ubahLast(ctx),
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(48, 36),
              ),
              child: const Text('Ubah', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: _batalkanLast,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[200],
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(56, 36),
              ),
              child: const Text('Batalkan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKategoriChip(String label, String id, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedKategoriId = id),
        selectedColor: AppTheme.tertiary,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.onTertiary : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildMenuCard(Menu menu, List<TransaksiItem> cart) {
    final cartIndex = cart.indexWhere((item) => item.namaMenu == menu.nama);
    final qty = cartIndex >= 0 ? cart[cartIndex].qty : 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: qty > 0 ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: qty > 0
            ? const BorderSide(color: AppTheme.primary, width: 2)
            : BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: () => ref.read(cartProvider.notifier).addMenu(menu),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto menu
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (menu.fotoUrl != null && menu.fotoUrl!.isNotEmpty)
                    Image.network(
                      menu.fotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => _buildPlaceholderPhoto(),
                    )
                  else
                    _buildPlaceholderPhoto(),
                  // Badge jumlah di pojok kanan atas jika qty > 0
                  if (qty > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    menu.nama,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          AppFormat.currency(menu.harga),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (qty > 0)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4EBE3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2CCBA)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => ref.read(cartProvider.notifier).decrementQty(menu.nama),
                                  borderRadius: BorderRadius.circular(16),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.remove, size: 16, color: AppTheme.primary),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '$qty',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => ref.read(cartProvider.notifier).incrementQty(menu.nama),
                                  borderRadius: BorderRadius.circular(16),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.add, size: 16, color: AppTheme.primary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderPhoto() {
    return Container(
      color: const Color(0xFFF7EDE3),
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          color: Color(0xFFC7A896),
          size: 36,
        ),
      ),
    );
  }
}
