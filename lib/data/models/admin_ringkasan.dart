class MetodeRingkasan {
  final int jumlah;
  final int total;

  MetodeRingkasan({
    required this.jumlah,
    required this.total,
  });

  factory MetodeRingkasan.fromJson(Map<String, dynamic> json) {
    return MetodeRingkasan(
      jumlah: (json['jumlah'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminRingkasan {
  final int totalPenjualan;
  final int jumlahTransaksi;
  final int jumlahBatal;
  final MetodeRingkasan tunai;
  final MetodeRingkasan qris;

  AdminRingkasan({
    required this.totalPenjualan,
    required this.jumlahTransaksi,
    required this.jumlahBatal,
    required this.tunai,
    required this.qris,
  });

  factory AdminRingkasan.fromJson(Map<String, dynamic> json) {
    return AdminRingkasan(
      totalPenjualan: (json['total_penjualan'] as num?)?.toInt() ?? 0,
      jumlahTransaksi: (json['jumlah_transaksi'] as num?)?.toInt() ?? 0,
      jumlahBatal: (json['jumlah_batal'] as num?)?.toInt() ?? 0,
      tunai: MetodeRingkasan.fromJson(json['tunai'] as Map<String, dynamic>? ?? {}),
      qris: MetodeRingkasan.fromJson(json['qris'] as Map<String, dynamic>? ?? {}),
    );
  }
}
