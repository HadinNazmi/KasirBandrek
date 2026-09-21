class LogAktivitasItem {
  final String id;
  final DateTime createdAt;
  final String aktor; // 'kasir' / 'admin'
  final String tipeAksi; // 'TRANSAKSI_BARU', 'BATAL_TRANSAKSI', 'UBAH_TRANSAKSI', 'TAMBAH_MENU', dll.
  final String judul;
  final String? rincian;
  final Map<String, dynamic>? dataJson;

  const LogAktivitasItem({
    required this.id,
    required this.createdAt,
    required this.aktor,
    required this.tipeAksi,
    required this.judul,
    this.rincian,
    this.dataJson,
  });

  factory LogAktivitasItem.fromJson(Map<String, dynamic> json) {
    return LogAktivitasItem(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      aktor: json['aktor'] as String? ?? 'kasir',
      tipeAksi: json['tipe_aksi'] as String? ?? 'LAINNYA',
      judul: json['judul'] as String? ?? 'Aktivitas',
      rincian: json['rincian'] as String?,
      dataJson: json['data_json'] as Map<String, dynamic>?,
    );
  }
}
