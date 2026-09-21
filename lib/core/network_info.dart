import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkInfo {
  static Future<bool> isConnected() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.none) || results.isEmpty) {
        return false;
      }
      return true;
    } catch (_) {
      // Jika terjadi error pada platform web atau check, anggap online atau biarkan request berjalan
      return true;
    }
  }

  static const String offlineMessage = 'Butuh koneksi internet untuk membuka fitur ini';
}
