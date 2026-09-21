import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/hive_boxes.dart';
import '../data/models/menu.dart';

final menuProvider = FutureProvider<List<Menu>>((ref) async {
  try {
    final client = Supabase.instance.client;
    final response = await client
        .from('menu')
        .select()
        .eq('aktif', true)
        .order('nama', ascending: true);

    final list = (response as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    // Simpan cache ke Hive
    await HiveBoxes.menuBox.put('cached_menus', list);
    return list.map((e) => Menu.fromJson(e)).toList();
  } catch (_) {
    // Fallback ke cache saat offline
    final cached = HiveBoxes.menuBox.get('cached_menus');
    if (cached != null && cached is List) {
      return cached
          .map((e) => Menu.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }
});
