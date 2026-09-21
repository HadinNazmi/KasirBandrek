import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  static const String antreanTransaksi = 'antrean_transaksi';
  static const String cacheMenu = 'cache_menu';
  static const String cacheKategori = 'cache_kategori';

  static Box<Map> get antreanBox => Hive.box<Map>(antreanTransaksi);
  static Box get menuBox => Hive.box(cacheMenu);
  static Box get kategoriBox => Hive.box(cacheKategori);

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(antreanTransaksi);
    await Hive.openBox(cacheMenu);
    await Hive.openBox(cacheKategori);
  }
}
