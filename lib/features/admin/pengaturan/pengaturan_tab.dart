import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network_info.dart';
import '../../../core/theme.dart';
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
          backgroundColor: Colors.red,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing != null ? 'Ubah Kategori' : 'Tambah Kategori',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dialogError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF0E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF6C9BA)),
                  ),
                  child: Text(
                    dialogError!,
                    style: const TextStyle(color: Color(0xFFC84C32), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Nama Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: namaCtrl,
                decoration: InputDecoration(
                  hintText: 'Contoh: Makanan, Minuman',
                  filled: true,
                  fillColor: const Color(0xFFFCF5EE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEBDCD0)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Nomor Urutan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: urutanCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '0',
                  filled: true,
                  fillColor: const Color(0xFFFCF5EE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFEBDCD0)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Batal'),
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
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
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
          const SnackBar(content: Text(NetworkInfo.offlineMessage), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Apakah Anda yakin ingin menghapus kategori "${kategori.nama}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
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
            backgroundColor: Colors.red,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ubah PIN Admin', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dialogError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF0E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF6C9BA)),
                    ),
                    child: Text(
                      dialogError!,
                      style: const TextStyle(color: Color(0xFFC84C32), fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('PIN Lama', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: lamaCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '6 digit PIN saat ini',
                    filled: true,
                    fillColor: const Color(0xFFFCF5EE),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEBDCD0)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('PIN Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: baruCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '6 digit angka baru',
                    filled: true,
                    fillColor: const Color(0xFFFCF5EE),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEBDCD0)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Konfirmasi PIN Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: konfirmasiCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Ulangi 6 digit PIN baru',
                    filled: true,
                    fillColor: const Color(0xFFFCF5EE),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFEBDCD0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dCtx),
              child: const Text('Batal'),
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
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
        title: const Text('Keluar dari Mode Admin'),
        content: const Text('Apakah Anda yakin ingin keluar dari Mode Admin dan kembali ke Kasir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Keluar'),
          ),
        ],
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
      backgroundColor: const Color(0xFFF9EFE6),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Pengaturan Admin', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4A2D).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
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
                            Icon(Icons.category_outlined, color: AppTheme.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Kelola Kategori',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D1F17)),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => _showKategoriDialog(),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tambah'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  kategoriAsync.when(
                    data: (kategoris) {
                      if (kategoris.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('Belum ada kategori.')),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: kategoris.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final k = kategoris[idx];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE5D4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${k.urutan}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13),
                                ),
                              ),
                            ),
                            title: Text(k.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                                  onPressed: () => _showKategoriDialog(k),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
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
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Gagal memuat kategori: $err', style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section 2: Keamanan (Ubah PIN)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4A2D).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE5D4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pin_outlined, color: AppTheme.primary, size: 22),
                ),
                title: const Text('Ubah PIN Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Ganti 6 digit PIN untuk akses admin', style: TextStyle(fontSize: 12, color: Color(0xFF6E5A4F))),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFB39E91)),
                onTap: _showUbahPinDialog,
              ),
            ),

            const SizedBox(height: 24),

            // Section 3: Tombol Keluar Admin
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _keluarAdmin,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Keluar dari Mode Admin',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.white,
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
