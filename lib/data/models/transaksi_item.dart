class TransaksiItem {
  final String namaMenu;
  final int hargaSatuan;
  final int qty;
  final int subtotal;

  TransaksiItem({
    required this.namaMenu,
    required this.hargaSatuan,
    required this.qty,
    required this.subtotal,
  });

  factory TransaksiItem.fromJson(Map<String, dynamic> json) {
    return TransaksiItem(
      namaMenu: json['nama_menu'] as String,
      hargaSatuan: json['harga_satuan'] as int,
      qty: json['qty'] as int,
      subtotal: json['subtotal'] as int? ?? (json['harga_satuan'] as int) * (json['qty'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nama_menu': namaMenu,
      'harga_satuan': hargaSatuan,
      'qty': qty,
      'subtotal': subtotal,
    };
  }
}
