class Kategori {
  final String id;
  final String nama;
  final int urutan;

  Kategori({
    required this.id,
    required this.nama,
    required this.urutan,
  });

  factory Kategori.fromJson(Map<String, dynamic> json) {
    return Kategori(
      id: json['id'] as String,
      nama: json['nama'] as String,
      urutan: json['urutan'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nama': nama,
      'urutan': urutan,
    };
  }
}
