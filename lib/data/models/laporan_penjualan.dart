import 'transaksi.dart';

class LaporanRingkasan {
  final int totalPenjualan;
  final int jumlahTransaksi;
  final int jumlahBatal;
  final int tunaiJumlah;
  final int tunaiTotal;
  final int qrisJumlah;
  final int qrisTotal;

  const LaporanRingkasan({
    required this.totalPenjualan,
    required this.jumlahTransaksi,
    required this.jumlahBatal,
    required this.tunaiJumlah,
    required this.tunaiTotal,
    required this.qrisJumlah,
    required this.qrisTotal,
  });

  int get rataRataTransaksi =>
      jumlahTransaksi > 0 ? (totalPenjualan / jumlahTransaksi).round() : 0;

  factory LaporanRingkasan.fromJson(Map<String, dynamic> json) {
    final tunai = json['tunai'] as Map<String, dynamic>? ?? {};
    final qris = json['qris'] as Map<String, dynamic>? ?? {};

    return LaporanRingkasan(
      totalPenjualan: (json['total_penjualan'] as num?)?.toInt() ?? 0,
      jumlahTransaksi: (json['jumlah_transaksi'] as num?)?.toInt() ?? 0,
      jumlahBatal: (json['jumlah_batal'] as num?)?.toInt() ?? 0,
      tunaiJumlah: (tunai['jumlah'] as num?)?.toInt() ?? 0,
      tunaiTotal: (tunai['total'] as num?)?.toInt() ?? 0,
      qrisJumlah: (qris['jumlah'] as num?)?.toInt() ?? 0,
      qrisTotal: (qris['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class LaporanHarianItem {
  final DateTime tanggal;
  final int total;
  final int jumlahTransaksi;

  const LaporanHarianItem({
    required this.tanggal,
    required this.total,
    required this.jumlahTransaksi,
  });

  factory LaporanHarianItem.fromJson(Map<String, dynamic> json) {
    return LaporanHarianItem(
      tanggal: DateTime.parse(json['tanggal'] as String),
      total: (json['total'] as num?)?.toInt() ?? 0,
      jumlahTransaksi: (json['jumlah_transaksi'] as num?)?.toInt() ?? 0,
    );
  }
}

class LaporanPenjualan {
  final LaporanRingkasan ringkasan;
  final List<LaporanHarianItem> harian;
  final List<Transaksi> transaksi;

  const LaporanPenjualan({
    required this.ringkasan,
    required this.harian,
    required this.transaksi,
  });

  factory LaporanPenjualan.fromJson(Map<String, dynamic> json) {
    final ringkasanData = json['ringkasan'] as Map<String, dynamic>? ?? {};
    final harianList = (json['harian'] as List<dynamic>? ?? [])
        .map((e) => LaporanHarianItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final transaksiList = (json['transaksi'] as List<dynamic>? ?? [])
        .map((e) => Transaksi.fromJson(e as Map<String, dynamic>))
        .toList();

    return LaporanPenjualan(
      ringkasan: LaporanRingkasan.fromJson(ringkasanData),
      harian: harianList,
      transaksi: transaksiList,
    );
  }
}
