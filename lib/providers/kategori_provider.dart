import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/kategori.dart';

final kategoriProvider = FutureProvider<List<Kategori>>((ref) async {
  final client = Supabase.instance.client;
  final response = await client
      .from('kategori')
      .select()
      .order('urutan', ascending: true);
      
  return (response as List).map((e) => Kategori.fromJson(e)).toList();
});
