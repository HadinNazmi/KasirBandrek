import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_colors.dart';
import '../../../core/format.dart';
import '../../../core/network_info.dart';
import '../../../data/models/admin_menu_item.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/kategori_provider.dart';
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

  void _openForm([AdminMenuItem? item, String? defaultKategoriId]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MenuFormSheet(
        menuItem: item,
        defaultKategoriId: defaultKategoriId,
      ),
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
          const SnackBar(content: Text(NetworkInfo.offlineMessage), backgroundColor: AppColors.error),
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
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingIds.remove(item.id));
      }
    }
  }

  Future<void> _confirmHapusMenu(AdminMenuItem item) async {
    final token = ref.read(adminTokenProvider);
    if (token == null) {
      _handleSessionExpired();
      return;
    }

    final hasInternet = await NetworkInfo.isConnected();
    if (!mounted) return;
    if (!hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(NetworkInfo.offlineMessage), backgroundColor: AppColors.error),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.cardBg,
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.errorBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hapus Menu',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Apakah Anda yakin ingin menghapus "${item.nama}" secara permanen?',
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textMuted,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dCtx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      backgroundColor: AppColors.cardBgSecondary,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dCtx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.cream,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Hapus',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final svc = ref.read(supabaseServiceProvider);
      await svc.adminHapusMenu(token: token, id: item.id);

      ref.invalidate(adminDaftarMenuProvider);
      ref.invalidate(menuProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Menu "${item.nama}" berhasil dihapus')),
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
            backgroundColor: AppColors.error,
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
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(adminDaftarMenuProvider);
    final kategoriAsync = ref.watch(kategoriProvider);

    menuAsync.whenOrNull(error: (e, _) {
      if (e is SessionExpiredException || e.toString().contains('SESI_TIDAK_VALID')) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleSessionExpired());
      }
    });

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Kelola Menu',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.cream,
          ),
        ),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.cream,
                elevation: 0,
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.burgundy,
        foregroundColor: AppColors.cream,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Menu Baru', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        color: AppColors.burgundy,
        onRefresh: () async {
          ref.invalidate(adminDaftarMenuProvider);
          ref.invalidate(kategoriProvider);
        },
        child: menuAsync.when(
          data: (menus) {
            final kategoris = kategoriAsync.value ?? [];

            // Group menus by category
            final List<Map<String, dynamic>> categorySections = [];
            final Set<String> processedCatIds = {};

            for (final cat in kategoris) {
              processedCatIds.add(cat.id);
              final items = menus.where((m) => m.kategoriId == cat.id).toList();
              categorySections.add({
                'id': cat.id,
                'name': cat.nama,
                'items': items,
              });
            }

            // Also check if any menu has no category or a category not in kategoris
            final otherMenus = menus.where((m) => m.kategoriId == null || !processedCatIds.contains(m.kategoriId)).toList();
            if (otherMenus.isNotEmpty) {
              categorySections.add({
                'id': null,
                'name': 'Lainnya',
                'items': otherMenus,
              });
            }

            if (categorySections.isEmpty && menus.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.restaurant_menu, size: 56, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada menu terdaftar.',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Menu Sekarang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        foregroundColor: AppColors.cream,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: categorySections.length,
              itemBuilder: (context, catIdx) {
                final section = categorySections[catIdx];
                final categoryId = section['id'] as String?;
                final categoryName = section['name'] as String;
                final items = section['items'] as List<AdminMenuItem>;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Header Pill + Add Button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            categoryName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${items.length})',
                            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _openForm(null, categoryId),
                            icon: const Icon(Icons.add, size: 15, color: AppColors.burgundy),
                            label: Text(
                              '+ Tambah $categoryName',
                              style: const TextStyle(color: AppColors.burgundy, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 30),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (items.isEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Belum ada menu di kategori $categoryName',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _openForm(null, categoryId),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text('Tambah'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.burgundy,
                                side: const BorderSide(color: AppColors.burgundy),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(0, 30),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...items.map((item) => _buildMenuCard(item)),

                    const SizedBox(height: 12),
                  ],
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.burgundy),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 40),
                const SizedBox(height: 8),
                Text(
                  err.toString().replaceAll('Exception:', '').trim(),
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.cream,
                  ),
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
        color: isNonaktif ? AppColors.cardBg.withValues(alpha: 0.8) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNonaktif ? AppColors.border.withValues(alpha: 0.5) : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Photo / Icon thumbnail with warm styling
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isNonaktif ? AppColors.disabledBg : AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: (item.fotoUrl != null && item.fotoUrl!.isNotEmpty)
                    ? Image.network(
                        item.fotoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Icon(
                          Icons.local_cafe_rounded,
                          color: isNonaktif ? AppColors.textDisabled : AppColors.burgundy,
                          size: 24,
                        ),
                      )
                    : Icon(
                        Icons.local_cafe_rounded,
                        color: isNonaktif ? AppColors.textDisabled : AppColors.burgundy,
                        size: 24,
                      ),
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
                            color: isNonaktif ? AppColors.textDisabled : AppColors.textDark,
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
                            color: AppColors.errorBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Nonaktif',
                            style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold),
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
                      color: isNonaktif ? AppColors.textDisabled : AppColors.burgundy,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle Switch, Edit Button & Delete Button
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.burgundy),
                    ),
                  )
                else
                  Switch(
                    value: item.aktif,
                    activeThumbColor: AppColors.gold,
                    activeTrackColor: AppColors.burgundy,
                    inactiveThumbColor: AppColors.textDisabled,
                    inactiveTrackColor: AppColors.cardBgSecondary,
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
                      color: AppColors.cardBgSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.burgundy,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Delete Button
                InkWell(
                  onTap: () => _confirmHapusMenu(item),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.error,
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
