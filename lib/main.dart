import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/hive_boxes.dart';
import 'core/theme.dart';
import 'features/kasir/kasir_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi locale tanggal Indonesia untuk Android/iOS
  await initializeDateFormatting('id_ID', null);
  
  // Inisialisasi Hive offline-first storage
  await HiveBoxes.init();
  
  // Baca konfigurasi dari env.json via --dart-define
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kedai Bandrek POS',
      theme: AppTheme.lightTheme,
      home: const KasirLayout(),
      debugShowCheckedModeBanner: false,
    );
  }
}
