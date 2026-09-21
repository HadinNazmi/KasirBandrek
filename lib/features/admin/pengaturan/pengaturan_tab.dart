import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_colors.dart';
import '../../../core/network_info.dart';
import '../../../data/models/kategori.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/kategori_provider.dart';
import '../../../providers/menu_provider.dart';
import '../../../providers/supabase_provider.dart';
import '../pin_gate.dart';

class PengaturanTab extends ConsumerStatefulWidget {
  const PengaturanTab({super.key});

  @override
  ConsumerState<PengaturanTab> createState() => _PengaturanTabState();
}

class _PengaturanTabState extends ConsumerState<PengaturanTab> {
  bool _isLoading = false;

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

  // =====================================================================
  // KELOLA KATEGORI
  // =====================================================================

  void _showKategoriDialog([Kategori? existing]) {
    final namaCtrl = TextEditingController(text: existing?.nama ?? '');
    final urutanCtrl = TextEditingController(
      text: existing != null ? existing.urutan.toString() : '0',
    );
    String? dialogError;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing != null ? 'Ubah Kategori' : 'Tambah Kategori',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dialogError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    dialogError!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Nama Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: namaCtrl,
                style: const TextStyle(color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: 'Contoh: Makanan, Minuman',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardBgSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Nomor Urutan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
              const SizedBox(height: 6),
              TextField(
                controller: urutanCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppColors.textDark),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardBgSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final token = ref.read(adminTokenProvider);
                if (token == null) {
                  Navigator.pop(dCtx);
                  _handleSessionExpired();
                  return;
                }

                final hasInternet = await NetworkInfo.isConnected();
                if (!hasInternet) {
                  setDialogState(() => dialogError = NetworkInfo.offlineMessage);
                  return;
                }

                final nama = namaCtrl.text.trim();
                if (nama.isEmpty) {
                  setDialogState(() => dialogError = 'Nama kategori wajib diisi');
                  return;
                }

                final urutan = int.tryParse(urutanCtrl.text.trim()) ?? 0;

                try {
                  final svc = ref.read(supabaseServiceProvider);
                  await svc.adminSimpanKategori(
                    token: token,
                    id: existing?.id,
                    nama: nama,
                    urutan: urutan,
                  );

                  ref.invalidate(kategoriProvider);
                  ref.invalidate(menuProvider);
                  ref.invalidate(adminDaftarMenuProvider);

                  if (dCtx.mounted) Navigator.pop(dCtx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(existing != null ? 'Kategori berhasil diubah' : 'Kategori berhasil ditambahkan')),
                    );
                  }
                } catch (e) {
                  final errStr = e.toString();
                  if (errStr.contains('SESI_TIDAK_VALID')) {
                    if (dCtx.mounted) Navigator.pop(dCtx);
                    _handleSessionExpired();
                    return;
                  }
                  setDialogState(() {
                    dialogError = errStr.replaceAll('Exception:', '').trim();
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.cream,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _hapusKategori(Kategori kategori) async {
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

    if (!mounted) return;
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
              'Hapus Kategori',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Apakah Anda yakin ingin menghapus kategori "${kategori.nama}"?',
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

    if (confirm != true || !mounted) return;

    try {
      final svc = ref.read(supabaseServiceProvider);
      await svc.adminHapusKategori(token: token, id: kategori.id);

      ref.invalidate(kategoriProvider);
      ref.invalidate(menuProvider);
      ref.invalidate(adminDaftarMenuProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kategori berhasil dihapus')),
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

  // =====================================================================
  // UBAH PIN ADMIN
  // =====================================================================

  void _showUbahPinDialog() {
    final lamaCtrl = TextEditingController();
    final baruCtrl = TextEditingController();
    final konfirmasiCtrl = TextEditingController();
    String? dialogError;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Ubah PIN Admin',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                if (dialogError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      dialogError!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('PIN Lama', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: lamaCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textDark),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '6 digit PIN saat ini',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.cardBgSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('PIN Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: baruCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textDark),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '6 digit angka baru',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.cardBgSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Konfirmasi PIN Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark)),
                const SizedBox(height: 6),
                TextField(
                  controller: konfirmasiCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textDark),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Ulangi 6 digit PIN baru',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.cardBgSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dCtx),
              child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final token = ref.read(adminTokenProvider);
                      if (token == null) {
                        Navigator.pop(dCtx);
                        _handleSessionExpired();
                        return;
                      }

                      final hasInternet = await NetworkInfo.isConnected();
                      if (!hasInternet) {
                        setDialogState(() => dialogError = NetworkInfo.offlineMessage);
                        return;
                      }

                      final pinLama = lamaCtrl.text.trim();
                      final pinBaru = baruCtrl.text.trim();
                      final konfirmasi = konfirmasiCtrl.text.trim();

                      if (pinLama.isEmpty) {
                        setDialogState(() => dialogError = 'PIN lama wajib diisi');
                        return;
                      }
                      if (pinBaru.length != 6) {
                        setDialogState(() => dialogError = 'PIN baru harus 6 digit angka');
                        return;
                      }
                      if (pinBaru != konfirmasi) {
                        setDialogState(() => dialogError = 'Konfirmasi PIN baru tidak cocok');
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                        dialogError = null;
                      });

                      try {
                        final svc = ref.read(supabaseServiceProvider);
                        await svc.adminUbahPin(
                          token: token,
                          pinLama: pinLama,
                          pinBaru: pinBaru,
                        );

                        if (dCtx.mounted) Navigator.pop(dCtx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PIN Admin berhasil diubah')),
                          );
                        }
                      } catch (e) {
                        final errStr = e.toString();
                        if (errStr.contains('SESI_TIDAK_VALID')) {
                          if (dCtx.mounted) Navigator.pop(dCtx);
                          _handleSessionExpired();
                          return;
                        }
                        setDialogState(() {
                          isSaving = false;
                          dialogError = errStr.replaceAll('Exception:', '').trim();
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.cream,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cream))
                  : const Text('Simpan PIN'),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // KELUAR ADMIN
  // =====================================================================

  void _keluarAdmin() async {
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
              child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Keluar dari Mode Admin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Apakah Anda yakin ingin keluar dari Mode Admin dan kembali ke Kasir?',
              style: TextStyle(
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
                      'Keluar',
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

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);

    final token = ref.read(adminTokenProvider);
    if (token != null) {
      try {
        final svc = ref.read(supabaseServiceProvider);
        await svc.adminKeluar(token);
      } catch (_) {
        // Abaikan error jaringan saat logout, token lokal tetap dihapus
      }
    }

    ref.read(adminTokenProvider.notifier).clearToken();

    if (mounted) {
      Navigator.of(context).pop(); // Kembali ke KasirLayout
    }
  }

  @override
  Widget build(BuildContext context) {
    final kategoriAsync = ref.watch(kategoriProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Pengaturan Admin',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.cream,
          ),
        ),
        backgroundColor: AppColors.appBarBg,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Kelola Kategori
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.category_outlined, color: AppColors.burgundy, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Kelola Kategori',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => _showKategoriDialog(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tambah'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.burgundy,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  kategoriAsync.when(
                    data: (kategoris) {
                      if (kategoris.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('Belum ada kategori.', style: TextStyle(color: AppColors.textMuted))),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: kategoris.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, idx) {
                          final k = kategoris[idx];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${k.urutan}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.burgundy, fontSize: 13),
                                ),
                              ),
                            ),
                            title: Text(k.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.burgundy),
                                  onPressed: () => _showKategoriDialog(k),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                  onPressed: () => _hapusKategori(k),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(color: AppColors.burgundy)),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Gagal memuat kategori: $err', style: const TextStyle(color: AppColors.error)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section 2: Keamanan (Ubah PIN)
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pin_outlined, color: AppColors.burgundy, size: 22),
                  ),
                  title: const Text('Ubah PIN Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
                  subtitle: const Text('Ganti 6 digit PIN untuk akses admin', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  onTap: _showUbahPinDialog,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section 3: Tombol Keluar Admin
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _keluarAdmin,
                icon: const Icon(Icons.logout, color: AppColors.error),
                label: const Text(
                  'Keluar dari Mode Admin',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: AppColors.cardBg,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
