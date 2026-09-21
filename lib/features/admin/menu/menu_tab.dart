import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/format.dart';
import '../../../core/network_info.dart';
import '../../../core/theme.dart';
import '../../../data/models/admin_menu_item.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/menu_provider.dart';
import '../../../providers/supabase_provider.dart';
import '../pin_gate.dart';
import 'widgets/menu_form_sheet.dart';

class MenuTab extends ConsumerStatefulWidget {
  const MenuTab({super.key});

  @override
  ConsumerState<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends ConsumerState<MenuTab> {
  final Set<String> _togglingIds = {};

  void _openForm([AdminMenuItem? item]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MenuFormSheet(menuItem: item),
    );
  }

  Future<void> _toggleStatus(AdminMenuItem item) async {
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

    setState(() => _togglingIds.add(item.id));

    try {
      final svc = ref.read(supabaseServiceProvider);
      await svc.adminSimpanMenu(
        token: token,
        id: item.id,
        nama: item.nama,
        harga: item.harga,
        kategoriId: item.kategoriId!,
        aktif: !item.aktif,
      );

      ref.invalidate(adminDaftarMenuProvider);
      ref.invalidate(menuProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              item.aktif ? '${item.nama} dinonaktifkan di kasir' : '${item.nama} diaktifkan di kasir',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('SESI_TIDAK_VALID')) {
        _handleSessionExpired();
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errStr.replaceAll('Exception:', '').trim()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingIds.remove(item.id));
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
    final menuAsync = ref.watch(adminDaftarMenuProvider);

    menuAsync.whenOrNull(error: (e, _) {
      if (e is SessionExpiredException || e.toString().contains('SESI_TIDAK_VALID')) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleSessionExpired());
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF9EFE6),
      appBar: AppBar(
        title: const Text('Kelola Menu', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminDaftarMenuProvider),
        child: menuAsync.when(
          data: (menus) {
            if (menus.isEmpty) {
              return const Center(
                child: Text('Belum ada menu terdaftar. Silakan tambah menu baru.'),
              );
            }

            // Group menus by category
            final Map<String, List<AdminMenuItem>> grouped = {};
            for (final m in menus) {
              final catName = m.kategoriNama ?? 'Lainnya';
              grouped.putIfAbsent(catName, () => []).add(m);
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: grouped.keys.length,
              itemBuilder: (context, catIdx) {
                final categoryName = grouped.keys.elementAt(catIdx);
                final items = grouped[categoryName]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Header Pill
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            categoryName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D1F17),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${items.length})',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF84746C)),
                          ),
                        ],
                      ),
                    ),

                    // Menu cards in category
                    ...items.map((item) => _buildMenuCard(item)),
                    const SizedBox(height: 12),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 8),
                Text(err.toString().replaceAll('Exception:', '').trim()),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(adminDaftarMenuProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(AdminMenuItem item) {
    final isToggling = _togglingIds.contains(item.id);
    final isNonaktif = !item.aktif;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isNonaktif ? 0.8 : 1.0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNonaktif ? const Color(0xFFD7C2B9).withValues(alpha: 0.5) : const Color(0xFFEBDCD0).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4A2D).withValues(alpha: isNonaktif ? 0.02 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon thumbnail with warm styling
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isNonaktif ? Colors.grey.shade200 : const Color(0xFFFEE5D4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_cafe_rounded,
                color: isNonaktif ? Colors.grey : AppTheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Name, Category & Price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.nama,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isNonaktif ? Colors.grey.shade600 : const Color(0xFF2D1F17),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isNonaktif) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDAD6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Nonaktif',
                            style: TextStyle(color: Color(0xFFBA1A1A), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppFormat.currency(item.harga),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isNonaktif ? Colors.grey : AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle Switch & Edit Button
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Switch Active Toggle
                if (isToggling)
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Switch(
                    value: item.aktif,
                    activeThumbColor: AppTheme.secondary,
                    onChanged: (_) => _toggleStatus(item),
                  ),
                const SizedBox(width: 4),

                // Edit Button
                InkWell(
                  onTap: () => _openForm(item),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0E7DE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
