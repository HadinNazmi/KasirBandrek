import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/menu.dart';

final menuProvider = FutureProvider<List<Menu>>((ref) async {
  final client = Supabase.instance.client;
  final response = await client
      .from('menu')
      .select()
      .eq('aktif', true)
      .order('nama', ascending: true);
      
  return (response as List).map((e) => Menu.fromJson(e)).toList();
});
