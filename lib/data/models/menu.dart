class Menu {
  final String id;
  final String? kategoriId;
  final String nama;
  final int harga;
  final bool aktif;
  final String? fotoUrl;

  Menu({
    required this.id,
    this.kategoriId,
    required this.nama,
    required this.harga,
    required this.aktif,
    this.fotoUrl,
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      id: json['id'] as String,
      kategoriId: json['kategori_id'] as String?,
      nama: json['nama'] as String,
      harga: (json['harga'] as num).toInt(),
      aktif: json['aktif'] as bool? ?? true,
      fotoUrl: json['foto_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kategori_id': kategoriId,
      'nama': nama,
      'harga': harga,
      'aktif': aktif,
      'foto_url': fotoUrl,
    };
  }
}
