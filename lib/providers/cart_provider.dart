import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/menu.dart';
import '../data/models/transaksi_item.dart';

final cartProvider = NotifierProvider<CartNotifier, List<TransaksiItem>>(() {
  return CartNotifier();
});

class CartNotifier extends Notifier<List<TransaksiItem>> {
  @override
  List<TransaksiItem> build() => [];

  void addMenu(Menu menu) {
    final existingIndex = state.indexWhere((item) => item.namaMenu == menu.nama);
    if (existingIndex >= 0) {
      final existingItem = state[existingIndex];
      final updated = List<TransaksiItem>.from(state);
      updated[existingIndex] = TransaksiItem(
        namaMenu: existingItem.namaMenu,
        hargaSatuan: existingItem.hargaSatuan,
        qty: existingItem.qty + 1,
        subtotal: existingItem.hargaSatuan * (existingItem.qty + 1),
      );
      state = updated;
    } else {
      state = [
        ...state,
        TransaksiItem(
          namaMenu: menu.nama,
          hargaSatuan: menu.harga,
          qty: 1,
          subtotal: menu.harga,
        ),
      ];
    }
  }

  void incrementQty(String namaMenu) {
    final idx = state.indexWhere((item) => item.namaMenu == namaMenu);
    if (idx < 0) return;
    final item = state[idx];
    final updated = List<TransaksiItem>.from(state);
    updated[idx] = TransaksiItem(
      namaMenu: item.namaMenu,
      hargaSatuan: item.hargaSatuan,
      qty: item.qty + 1,
      subtotal: item.hargaSatuan * (item.qty + 1),
    );
    state = updated;
  }

  void decrementQty(String namaMenu) {
    final idx = state.indexWhere((item) => item.namaMenu == namaMenu);
    if (idx < 0) return;
    final item = state[idx];
    if (item.qty > 1) {
      final updated = List<TransaksiItem>.from(state);
      updated[idx] = TransaksiItem(
        namaMenu: item.namaMenu,
        hargaSatuan: item.hargaSatuan,
        qty: item.qty - 1,
        subtotal: item.hargaSatuan * (item.qty - 1),
      );
      state = updated;
    } else {
      removeItem(namaMenu);
    }
  }

  void removeItem(String namaMenu) {
    state = state.where((item) => item.namaMenu != namaMenu).toList();
  }

  void clear() {
    state = [];
  }
}
