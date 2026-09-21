import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/hive_boxes.dart';
import '../data/models/kategori.dart';

final kategoriProvider = FutureProvider<List<Kategori>>((ref) async {
  try {
    final client = Supabase.instance.client;
    final response = await client
        .from('kategori')
        .select()
        .order('urutan', ascending: true);

    final list = (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    // Simpan cache ke Hive
    await HiveBoxes.kategoriBox.put('cached_kategoris', list);
    return list.map((e) => Kategori.fromJson(e)).toList();
  } catch (_) {
    // Fallback ke cache saat offline
    final cached = HiveBoxes.kategoriBox.get('cached_kategoris');
    if (cached != null && cached is List) {
      return cached
          .map((e) => Kategori.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }
});
