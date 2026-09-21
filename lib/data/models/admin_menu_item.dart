class AdminMenuItem {
  final String id;
  final String nama;
  final int harga;
  final bool aktif;
  final String? fotoUrl;
  final String? kategoriId;
  final String? kategoriNama;

  AdminMenuItem({
    required this.id,
    required this.nama,
    required this.harga,
    required this.aktif,
    this.fotoUrl,
    this.kategoriId,
    this.kategoriNama,
  });

  factory AdminMenuItem.fromJson(Map<String, dynamic> json) {
    return AdminMenuItem(
      id: json['id'] as String,
      nama: json['nama'] as String,
      harga: (json['harga'] as num).toInt(),
      aktif: json['aktif'] as bool? ?? true,
      fotoUrl: json['foto_url'] as String?,
      kategoriId: json['kategori_id'] as String?,
      kategoriNama: json['kategori_nama'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'harga': harga,
      'aktif': aktif,
      'foto_url': fotoUrl,
      'kategori_id': kategoriId,
      'kategori_nama': kategoriNama,
    };
  }

  AdminMenuItem copyWith({
    String? id,
    String? nama,
    int? harga,
    bool? aktif,
    String? fotoUrl,
    String? kategoriId,
    String? kategoriNama,
  }) {
    return AdminMenuItem(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      harga: harga ?? this.harga,
      aktif: aktif ?? this.aktif,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      kategoriId: kategoriId ?? this.kategoriId,
      kategoriNama: kategoriNama ?? this.kategoriNama,
    );
  }
}
