import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});
