import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/network_info.dart';
import '../../../../data/models/admin_menu_item.dart';
import '../../../../providers/admin_provider.dart';
import '../../../../providers/kategori_provider.dart';
import '../../../../providers/menu_provider.dart';
import '../../../../providers/supabase_provider.dart';
import '../../pin_gate.dart';

class MenuFormSheet extends ConsumerStatefulWidget {
  final AdminMenuItem? menuItem;
  final String? defaultKategoriId;

  const MenuFormSheet({super.key, this.menuItem, this.defaultKategoriId});

  @override
  ConsumerState<MenuFormSheet> createState() => _MenuFormSheetState();
}

class _MenuFormSheetState extends ConsumerState<MenuFormSheet> {
  late final TextEditingController _namaController;
  late final TextEditingController _hargaController;
  String? _selectedKategoriId;
  late bool _isAktif;
  bool _isLoading = false;
  String? _errorMessage;

  Uint8List? _imageBytes;
  String? _imageExtension;
  String? _currentFotoUrl;
  bool _removeFoto = false;

  bool get _isEdit => widget.menuItem != null;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.menuItem?.nama ?? '');
    _hargaController = TextEditingController(
      text: widget.menuItem != null ? widget.menuItem!.harga.toString() : '',
    );
    _selectedKategoriId = widget.menuItem?.kategoriId ?? widget.defaultKategoriId;
    _isAktif = widget.menuItem?.aktif ?? true;
    _currentFotoUrl = widget.menuItem?.fotoUrl;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last;
        setState(() {
          _imageBytes = bytes;
          _imageExtension = ext;
          _removeFoto = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih gambar: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.burgundy),
              title: const Text('Pilih dari Galeri', style: TextStyle(color: AppColors.textDark)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.burgundy),
              title: const Text('Ambil Foto Kamera', style: TextStyle(color: AppColors.textDark)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simpan() async {
    final token = ref.read(adminTokenProvider);
    if (token == null) {
      _handleSessionExpired();
      return;
    }

    final hasInternet = await NetworkInfo.isConnected();
    if (!hasInternet) {
      if (mounted) {
        setState(() => _errorMessage = NetworkInfo.offlineMessage);
      }
      return;
    }

    final nama = _namaController.text.trim();
    if (nama.isEmpty) {
      setState(() => _errorMessage = 'Nama menu wajib diisi');
      return;
    }

    final hargaText = _hargaController.text.trim().replaceAll('.', '').replaceAll(',', '');
    final harga = int.tryParse(hargaText);
    if (harga == null || harga < 0 || harga > 1000000) {
      setState(() => _errorMessage = 'Harga tidak valid (0 sampai 1.000.000)');
      return;
    }

    if (_selectedKategoriId == null || _selectedKategoriId!.isEmpty) {
      setState(() => _errorMessage = 'Pilih kategori terlebih dahulu');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final svc = ref.read(supabaseServiceProvider);

      String? finalFotoUrl = _currentFotoUrl;
      if (_imageBytes != null && _imageExtension != null) {
        finalFotoUrl = await svc.uploadFotoMenu(
          bytes: _imageBytes!,
          fileExtension: _imageExtension!,
        );
      } else if (_removeFoto) {
        finalFotoUrl = null;
      }

      await svc.adminSimpanMenu(
        token: token,
        id: widget.menuItem?.id,
        nama: nama,
        harga: harga,
        kategoriId: _selectedKategoriId!,
        aktif: _isAktif,
        fotoUrl: finalFotoUrl,
      );

      // Invalidate providers so Kasir & Admin update immediately
      ref.invalidate(adminDaftarMenuProvider);
      ref.invalidate(menuProvider);
      ref.invalidate(kategoriProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Menu berhasil diubah' : 'Menu berhasil ditambahkan'),
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
        setState(() {
          _isLoading = false;
          _errorMessage = errStr.replaceAll('Exception:', '').trim();
        });
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
    final kategoriAsync = ref.watch(kategoriProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Grabber
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit_note,
                          color: AppColors.burgundy,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isEdit ? 'Ubah Menu' : 'Tambah Menu Baru',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.burgundy,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: AppColors.cardBgSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 18, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Error notification banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Foto Menu
              const Text(
                'FOTO MENU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    // Preview Foto
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 72,
                        height: 72,
                        color: AppColors.gold.withValues(alpha: 0.15),
                        child: _imageBytes != null
                            ? Image.memory(
                                _imageBytes!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              )
                            : (_currentFotoUrl != null && !_removeFoto)
                                ? Image.network(
                                    _currentFotoUrl!,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => const Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.textDisabled,
                                      size: 32,
                                    ),
                                  )
                                : const Icon(
                                    Icons.restaurant_menu,
                                    color: AppColors.burgundy,
                                    size: 32,
                                  ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Action Buttons
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _showImageSourceDialog,
                            icon: Icon(
                              (_imageBytes != null || (_currentFotoUrl != null && !_removeFoto))
                                  ? Icons.change_circle_outlined
                                  : Icons.add_photo_alternate_outlined,
                              size: 16,
                            ),
                            label: Text(
                              (_imageBytes != null || (_currentFotoUrl != null && !_removeFoto))
                                  ? 'Ganti Foto'
                                  : 'Pilih Foto',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.burgundy,
                              foregroundColor: AppColors.cream,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: const Size(0, 34),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          if (_imageBytes != null || (_currentFotoUrl != null && !_removeFoto)) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _imageBytes = null;
                                        _imageExtension = null;
                                        _currentFotoUrl = null;
                                        _removeFoto = true;
                                      });
                                    },
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                child: Text(
                                  'Hapus Foto',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Nama Menu Input
              const Text(
                'NAMA MENU',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardBgSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: TextField(
                    controller: _namaController,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Bandrek Original Jahe Merah',
                      hintStyle: TextStyle(fontSize: 14, color: AppColors.textMuted),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Harga Jual (Rp) Input
              const Text(
                'HARGA JUAL (RP)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardBgSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Rp',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.burgundy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _hargaController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(fontSize: 16, color: AppColors.textMuted),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Kategori Dropdown
              const Text(
                'KATEGORI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              kategoriAsync.when(
                data: (kategoris) {
                  if (_selectedKategoriId == null && kategoris.isNotEmpty) {
                    _selectedKategoriId = kategoris.first.id;
                  }
                  return Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedKategoriId,
                        isExpanded: true,
                        dropdownColor: AppColors.cardBg,
                        hint: const Text('Pilih Kategori', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                        items: kategoris.map((k) {
                          return DropdownMenuItem<String>(
                            value: k.id,
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
                                const SizedBox(width: 10),
                                Text(
                                  k.nama,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedKategoriId = val);
                          }
                        },
                      ),
                    ),
                  );
                },
                loading: () => Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.cardBgSecondary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.burgundy),
                    ),
                  ),
                ),
                error: (err, _) => Text(
                  'Gagal memuat kategori: $err',
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),

              const SizedBox(height: 18),

              // Status Toggle (Aktif di Kasir)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardBgSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Tampilkan & Aktif di Kasir',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Menu dapat langsung dipilih kasir saat shift berjalan',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isAktif,
                      activeThumbColor: AppColors.gold,
                      activeTrackColor: AppColors.burgundy,
                      inactiveThumbColor: AppColors.textDisabled,
                      inactiveTrackColor: AppColors.cardBg,
                      onChanged: (val) => setState(() => _isAktif = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _simpan,
                        icon: _isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppColors.cream, strokeWidth: 2))
                            : const Icon(Icons.check, size: 18),
                        label: Text(
                          _isEdit ? 'Simpan Perubahan' : 'Simpan Menu',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.burgundy,
                          foregroundColor: AppColors.cream,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
